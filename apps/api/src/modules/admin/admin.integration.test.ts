/**
 * Phase 16 (ADR-022) on real Postgres: the admin claim on every route,
 * the audit trail, corrections applied by slug to future menus, provider
 * staleness, foods and exercises the seed then leaves alone, flags and
 * /meta/config, the support lookup that never shows food log contents.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { APP_FEATURE_KEYS, type MessMenu } from '@fitos/contracts';
import { VIT_ENDPOINTS } from '@fitos/core/mess/providers/vit/config';

import { createDatabase, type DatabaseHandle } from '../../db/client.js';
import { seedFoods } from '../../db/food-seed/load.js';
import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import { seedMesses } from '../../db/seed-mess.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { runMirror, type FetchOutcome } from '../mess/mirror.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

/** A copy without the named keys. */
const omit = <T extends Record<string, unknown>>(o: T, keys: readonly string[]): Record<string, unknown> =>
  Object.fromEntries(Object.entries(o).filter(([k]) => !keys.includes(k)));

const FIXTURES = new URL('../../../../../packages/core/test/fixtures/', import.meta.url);
const fresh = (n: string): string => readFileSync(fileURLToPath(new URL(`messit-2026-09-24/${n}.json`, FIXTURES)), 'utf8');
const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);
const nameOf = (url: string): string => /(hostel-\d-mess-\d)\.json$/.exec(url)?.[1] ?? url;

describeIfDb('/v1/admin (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let handle: DatabaseHandle;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  interface U {
    token: string;
    id: string;
    email: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.20.${n % 250}.${(n * 7) % 250}` });

  async function user(opts: { admin?: boolean; mess?: boolean } = {}): Promise<U> {
    n += 1;
    const token = `adm-tok-${n}`;
    const email = `adm${n}@vit.ac.in`;
    verifier.accept(token, { uid: `adm-uid-${n}`, email, claims: opts.admin === true ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`adm-uid-${n}`}`;
    const u = { token, id: row!.id, email };
    if (opts.mess === true) {
      const p = await call(u, 'PATCH', '/user/profile', { isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' } });
      expect(p.statusCode, p.body).toBe(200);
    }
    return u;
  }

  const call = (u: U | null, method: 'GET' | 'POST' | 'PUT' | 'PATCH', path: string, payload?: unknown) =>
    app.inject({
      method,
      url: `/v1${path}`,
      headers: u === null ? { 'x-forwarded-for': '198.21.0.1' } : headers(u.token),
      ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}),
    });
  const audits = async (action: string) => sql<{ actor_user_id: string | null; entity_id: string | null; metadata: Record<string, unknown> }[]>`
    select actor_user_id, entity_id, metadata from audit_logs where action = ${action} order by occurred_at`;
  const dish = (m: MessMenu, slug: string) => m.meals.flatMap((x) => x.dishes).find((d) => d.slug === slug);

  let admin: U;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    handle = createDatabase(url);
    await seedMesses(handle.db);
    await seedExercises(url);
    await seedFoods(url);
    await sql`delete from mess_dish_corrections`;
    await sql`delete from mess_dish_overrides`;
    await sql`delete from audit_logs`;
    await sql`delete from feature_flags`;
    await runMirror(handle, {
      fetcher: async (u): Promise<FetchOutcome> => {
        const name = nameOf(u);
        return NAMES.includes(name) ? { ok: true, body: fresh(name) } : { ok: false };
      },
    });
    ({ app, verifier } = await buildDbApp(url));
    admin = await user({ admin: true });
  });

  afterAll(async () => {
    await sql`delete from mess_dish_corrections`;
    await sql`delete from mess_dish_overrides`;
    await sql`delete from mess_menu_snapshots`;
    await sql`delete from mess_dish_nutrition`;
    await sql`delete from audit_logs`;
    await sql`delete from feature_flags`;
    await sql`delete from exercises where slug like 'adm-%'`;
    await sql`update foods set admin_edited_at = null`;
    await sql`update exercises set admin_edited_at = null, retired_at = null`;
    await seedFoods(url);
    await seedExercises(url);
    await sql`delete from users where firebase_uid like 'adm-%'`;
    await app.close();
    await handle.client.end({ timeout: 5 });
    await sql.end({ timeout: 5 });
  });

  /* ---------------------------------------------------------- access -- */

  it('§20: the claim is checked on the server for every admin route — 401 without a session, 403 without the claim', async () => {
    const plain = await user();
    const routes: ['GET' | 'POST' | 'PUT', string, unknown?][] = [
      ['GET', '/admin/me'],
      ['GET', '/admin/overview'],
      ['GET', '/admin/mess/health'],
      ['GET', '/admin/mess/corrections'],
      ['POST', `/admin/mess/corrections/${randomUUID()}/review`, { decision: 'reject' }],
      ['PUT', '/admin/mess/dishes/phulka/estimate', { field: 'kcal', low: 1, high: 2, reason: 'x x x' }],
      ['PUT', '/admin/mess/dishes/phulka/diet', { diet: 'veg', reason: 'x x x' }],
      ['GET', '/admin/foods'],
      ['GET', `/admin/foods/${randomUUID()}`],
      ['GET', '/admin/exercises'],
      ['POST', '/admin/exercises', {}],
      ['GET', '/admin/flags'],
      ['PUT', '/admin/flags/new-home', { enabled: true }],
      ['GET', '/admin/users?email=a@b.co'],
      ['GET', '/admin/audit'],
    ];
    for (const [method, path, body] of routes) {
      expect((await call(null, method, path, body)).statusCode, `${method} ${path} anon`).toBe(401);
      const r = await call(plain, method, path, body);
      expect(r.statusCode, `${method} ${path} non-admin`).toBe(403);
      expect((r.json() as { error: { code: string } }).error.code).toBe('FORBIDDEN');
    }
    const me = await call(admin, 'GET', '/admin/me');
    expect(me.json()).toEqual({ userId: admin.id, email: admin.email, isAdmin: true });
    // Nothing was written by the refused calls.
    expect((await sql`select 1 from audit_logs`).length).toBe(0);
  });

  /* --------------------------------------------------------- corrections -- */

  it('acceptance: an accepted correction applies by slug to every future menu (any date); provenance and audit kept; reviewed once', async () => {
    const reporter = await user({ mess: true });
    const r = await call(reporter, 'POST', '/mess/dishes/phulka/correction', { clientCorrectionId: randomUUID(), field: 'kcal', low: 110, high: 140, note: 'bigger here' });
    expect(r.statusCode, r.body).toBe(201);
    const id = (r.json() as { id: string }).id;

    const queue = (await call(admin, 'GET', '/admin/mess/corrections')).json() as { items: { dishSlug: string; estimate: { kcalLow: number } | null; reports: { id: string }[] }[] };
    const group = queue.items.find((g) => g.dishSlug === 'phulka')!;
    expect(group.estimate!.kcalLow).toBe(85);
    expect(group.reports.map((x) => x.id)).toContain(id);

    const ok = await call(admin, 'POST', `/admin/mess/corrections/${id}/review`, { decision: 'accept', note: 'checked the mess' });
    expect(ok.statusCode, ok.body).toBe(200);
    expect((ok.json() as { estimate: { kcalLow: number; kcalHigh: number } }).estimate).toMatchObject({ kcalLow: 110, kcalHigh: 140 });

    // The served menu, on the fixture's date and on a later (inferred) one, uses the new numbers.
    for (const date of ['2026-09-24', '2026-09-25']) {
      const m = (await call(reporter, 'GET', `/mess/menu?date=${date}`)).json() as MessMenu;
      const p = dish(m, 'phulka');
      if (p !== undefined) expect(p.nutrition).toMatchObject({ kcalLow: 110, kcalHigh: 140 });
    }
    const [rev] = await sql<{ reason: string; previous: { kcalLow: number }; current: { kcalLow: number } }[]>`
      select reason, previous, current from mess_dish_nutrition_revisions where dish_slug = 'phulka' order by revised_at desc limit 1`;
    expect(rev).toMatchObject({ reason: `review of correction ${id}`, previous: { kcalLow: 85 }, current: { kcalLow: 110 } });
    expect(await audits('correction.accept')).toEqual([{ actor_user_id: admin.id, entity_id: id, metadata: { dishSlug: 'phulka', field: 'kcal', note: 'checked the mess', low: 110, high: 140 } }]);

    const again = await call(admin, 'POST', `/admin/mess/corrections/${id}/review`, { decision: 'reject' });
    expect(again.statusCode).toBe(409);
  });

  it('reject changes nothing; a diet correction applies to the served menu by slug and can be cleared', async () => {
    const reporter = await user({ mess: true });
    const kcal = await call(reporter, 'POST', '/mess/dishes/phulka/correction', { clientCorrectionId: randomUUID(), field: 'kcal', low: 900, high: 950 });
    const kid = (kcal.json() as { id: string }).id;
    expect((await call(admin, 'POST', `/admin/mess/corrections/${kid}/review`, { decision: 'reject', note: 'implausible' })).statusCode).toBe(200);
    const [row] = await sql<{ kcal_low: string }[]>`select kcal_low from mess_dish_nutrition where dish_slug = 'phulka'`;
    expect(row!.kcal_low).toBe('110.00');
    expect(await audits('correction.reject')).toHaveLength(1);

    const diet = await call(reporter, 'POST', '/mess/dishes/phulka/correction', { clientCorrectionId: randomUUID(), field: 'diet', diet: 'egg', note: 'egg wash' });
    expect(diet.statusCode, diet.body).toBe(201);
    const did = (diet.json() as { id: string }).id;
    expect((await call(admin, 'POST', `/admin/mess/corrections/${did}/review`, { decision: 'accept' })).statusCode).toBe(200);
    const menu = (await call(reporter, 'GET', '/mess/menu?date=2026-09-24')).json() as MessMenu;
    expect(dish(menu, 'phulka')!.diet).toBe('egg');

    expect((await call(admin, 'PUT', '/admin/mess/dishes/phulka/diet', { diet: null, reason: 'back to the parser' })).statusCode).toBe(204);
    expect(dish((await call(reporter, 'GET', '/mess/menu?date=2026-09-24')).json() as MessMenu, 'phulka')!.diet).toBe('veg');
    expect((await audits('dish.diet')).map((a) => a.metadata['diet'])).toEqual([null]);
  });

  it('a direct estimate edit is validated (a slip is refused) and audited', async () => {
    const bad = await call(admin, 'PUT', '/admin/mess/dishes/phulka/estimate', { field: 'protein', low: 3, high: 900, reason: 'typo test' });
    expect(bad.statusCode).toBe(422);
    const ok = await call(admin, 'PUT', '/admin/mess/dishes/phulka/estimate', { field: 'protein', low: 3, high: 4.5, reason: 'measured' });
    expect(ok.statusCode, ok.body).toBe(204);
    const [row] = await sql<{ protein_low: string; protein_high: string }[]>`select protein_low, protein_high from mess_dish_nutrition where dish_slug = 'phulka'`;
    expect(row).toEqual({ protein_low: '3.00', protein_high: '4.50' });
    expect((await call(admin, 'PUT', '/admin/mess/dishes/no-such-dish/estimate', { field: 'kcal', low: 1, high: 2, reason: 'xyz' })).statusCode).toBe(404);
    expect(await audits('dish.estimate')).toHaveLength(1);
  });

  /* -------------------------------------------------------------- health -- */

  it('acceptance: provider health shows per-endpoint staleness', async () => {
    const codes = (await sql<{ code: string }[]>`select code from messes order by code`).map((r) => r.code);
    await sql`update messes set last_success_at = now() - interval '2 hours', consecutive_failures = 0`;
    await sql`update messes set last_success_at = now() - interval '30 hours' where code = ${codes[0]!}`;
    await sql`update messes set consecutive_failures = 4, last_error = 'unreachable' where code = ${codes[1]!}`;
    await sql`update messes set last_success_at = null where code = ${codes[2]!}`;
    const items = ((await call(admin, 'GET', '/admin/mess/health')).json() as { items: { code: string; state: string; hoursSinceSuccess: number | null; lastError: string | null }[] }).items;
    const state = new Map(items.map((i) => [i.code, i]));
    expect(items).toHaveLength(codes.length);
    expect(state.get(codes[0]!)).toMatchObject({ state: 'stale', hoursSinceSuccess: 30 });
    expect(state.get(codes[1]!)).toMatchObject({ state: 'failing', lastError: 'unreachable' });
    expect(state.get(codes[2]!)).toMatchObject({ state: 'never', hoursSinceSuccess: null });
    expect(state.get(codes[3]!)!.state).toBe('ok');
    const overview = (await call(admin, 'GET', '/admin/overview?days=7')).json() as { endpoints: unknown[]; pendingCorrections: number; users: { total: number }; days: number };
    expect(overview.endpoints).toHaveLength(codes.length);
    expect(overview.days).toBe(7);
    expect(overview.users.total).toBeGreaterThan(0);
  });

  /* --------------------------------------------------------------- foods -- */

  it('foods: a FITOS food corrected by hand keeps the correction through a re-seed; estimates stay unverified; custom foods are not here', async () => {
    const list = (await call(admin, 'GET', '/admin/foods?q=chapati')).json() as { items: { id: string; slug: string; source: string }[] };
    const chapati = list.items.find((f) => f.slug === 'chapati')!;
    const detail = (await call(admin, 'GET', `/admin/foods/${chapati.id}`)).json() as { nutrition: Record<string, unknown>[]; aliases: string[] };
    const row = { ...detail.nutrition[0]!, kcalLow: 90, kcalHigh: 110 };
    const verified = await call(admin, 'PUT', `/admin/foods/${chapati.id}`, { name: 'Chapati', aliases: ['Roti'], isVerified: true, nutrition: [row], reason: 'weighed' });
    expect(verified.statusCode).toBe(422);
    const ok = await call(admin, 'PUT', `/admin/foods/${chapati.id}`, { name: 'Chapati (phulka)', aliases: ['Roti', 'Phulka'], isVerified: false, nutrition: [row], reason: 'weighed at the mess' });
    expect(ok.statusCode, ok.body).toBe(200);
    expect(ok.json()).toMatchObject({ name: 'Chapati (phulka)', aliases: expect.arrayContaining(['roti', 'phulka']), nutrition: [{ kcalLow: 90, kcalHigh: 110 }] });
    expect((ok.json() as { adminEditedAt: string | null }).adminEditedAt).not.toBeNull();

    await seedFoods(url);
    const after = (await call(admin, 'GET', `/admin/foods/${chapati.id}`)).json() as { name: string; nutrition: { kcalLow: number }[] };
    expect(after.name).toBe('Chapati (phulka)');
    expect(after.nutrition[0]!.kcalLow).toBe(90);
    const [audit] = await audits('food.edit');
    expect(audit).toMatchObject({ actor_user_id: admin.id, entity_id: chapati.id, metadata: { slug: 'chapati', reason: 'weighed at the mess' } });

    // A user's own food is never in the admin list or editable.
    const owner = await user();
    const custom = await call(owner, 'POST', '/nutrition/foods', {
      clientFoodId: randomUUID(), name: 'Admtest my bar', nutrition: [{ ...row, basis: 'per_serving', servingLabel: '1 bar', confidence: 'medium' }],
    });
    const customId = (custom.json() as { id?: string }).id;
    expect(((await call(admin, 'GET', '/admin/foods?q=Admtest')).json() as { items: unknown[] }).items).toEqual([]);
    if (customId !== undefined) expect((await call(admin, 'GET', `/admin/foods/${customId}`)).statusCode).toBe(404);
  });

  /* ----------------------------------------------------------- exercises -- */

  it('exercises: create, edit, retire (out of the library and new programmes) and restore; the seed leaves an edited one alone', async () => {
    const body = {
      slug: 'adm-landmine-press',
      name: 'Landmine Press',
      movementPattern: 'vertical-push',
      equipment: ['barbell'],
      difficulty: 'intermediate',
      isUnilateral: true,
      defaultIncrementKg: 2.5,
      instructions: ['Hold the bar end at the shoulder.', 'Press up and forward.'],
      videoUrl: null,
      primaryMuscles: ['shoulders'],
      secondaryMuscles: ['triceps'],
      contraindications: [],
    };
    const created = await call(admin, 'POST', '/admin/exercises', body);
    expect(created.statusCode, created.body).toBe(201);
    const x = created.json() as { id: string; primaryMuscles: string[] };
    expect(x.primaryMuscles).toEqual(['shoulders']);
    expect((await call(admin, 'POST', '/admin/exercises', body)).statusCode).toBe(409);

    const plain = await user();
    const inLibrary = async () => ((await call(plain, 'GET', '/exercises?q=Landmine')).json() as { items: { id: string }[] }).items.some((i) => i.id === x.id);
    expect(await inLibrary()).toBe(true);

    const edit = omit(body, ['slug']);
    const edited = await call(admin, 'PUT', `/admin/exercises/${x.id}`, { ...edit, name: 'Landmine Shoulder Press', secondaryMuscles: ['triceps', 'chest'] });
    expect(edited.statusCode, edited.body).toBe(200);
    expect(edited.json()).toMatchObject({ name: 'Landmine Shoulder Press', secondaryMuscles: ['triceps', 'chest'] });

    expect((await call(admin, 'POST', `/admin/exercises/${x.id}/retire`)).statusCode).toBe(200);
    expect(await inLibrary()).toBe(false);
    const [inCatalogue] = await sql<{ n: string }[]>`select count(*)::text as n from exercises where id = ${x.id} and retired_at is null`;
    expect(inCatalogue!.n).toBe('0');
    expect((await call(admin, 'POST', `/admin/exercises/${x.id}/restore`)).statusCode).toBe(200);
    expect(await inLibrary()).toBe(true);

    // A seed exercise edited by hand survives a re-seed.
    const seedX = ((await call(admin, 'GET', '/admin/exercises?q=goblet')).json() as { items: { id: string; slug: string }[] }).items[0]!;
    const full = (await call(admin, 'GET', `/admin/exercises/${seedX.id}`)).json() as Record<string, unknown>;
    const seedEdit = omit(full, ['id', 'slug', 'retiredAt', 'adminEditedAt']);
    expect((await call(admin, 'PUT', `/admin/exercises/${seedX.id}`, { ...seedEdit, name: 'Goblet Squat (heels raised)' })).statusCode).toBe(200);
    await seedExercises(url);
    expect(((await call(admin, 'GET', `/admin/exercises/${seedX.id}`)).json() as { name: string }).name).toBe('Goblet Squat (heels raised)');
    expect((await audits('exercise.create')).length).toBe(1);
    expect((await audits('exercise.edit')).length).toBe(2);
    expect((await audits('exercise.retire')).length).toBe(1);
    expect((await audits('exercise.restore')).length).toBe(1);
  });

  /* ---------------------------------------------------------------- flags -- */

  it('flags: set by an admin, audited, served by the public /meta/config (§10.1); the app switches are listed and on by default (ADR-033)', async () => {
    const plain = await user();
    await sql`delete from feature_flags`;
    app.features.invalidate();
    const allOn = { 'share-programme': true, 'mess-ratings': true, streaks: true, 'community-foods': true, 'food-requests': true, 'weekly-report': true, 'progress-photos': true };
    expect((await call(plain, 'GET', '/meta/config')).json()).toEqual({ flags: allOn, minimumBuild: 0 });
    expect((await call(null, 'GET', '/meta/config')).statusCode).toBe(200);
    expect((await call(admin, 'PUT', '/admin/flags/Bad Key', { enabled: true })).statusCode).toBeGreaterThanOrEqual(400);
    const put = await call(admin, 'PUT', '/admin/flags/describe-meal', { enabled: false, description: 'FITOS AI meal parsing' });
    expect(put.statusCode, put.body).toBe(200);
    await call(admin, 'PUT', '/admin/flags/describe-meal', { enabled: true });
    expect((await call(plain, 'GET', '/meta/config')).json()).toEqual({ flags: { ...allOn, 'describe-meal': true }, minimumBuild: 0 });
    expect((await call(null, 'GET', '/meta/config')).json()).toEqual({ flags: { ...allOn, 'describe-meal': true }, minimumBuild: 0 });
    const list = (await call(admin, 'GET', '/admin/flags')).json() as { items: { key: string; name: string | null; description: string; updatedAt: string | null }[] };
    expect(list.items.map((i) => i.key)).toEqual([...APP_FEATURE_KEYS, 'describe-meal']);
    expect(list.items[0]).toMatchObject({ key: 'share-programme', name: 'Share your programme', updatedAt: null });
    expect(list.items.at(-1)).toMatchObject({ key: 'describe-meal', name: null, description: 'FITOS AI meal parsing' });

    // Switching one off reaches /meta/config at once, and the admin list shows when.
    expect((await call(admin, 'PUT', '/admin/flags/streaks', { enabled: false })).json()).toMatchObject({ key: 'streaks', name: 'Streak and goal ring', enabled: false });
    expect(((await call(null, 'GET', '/meta/config')).json() as { flags: Record<string, boolean> }).flags['streaks']).toBe(false);
    await call(admin, 'PUT', '/admin/flags/streaks', { enabled: true });
    await sql`delete from feature_flags where key = 'streaks'`;
    app.features.invalidate();
    expect((await audits('flag.set')).map((a) => a.metadata['enabled'])).toEqual([false, true, false, true]);
  });

  /* -------------------------------------------------------------- support -- */

  it('support lookup: counts and dates only (no food log contents), audited — found or not', async () => {
    const someone = await user();
    await call(someone, 'POST', '/nutrition/logs', {
      clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'quick-add', quickAdd: { name: 'Secret lunch', kcal: 500, proteinG: 20, carbG: 50, fatG: 15 },
    });
    const r = await call(admin, 'GET', `/admin/users?email=${encodeURIComponent(someone.email.toUpperCase())}`);
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json()).toMatchObject({ userId: someone.id, email: someone.email, counts: { foodLogs: 1, sessions: 0 }, notifications: { enabled: true, tone: 'cheeky' } });
    expect(r.body).not.toContain('Secret lunch');
    expect(r.body).not.toContain('500');
    expect((await call(admin, 'GET', `/admin/users?id=${someone.id}`)).statusCode).toBe(200);
    expect((await call(admin, 'GET', '/admin/users?email=nobody@vit.ac.in')).statusCode).toBe(404);
    expect((await call(admin, 'GET', '/admin/users')).statusCode).toBe(422);
    expect((await audits('user.lookup')).map((a) => [a.entity_id, a.metadata['found']])).toEqual([
      [someone.id, true],
      [someone.id, true],
      [null, false],
    ]);
  });

  it('the audit log lists every action, newest first, with its actor, and pages', async () => {
    const page = (await call(admin, 'GET', '/admin/audit?limit=3')).json() as { items: { action: string; actorEmail: string | null; occurredAt: string }[]; next: string | null };
    expect(page.items).toHaveLength(3);
    expect(page.items.every((i) => i.actorEmail === admin.email)).toBe(true);
    expect(page.next).not.toBeNull();
    const more = (await call(admin, 'GET', `/admin/audit?limit=200&before=${encodeURIComponent(page.next!)}`)).json() as { items: { action: string }[] };
    const all = [...page.items, ...more.items].map((i) => i.action);
    for (const a of ['correction.accept', 'correction.reject', 'dish.diet', 'dish.estimate', 'food.edit', 'exercise.create', 'flag.set', 'user.lookup']) {
      expect(all, a).toContain(a);
    }
  });
});
