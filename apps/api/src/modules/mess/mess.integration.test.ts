/**
 * VIT mess through the HTTP surface on real Postgres (Phase 9, §31).
 *
 * The mirror is driven by a scripted fetcher serving the verbatim captures in
 * packages/core/test/fixtures — nothing here reaches MessIT. Covers: all six
 * endpoints, dedupe by payload hash, malformed and unreachable endpoints
 * (the stored copy keeps being served), stale/inferred menus with their
 * qualifier, the medium cap, logging a dish through Phase 8's snapshot,
 * history immune to estimate changes, saved meals keeping mess identity
 * (owner D11), pending corrections (D17), mess config (D13) and latency.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import type { CreateLogResponse, MessCorrection, MessMenu, MessesResponse, NutritionDay, SavedMeal, UserProfileDetail } from '@fitos/contracts';
import { VIT_ENDPOINTS } from '@fitos/core/mess/providers/vit/config';

import { createDatabase, type DatabaseHandle } from '../../db/client.js';
import { migrateUp } from '../../db/migrate.js';
import { seedMesses } from '../../db/seed-mess.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { runMirror, type FetchOutcome, type MirrorFetcher } from './mirror.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

const FIXTURES = new URL('../../../../../packages/core/test/fixtures/', import.meta.url);
const fixtureText = (path: string): string => readFileSync(fileURLToPath(new URL(path, FIXTURES)), 'utf8');
const fresh = (n: string): string => fixtureText(`messit-2026-09-24/${n}.json`);
/** A 2026-09-07 fixture without its `_capture` note (the note is ours, not upstream's). */
const old = (n: string): string => {
  const { _capture, ...payload } = JSON.parse(fixtureText(`${n}.json`)) as Record<string, unknown>;
  void _capture;
  return JSON.stringify(payload);
};
const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);
const nameOf = (url: string): string => /(hostel-\d-mess-\d)\.json$/.exec(url)?.[1] ?? url;

/** Serves `bodies[name]`; a missing name or `null` is an unreachable endpoint. */
function scripted(bodies: Record<string, string | null>, calls: string[] = []): MirrorFetcher {
  return async (url): Promise<FetchOutcome> => {
    calls.push(url);
    const body = bodies[nameOf(url)];
    return body === undefined || body === null ? { ok: false } : { ok: true, body };
  };
}
const allFresh = (): Record<string, string> => Object.fromEntries(NAMES.map((n) => [n, fresh(n)]));

describeIfDb('/v1/mess (real Postgres, scripted MessIT)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let handle: DatabaseHandle;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let ip = 0;

  const reset = async (): Promise<void> => {
    await sql`delete from mess_dish_corrections`;
    await sql`delete from mess_menu_snapshots`;
    await sql`delete from mess_dish_nutrition`;
    await sql`update messes set last_attempt_at = null, last_success_at = null, last_changed_at = null, last_error = null, consecutive_failures = 0`;
  };

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    handle = createDatabase(url);
    await seedMesses(handle.db);
    await reset();
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'mess-%'`;
    await reset();
    await app.close();
    await handle.client.end({ timeout: 5 });
    await sql.end({ timeout: 5 });
  });

  const headers = (token: string) => {
    ip += 1;
    return { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.19.${Math.floor(ip / 250) % 250}.${ip % 250}` };
  };

  interface TestUser {
    token: string;
    id: string;
  }

  async function user(mess: { hostelId: string; messId: string } | null = { hostelId: 'mens', messId: 'veg' }): Promise<TestUser> {
    n += 1;
    const token = `mess-tok-${n}`;
    verifier.accept(token, { uid: `mess-uid-${n}`, email: `mess${n}@vit.ac.in` });
    const r = await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} });
    expect(r.statusCode, r.body).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`mess-uid-${n}`}`;
    const u = { token, id: row!.id };
    if (mess !== null) {
      const p = await patchProfile(u, { isVitStudent: true, mess: { providerId: 'vit-vellore', ...mess } });
      expect(p.statusCode, p.body).toBe(200);
    }
    return u;
  }

  const get = (u: TestUser, path: string) => app.inject({ method: 'GET', url: `/v1${path}`, headers: headers(u.token) });
  const post = (u: TestUser, path: string, payload: unknown) =>
    app.inject({ method: 'POST', url: `/v1${path}`, headers: headers(u.token), payload: payload as Record<string, unknown> });
  const patchProfile = (u: TestUser, payload: unknown) =>
    app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: headers(u.token), payload: payload as Record<string, unknown> });

  async function menu(u: TestUser, query = ''): Promise<MessMenu> {
    const r = await get(u, `/mess/menu${query}`);
    expect(r.statusCode, r.body).toBe(200);
    return r.json();
  }

  const messLog = (items: unknown[], extra: Record<string, unknown> = {}) => ({
    clientLogId: randomUUID(),
    mealSlot: 'lunch',
    entryMethod: 'mess',
    mess: 'mens-veg',
    menuDate: '2026-09-24',
    loggedAt: new Date().toISOString(),
    items,
    ...extra,
  });

  // ---------------------------------------------------------------- auth --

  it('401 without a session on every mess route', async () => {
    for (const [method, path] of [
      ['GET', '/v1/mess/providers'],
      ['GET', '/v1/mess/providers/vit-vellore/messes'],
      ['GET', '/v1/mess/menu'],
      ['POST', '/v1/mess/dishes/dal-tadka/correction'],
    ] as const) {
      const r = await app.inject(method === 'POST' ? { method, url: path, payload: {} } : { method, url: path });
      expect(r.statusCode, `${method} ${path}`).toBe(401);
    }
  });

  // -------------------------------------------------------------- mirror --

  it('the mirror stores all six endpoints; a re-run with the same payloads stores nothing new (dedupe by hash)', async () => {
    await reset();
    const calls: string[] = [];
    const first = await runMirror(handle, { fetcher: scripted(allFresh(), calls) });
    expect(first.ran).toBe(true);
    expect(first.messes.map((m) => m.outcome)).toEqual(Array(6).fill('new'));
    expect(first.messes.every((m) => m.dates === 30)).toBe(true);
    // Only the six configured URLs, nothing else, no user data in them.
    expect(calls.sort()).toEqual(VIT_ENDPOINTS.map((e) => e.url).sort());
    const [{ count: snaps1 }] = await sql<{ count: string }[]>`select count(*)::text as count from mess_menu_snapshots`;
    expect(Number(snaps1)).toBe(6);
    const [{ count: dishes1 }] = await sql<{ count: string }[]>`select count(*)::text as count from mess_dish_nutrition`;
    expect(Number(dishes1)).toBeGreaterThan(200);
    expect(first.messes.reduce((s, m) => s + m.dishesAdded, 0)).toBe(Number(dishes1));

    const second = await runMirror(handle, { fetcher: scripted(allFresh()) });
    expect(second.messes.map((m) => m.outcome)).toEqual(Array(6).fill('unchanged'));
    // Enrichment is idempotent: nothing added, nothing overwritten.
    expect(second.messes.reduce((s, m) => s + m.dishesAdded, 0)).toBe(0);
    const [{ count: snaps2 }] = await sql<{ count: string }[]>`select count(*)::text as count from mess_menu_snapshots`;
    expect(Number(snaps2)).toBe(6);
    const [row] = await sql<{ first_seen_at: Date; last_seen_at: Date }[]>`select first_seen_at, last_seen_at from mess_menu_snapshots limit 1`;
    expect(row!.last_seen_at.getTime()).toBeGreaterThanOrEqual(row!.first_seen_at.getTime());
  });

  it('no stored estimate is high confidence, and none has fibre (unknown, never 0)', async () => {
    const rows = await sql<{ confidence: string; fibre_low: string | null }[]>`select confidence, fibre_low from mess_dish_nutrition`;
    expect(rows.some((r) => r.confidence === 'high')).toBe(false);
    expect(rows.every((r) => r.fibre_low === null)).toBe(true);
    const [rice] = await sql<{ confidence: string }[]>`select confidence from mess_dish_nutrition where dish_slug = 'white-rice'`;
    expect(rice!.confidence).toBe('medium'); // 'high' in the core table, capped
  });

  it('a malformed payload is rejected and the previous copy is kept; the status says so', async () => {
    const bodies = allFresh();
    bodies['hostel-1-mess-2'] = JSON.stringify({ hostel: 1, mess: 2, menu: [{ date: '2026-09-24', menu: [{ type: '1', menu: 'Idly' }] }] });
    bodies['hostel-1-mess-3'] = '<html>502 Bad Gateway</html>';
    bodies['hostel-2-mess-3'] = fresh('hostel-2-mess-2'); // the wrong mess's payload
    const report = await runMirror(handle, { fetcher: scripted(bodies) });
    const outcome = Object.fromEntries(report.messes.map((m) => [m.code, m.outcome]));
    expect(outcome).toMatchObject({ 'mens-veg': 'malformed', 'mens-nonveg': 'malformed', 'womens-nonveg': 'malformed', 'womens-veg': 'unchanged' });
    const [{ count }] = await sql<{ count: string }[]>`select count(*)::text as count from mess_menu_snapshots`;
    expect(Number(count)).toBe(6);
    const u = await user();
    const m = await menu(u, '?date=2026-09-24');
    expect(m.resolution).toEqual({ kind: 'exact', date: '2026-09-24' });
    expect(m.mess.freshness.lastError).toBe('malformed');
    expect(m.mess.freshness.lastSuccessAt).not.toBeNull();
  });

  it('an upstream outage still serves the mirror, with honest freshness (§31 acceptance)', async () => {
    const before = await sql<{ code: string; last_success_at: Date }[]>`select code, last_success_at from messes order by code`;
    const report = await runMirror(handle, { fetcher: scripted({}) });
    expect(report.messes.every((m) => m.outcome === 'unreachable')).toBe(true);
    const after = await sql<{ code: string; last_success_at: Date; consecutive_failures: number }[]>`
      select code, last_success_at, consecutive_failures from messes order by code`;
    expect(after.map((a) => a.last_success_at.getTime())).toEqual(before.map((b) => b.last_success_at.getTime()));
    expect(after.every((a) => a.consecutive_failures >= 1)).toBe(true);
    const u = await user({ hostelId: 'womens', messId: 'special' });
    const m = await menu(u, '?date=2026-09-24');
    expect(m.mess.code).toBe('womens-special');
    expect(m.resolution.kind).toBe('exact');
    expect(m.meals.map((x) => x.slot)).toEqual(['breakfast', 'lunch', 'snacks', 'dinner']);
    expect(m.mess.freshness.lastError).toBe('unreachable');
    // Back online: the error clears.
    await runMirror(handle, { fetcher: scripted(allFresh()) });
    expect((await menu(u, '?date=2026-09-24')).mess.freshness.lastError).toBeNull();
  });

  it('two runs never overlap: the second reports ran:false while the first holds the lock', async () => {
    let release: () => void = () => undefined;
    const gate = new Promise<void>((r) => {
      release = r;
    });
    const slow: MirrorFetcher = async (u) => {
      await gate;
      return scripted(allFresh())(u);
    };
    const first = runMirror(handle, { fetcher: slow });
    await new Promise((r) => setTimeout(r, 100));
    const second = await runMirror(handle, { fetcher: scripted(allFresh()) });
    expect(second.ran).toBe(false);
    release();
    expect((await first).ran).toBe(true);
  });

  // --------------------------------------------------------------- reads --

  it('providers and all six messes, each with its freshness', async () => {
    const u = await user();
    const p = await get(u, '/mess/providers');
    expect(p.statusCode).toBe(200);
    expect(p.json()).toEqual({ items: [{ slug: 'vit-vellore', displayName: 'VIT Vellore', status: 'active' }] });
    const r = await get(u, '/mess/providers/vit-vellore/messes');
    expect(r.statusCode).toBe(200);
    const body: MessesResponse = r.json();
    expect(body.items.map((m) => m.code).sort()).toEqual(['mens-nonveg', 'mens-special', 'mens-veg', 'womens-nonveg', 'womens-special', 'womens-veg']);
    for (const m of body.items) {
      expect(m.freshness.stale, m.code).toBe(false);
      expect(m.freshness.latestPublishedDate, m.code).toBe('2026-09-30');
    }
    expect((await get(u, '/mess/providers/nope/messes')).statusCode).toBe(404);
  });

  it('all six messes render a menu for today (§31 acceptance)', async () => {
    const u = await user();
    for (const code of ['mens-veg', 'mens-nonveg', 'mens-special', 'womens-veg', 'womens-nonveg', 'womens-special']) {
      const m = await menu(u, `?mess=${code}&date=2026-09-24`);
      expect(m.mess.code).toBe(code);
      expect(m.resolution.kind, code).toBe('exact');
      expect(m.meals.length, code).toBe(4);
      expect(m.meals.every((x) => x.dishes.length > 0), code).toBe(true);
    }
  });

  it('the menu: verbatim text per meal, parsed dishes with diet, role and a medium-capped estimate', async () => {
    const u = await user();
    const m = await menu(u, '?date=2026-09-24');
    expect(m.mess.code).toBe('mens-veg');
    const upstream = (JSON.parse(fresh('hostel-1-mess-2')) as { menu: { date: string; menu: { type: number; menu: string }[] }[] }).menu
      .find((d) => d.date === '2026-09-24')!.menu.find((x) => x.type === 2)!.menu;
    const lunch = m.meals.find((x) => x.slot === 'lunch')!;
    expect(lunch.rawMenu).toBe(upstream);
    const phulka = lunch.dishes.find((d) => d.slug === 'phulka')!;
    expect(phulka).toMatchObject({ name: 'Phulka', diet: 'veg', role: 'staple', isAmbient: false, correctionPending: false });
    expect(phulka.nutrition).toMatchObject({ servingLabel: '1 piece', servingGrams: 40, kcalLow: 85, kcalHigh: 120, confidence: 'medium', source: 'estimated', fibreLow: null });
    const kulambu = lunch.dishes.find((d) => d.slug === 'kara-kulambu')!;
    expect(kulambu.nutrition?.servingGrams).toBeNull();
    expect(kulambu.nutrition?.confidence).toBe('low');
  });

  it('a date the mess has not published is inferred from the cycle, and says so (stale endpoint, §14.4)', async () => {
    const u = await user();
    const m = await menu(u, '?date=2026-10-02');
    expect(m.resolution).toEqual({ kind: 'cycle-inferred', date: '2026-10-02', sourceDate: '2026-09-18', cycleLengthDays: 14 });
    expect(m.meals.length).toBe(4);
  });

  it('a stale endpoint with no cycle is unavailable, with the latest published date', async () => {
    // The 2026-09-07 men's special capture: two August days, no cycle.
    const [mess] = await sql<{ id: string }[]>`select id from messes where code = 'mens-special'`;
    await sql`delete from mess_menu_snapshots where mess_id = ${mess!.id}`;
    const bodies = allFresh();
    bodies['hostel-1-mess-1'] = old('hostel-1-mess-1');
    await runMirror(handle, { fetcher: scripted(bodies) });
    const u = await user();
    const m = await menu(u, '?mess=mens-special&date=2026-09-24');
    expect(m.resolution).toEqual({ kind: 'unavailable', date: '2026-09-24', latestAvailable: '2026-08-10' });
    expect(m.meals).toEqual([]);
    // Restored: the fresh payload is newest again and today is exact.
    await runMirror(handle, { fetcher: scripted(allFresh()) });
    expect((await menu(u, '?mess=mens-special&date=2026-09-24')).resolution.kind).toBe('exact');
    // The August day only the old capture publishes is still answered exactly.
    expect((await menu(u, '?mess=mens-special&date=2026-08-10')).resolution).toEqual({ kind: 'exact', date: '2026-08-10' });
  });

  it('no mess configured: 404 "choose your mess"; an unknown mess code: 404; a bad date: 422', async () => {
    const u = await user(null);
    const r = await get(u, '/mess/menu');
    expect(r.statusCode).toBe(404);
    expect(r.json().error.message).toMatch(/Choose your mess/);
    expect((await get(u, '/mess/menu?mess=mens-veg&date=2026-09-24')).statusCode).toBe(200); // browsing any mess (D14)
    expect((await get(u, '/mess/menu?mess=nope-mess')).statusCode).toBe(404);
    expect((await get(u, '/mess/menu?date=24-09-2026')).statusCode).toBe(422);
  });

  it('the mirror stale flag turns on after 24 h without a successful fetch (D19)', async () => {
    await runMirror(handle, { fetcher: scripted(allFresh()), now: () => new Date(Date.now() - 25 * 3_600_000) });
    const u = await user();
    const m = await menu(u, '?date=2026-09-24');
    expect(m.mess.freshness.stale).toBe(true);
    await runMirror(handle, { fetcher: scripted(allFresh()) });
    expect((await menu(u, '?date=2026-09-24')).mess.freshness.stale).toBe(false);
  });

  // ------------------------------------------------------------- logging --

  it('a dish tap logs the estimate x portion as a Phase 8 snapshot (§31 acceptance), retry-safe', async () => {
    const u = await user();
    const body = messLog([{ dishSlug: 'phulka', servings: 1.5 }]);
    const r1 = await post(u, '/nutrition/logs', body);
    expect(r1.statusCode, r1.body).toBe(201);
    const created: CreateLogResponse = r1.json();
    expect(created.log).toMatchObject({ entryMethod: 'mess', messCode: 'mens-veg', mealSlot: 'lunch' });
    const item = created.log.items[0]!;
    expect(item).toMatchObject({
      foodId: null,
      messDishSlug: 'phulka',
      foodName: 'Phulka',
      foodSource: 'estimated',
      basis: 'per_serving',
      servingLabel: '1 piece',
      servingGrams: 40,
      servings: 1.5,
      grams: 60,
      confidence: 'medium',
      fibreLow: null,
      fibreHigh: null,
    });
    // 85-120 kcal, 2.5-3.6 g protein per piece x 1.5, rounded outward.
    expect([item.kcalLow, item.kcalHigh]).toEqual([127, 180]);
    expect(item.proteinLow).toBeLessThanOrEqual(3.75);
    expect(item.proteinHigh).toBeGreaterThanOrEqual(5.4);
    expect(created.day.totals.kcalLow).toBeGreaterThanOrEqual(127);
    // Replay: the same log, 200, nothing counted twice.
    const r2 = await post(u, '/nutrition/logs', body);
    expect(r2.statusCode).toBe(200);
    expect((r2.json() as CreateLogResponse).log.id).toBe(created.log.id);
    expect((r2.json() as CreateLogResponse).day.totals.itemCount).toBe(created.day.totals.itemCount);
    // The menu marks it logged.
    const m = await menu(u, '?date=2026-09-24');
    const today = m.today;
    if (today === '2026-09-24' || created.log.localDate === '2026-09-24') {
      expect(m.logged).toContainEqual({ dishSlug: 'phulka', mealSlot: 'lunch', clientLogId: body.clientLogId });
    }
  });

  it('logging refuses a dish not on that menu, an unknown mess, a dish with no estimate, and grams without a weight', async () => {
    const u = await user();
    const notOnMenu = await post(u, '/nutrition/logs', messLog([{ dishSlug: 'chicken-biryani', servings: 1 }]));
    expect(notOnMenu.statusCode).toBe(404);
    const unknown = await post(u, '/nutrition/logs', messLog([{ dishSlug: 'phulka', servings: 1 }], { mess: 'nope-mess' }));
    expect(unknown.statusCode).toBe(404);
    const noEstimate = await post(
      u,
      '/nutrition/logs',
      messLog([{ dishSlug: 'urapadai', servings: 1 }], { mess: 'womens-special', menuDate: '2026-09-25', mealSlot: 'dinner' }),
    );
    expect(noEstimate.statusCode, noEstimate.body).toBe(422);
    const noWeight = await post(u, '/nutrition/logs', messLog([{ dishSlug: 'kara-kulambu', grams: 150 }]));
    expect(noWeight.statusCode).toBe(422);
    const withServings = await post(u, '/nutrition/logs', messLog([{ dishSlug: 'kara-kulambu', servings: 1 }]));
    expect(withServings.statusCode, withServings.body).toBe(201);
    // Numbers in the body are refused by the contract: the server's estimate is the only source.
    const withNumbers = await post(u, '/nutrition/logs', messLog([{ dishSlug: 'phulka', servings: 1, kcalLow: 1 }]));
    expect(withNumbers.statusCode).toBe(422);
  });

  it('a logged dish never changes when its estimate is corrected later; a new log takes the new estimate', async () => {
    const u = await user();
    const first: CreateLogResponse = (await post(u, '/nutrition/logs', messLog([{ dishSlug: 'dhal-makhani', servings: 1 }]))).json();
    const before = first.log.items[0]!;
    await sql`update mess_dish_nutrition set kcal_low = 400, kcal_high = 500 where dish_slug = 'dhal-makhani'`;
    try {
      const day: NutritionDay = (await get(u, `/nutrition/day/${first.log.localDate}`)).json();
      const same = day.logs.find((l) => l.clientLogId === first.log.clientLogId)!.items[0]!;
      expect([same.kcalLow, same.kcalHigh]).toEqual([before.kcalLow, before.kcalHigh]);
      const second: CreateLogResponse = (await post(u, '/nutrition/logs', messLog([{ dishSlug: 'dhal-makhani', servings: 1 }]))).json();
      expect([second.log.items[0]!.kcalLow, second.log.items[0]!.kcalHigh]).toEqual([400, 500]);
    } finally {
      await sql`update mess_dish_nutrition set kcal_low = 180, kcal_high = 260 where dish_slug = 'dhal-makhani'`;
    }
  });

  it('a saved meal keeps a mess dish as a mess dish with its range (owner D11); normal items unchanged', async () => {
    const u = await user();
    const mess: CreateLogResponse = (await post(u, '/nutrition/logs', messLog([{ dishSlug: 'dhal-makhani', servings: 2 }, { dishSlug: 'phulka', servings: 3 }]))).json();
    const quick: CreateLogResponse = (
      await post(u, '/nutrition/logs', {
        clientLogId: randomUUID(),
        mealSlot: 'lunch',
        entryMethod: 'quick-add',
        quickAdd: { name: 'Lassi', kcal: 150, proteinG: 5, carbG: 20, fatG: 5 },
      })
    ).json();
    const r = await post(u, '/nutrition/saved-meals', { clientMealId: randomUUID(), name: 'Mess lunch', fromClientLogIds: [mess.log.clientLogId, quick.log.clientLogId] });
    expect(r.statusCode, r.body).toBe(201);
    const meal: SavedMeal = r.json();
    expect(meal.items.map((i) => i.kind)).toEqual(['mess', 'mess', 'quick-add']);
    const dal = meal.items[0]!;
    if (dal.kind !== 'mess') throw new Error('expected a mess item');
    expect(dal).toMatchObject({ dishSlug: 'dhal-makhani', name: 'Dhal Makhani', servings: 2 });
    expect(dal.row).toMatchObject({ kcalLow: 180, kcalHigh: 260, confidence: 'medium' });
    const q = meal.items[2]!;
    if (q.kind !== 'quick-add') throw new Error('expected a quick add');
    expect(q.kcal).toBe(150);

    // Re-log: a range again (never the low end as an exact number), from the CURRENT estimate.
    await sql`update mess_dish_nutrition set kcal_low = 200, kcal_high = 300 where dish_slug = 'dhal-makhani'`;
    try {
      const again = await post(u, '/nutrition/logs', { clientLogId: randomUUID(), mealSlot: 'dinner', entryMethod: 'saved-meal', savedMealId: meal.id });
      expect(again.statusCode, again.body).toBe(201);
      const items = (again.json() as CreateLogResponse).log.items;
      expect(items[0]).toMatchObject({ messDishSlug: 'dhal-makhani', foodSource: 'estimated', kcalLow: 400, kcalHigh: 600, confidence: 'medium' });
      expect(items[1]).toMatchObject({ messDishSlug: 'phulka', servings: 3 });
      expect(items[1]!.kcalLow).toBeLessThan(items[1]!.kcalHigh);
      expect(items[2]).toMatchObject({ messDishSlug: null, foodSource: 'user', kcalLow: 150, kcalHigh: 150 });
    } finally {
      await sql`update mess_dish_nutrition set kcal_low = 180, kcal_high = 260 where dish_slug = 'dhal-makhani'`;
    }
    // Mess dishes are not "recent foods" (those are library foods).
    const recent = await get(u, '/nutrition/foods/recent');
    expect(recent.json().items).toEqual([]);
  });

  // --------------------------------------------------------- corrections --

  it('a correction is stored pending, changes no estimate, shows as pending to its author only; retry-safe', async () => {
    const author = await user();
    const other = await user();
    const body = { clientCorrectionId: randomUUID(), field: 'kcal', low: 150, high: 200, note: 'Our phulkas are bigger' };
    const r1 = await post(author, '/mess/dishes/phulka/correction', body);
    expect(r1.statusCode, r1.body).toBe(201);
    const c: MessCorrection = r1.json();
    expect(c).toMatchObject({ dishSlug: 'phulka', field: 'kcal', low: 150, high: 200, status: 'pending' });
    const r2 = await post(author, '/mess/dishes/phulka/correction', body);
    expect(r2.statusCode).toBe(200);
    expect((r2.json() as MessCorrection).id).toBe(c.id);
    // The active estimate is unchanged (D17).
    const [row] = await sql<{ kcal_low: string }[]>`select kcal_low from mess_dish_nutrition where dish_slug = 'phulka'`;
    expect(row!.kcal_low).toBe('85.00');
    const mine = (await menu(author, '?date=2026-09-24')).meals.flatMap((m) => m.dishes).find((d) => d.slug === 'phulka')!;
    const theirs = (await menu(other, '?date=2026-09-24')).meals.flatMap((m) => m.dishes).find((d) => d.slug === 'phulka')!;
    expect(mine.correctionPending).toBe(true);
    expect(mine.nutrition?.kcalLow).toBe(85);
    expect(theirs.correctionPending).toBe(false);
  });

  it('corrections: a dish with no estimate can be reported; an unknown dish cannot; the body is validated', async () => {
    const u = await user();
    const ok = await post(u, '/mess/dishes/urapadai/correction', { clientCorrectionId: randomUUID(), field: 'other', note: 'A lentil pancake, about 2 per plate' });
    expect(ok.statusCode, ok.body).toBe(201);
    const unknown = await post(u, '/mess/dishes/no-such-dish/correction', { clientCorrectionId: randomUUID(), field: 'diet', diet: 'veg' });
    expect(unknown.statusCode).toBe(404);
    const bad = await post(u, '/mess/dishes/phulka/correction', { clientCorrectionId: randomUUID(), field: 'kcal', low: 300, high: 100 });
    expect(bad.statusCode).toBe(422);
  });

  // -------------------------------------------------------- mess config --

  it('the mess can be changed after onboarding, only to a listed mess (owner D13)', async () => {
    const u = await user();
    const change = await patchProfile(u, { mess: { providerId: 'vit-vellore', hostelId: 'womens', messId: 'nonveg' } });
    expect(change.statusCode, change.body).toBe(200);
    expect((change.json() as UserProfileDetail).mess).toEqual({ providerId: 'vit-vellore', hostelId: 'womens', messId: 'nonveg' });
    expect((await menu(u, '?date=2026-09-24')).mess.code).toBe('womens-nonveg');
    const unknown = await patchProfile(u, { mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'luxury' } });
    expect(unknown.statusCode).toBe(422);
    const noMess = await patchProfile(u, { isVitStudent: true, mess: null });
    expect(noMess.statusCode).toBe(422);
    const clear = await patchProfile(u, { mess: null });
    expect(clear.statusCode).toBe(422); // a VIT student keeps a mess
    const leave = await patchProfile(u, { isVitStudent: false });
    expect(leave.statusCode).toBe(200);
    expect(leave.json()).toMatchObject({ isVitStudent: false, mess: null });
    expect((await get(u, '/mess/menu')).statusCode).toBe(404);
  });

  it('onboarding refuses a mess the server does not list', async () => {
    const u = await user(null);
    const r = await post(u, '/onboarding/answer', { step: 'vit', isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'luxury' } });
    expect(r.statusCode).toBe(422);
    const ok = await post(u, '/onboarding/answer', { step: 'vit', isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' } });
    expect(ok.statusCode, ok.body).toBe(200);
  });

  // ---------------------------------------------------------- latency --

  it('GET /mess/menu p95 under 200 ms', async () => {
    const u = await user();
    const times: number[] = [];
    for (let i = 0; i < 25; i += 1) {
      const t = performance.now();
      const r = await get(u, `/mess/menu?date=2026-09-${String(1 + (i % 28)).padStart(2, '0')}`);
      times.push(performance.now() - t);
      expect(r.statusCode).toBe(200);
    }
    times.sort((a, b) => a - b);
    expect(times[Math.floor(times.length * 0.95) - 1]).toBeLessThan(200);
  });
});
