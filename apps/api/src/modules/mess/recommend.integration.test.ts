/**
 * GET /v1/mess/menu/recommend on real Postgres (Phase 10, ADR-015).
 *
 * The mirror serves the verbatim 2026-09-24 capture with every date shifted so
 * that its 24 Sep is TODAY in the user's zone — the tests hold on any day CI
 * runs. Nothing here reaches MessIT.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { ALLERGENS, type CreateLogResponse, type MessRecommendation } from '@fitos/contracts';
import { ALLERGENS as CORE_ALLERGENS, allergenStatus } from '@fitos/core/mess/allergens';
import { VIT_ENDPOINTS } from '@fitos/core/mess/providers/vit/config';
import { defaultRecommendationSlot } from '@fitos/core/mess/recommendation';
import { addDays, localDateOf, localHourOf, snapshotNutrition } from '@fitos/core/nutrition/log';

import { createDatabase, type DatabaseHandle } from '../../db/client.js';
import { migrateUp } from '../../db/migrate.js';
import { seedMesses } from '../../db/seed-mess.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { runMirror, type FetchOutcome, type MirrorFetcher } from './mirror.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

const IST = 'Asia/Kolkata';
const today = (): string => localDateOf(new Date(), IST);
const FIXTURES = new URL('../../../../../packages/core/test/fixtures/messit-2026-09-24/', import.meta.url);
const CAPTURE_DAY = '2026-09-24';

function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
}

/** The capture with every date moved so that 2026-09-24 is today; optionally only dates before `before`. */
function shifted(name: string, opts: { before?: string } = {}): string {
  const payload = JSON.parse(readFileSync(fileURLToPath(new URL(`${name}.json`, FIXTURES)), 'utf8')) as {
    hostel: number;
    mess: number;
    menu: { date: string; menu: unknown[] }[];
  };
  const by = daysBetween(CAPTURE_DAY, today());
  const menu = payload.menu
    .map((d) => ({ ...d, date: addDays(d.date, by) }))
    .filter((d) => opts.before === undefined || d.date < opts.before);
  return JSON.stringify({ ...payload, menu });
}

const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);
const nameOf = (url: string): string => /(hostel-\d-mess-\d)\.json$/.exec(url)?.[1] ?? url;
const scripted = (bodies: Record<string, string>): MirrorFetcher => async (url): Promise<FetchOutcome> => {
  const body = bodies[nameOf(url)];
  return body === undefined ? { ok: false } : { ok: true, body };
};

describeIfDb('/v1/mess/menu/recommend (real Postgres)', { timeout: 30_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let handle: DatabaseHandle;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let ip = 0;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    handle = createDatabase(url);
    await seedMesses(handle.db);
    await sql`delete from mess_menu_snapshots`;
    await sql`delete from mess_dish_nutrition`;
    // Today is published everywhere except women's special, whose copy stops yesterday (→ inferred).
    const bodies = Object.fromEntries(NAMES.map((name) => [name, shifted(name)]));
    bodies['hostel-2-mess-1'] = shifted('hostel-2-mess-1', { before: today() });
    const report = await runMirror(handle, { fetcher: scripted(bodies) });
    expect(report.messes.every((m) => m.outcome === 'new')).toBe(true);
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'rec-%'`;
    await sql`delete from mess_menu_snapshots`;
    await sql`delete from mess_dish_nutrition`;
    await app.close();
    await handle.client.end({ timeout: 5 });
    await sql.end({ timeout: 5 });
  });

  const headers = (token: string) => {
    ip += 1;
    return { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.20.${Math.floor(ip / 250) % 250}.${ip % 250}` };
  };

  interface TestUser {
    token: string;
    id: string;
  }

  interface Setup {
    mess?: { hostelId: string; messId: string } | null;
    diet?: 'vegetarian' | 'eggetarian' | 'non-vegetarian';
    allergies?: { allergen: string; severity: 'mild' | 'moderate' | 'severe' }[];
    goal?: string | null;
    targets?: { kcal: number; protein: number; carb: number; fat: number } | null;
  }

  async function user(s: Setup = {}): Promise<TestUser> {
    n += 1;
    const token = `rec-tok-${n}`;
    verifier.accept(token, { uid: `rec-uid-${n}`, email: `rec${n}@vit.ac.in` });
    const r = await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} });
    expect(r.statusCode, r.body).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`rec-uid-${n}`}`;
    const u = { token, id: row!.id };
    const mess = s.mess === undefined ? { hostelId: 'mens', messId: 'veg' } : s.mess;
    if (mess !== null) {
      const p = await app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: headers(token), payload: { isVitStudent: true, mess: { providerId: 'vit-vellore', ...mess } } });
      expect(p.statusCode, p.body).toBe(200);
    }
    const d = await app.inject({
      method: 'PUT', url: '/v1/user/diet-preferences', headers: headers(token),
      payload: { dietType: s.diet ?? 'vegetarian', allergies: s.allergies ?? [] },
    });
    expect(d.statusCode, d.body).toBe(200);
    if (s.goal !== null) await sql`insert into user_goals (user_id, goal_type) values (${u.id}, ${s.goal ?? 'muscle-gain'})`;
    const t = s.targets === undefined ? { kcal: 2400, protein: 140, carb: 290, fat: 70 } : s.targets;
    if (t !== null) {
      await sql`
        insert into nutrition_targets (user_id, effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale, reason)
        values (${u.id}, '2026-01-01', ${t.kcal}, ${t.protein}, ${t.carb}, ${t.fat}, 30, 1700, 2500, ${sql.json(['test'])}, 'onboarding')`;
    }
    return u;
  }

  const get = (u: TestUser, query: string) => app.inject({ method: 'GET', url: `/v1/mess/menu/recommend${query}`, headers: headers(u.token) });
  async function rec(u: TestUser, query: string): Promise<MessRecommendation> {
    const r = await get(u, query);
    expect(r.statusCode, r.body).toBe(200);
    return r.json();
  }
  const post = (u: TestUser, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/nutrition/logs', headers: headers(u.token), payload: body });

  // ------------------------------------------------------------- access --

  it('401 without a session; 404 with no mess; 422 for a past day, the day after tomorrow, or a bad meal', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/mess/menu/recommend' })).statusCode).toBe(401);
    const noMess = await user({ mess: null });
    expect((await get(noMess, '')).statusCode).toBe(404);
    expect((await get(noMess, '?mess=mens-veg&slot=lunch')).statusCode).toBe(200); // browsing a mess still works
    const u = await user();
    expect((await get(u, `?date=${addDays(today(), -1)}`)).statusCode).toBe(422);
    expect((await get(u, `?date=${addDays(today(), 2)}`)).statusCode).toBe(422);
    expect((await get(u, '?slot=brunch')).statusCode).toBe(422);
    expect((await get(u, '?mess=nope-mess')).statusCode).toBe(404);
  });

  it('core and contract allergen lists are the same', () => {
    expect([...ALLERGENS]).toEqual([...CORE_ALLERGENS]);
  });

  // ---------------------------------------------------------- the plate --

  it('a vegetarian lunch: ranges, confidence, coded reasons, filters, and only veg dishes', async () => {
    const u = await user({ diet: 'vegetarian' });
    const r = await rec(u, '?slot=lunch');
    expect(r).toMatchObject({ status: 'ok', slot: 'lunch', loggable: true, basis: 'published', filters: { diet: 'vegetarian', allergies: [] }, goal: 'muscle-gain' });
    expect(r.plates.length).toBeGreaterThan(0);
    const dietOf = new Map(r.dishes.map((d) => [d.dishSlug, d.diet]));
    for (const p of r.plates) {
      expect(p.totals.kcalLow).toBeLessThan(p.totals.kcalHigh);
      expect(['medium', 'low']).toContain(p.confidence);
      expect(p.reasons.map((x) => x.code)).toContain('goal-weighting');
      for (const i of p.items) expect(dietOf.get(i.dishSlug)).toBe('veg');
    }
    for (const d of r.dishes) expect(d.reasons.length).toBeGreaterThan(0);
  });

  it('plate items are the Phase 8 snapshot of the STORED estimate; logging the plate stores exactly them, once', async () => {
    const u = await user({ diet: 'vegetarian' });
    const r = await rec(u, '?slot=lunch');
    const plate = r.plates[0]!;
    for (const item of plate.items) {
      const [row] = await sql<{ kcal_low: string; kcal_high: string; protein_low: string; protein_high: string; carb_low: string; carb_high: string; fat_low: string; fat_high: string }[]>`
        select * from mess_dish_nutrition where dish_slug = ${item.dishSlug}`;
      const snap = snapshotNutrition({
        macros: {
          kcalLow: Number(row!.kcal_low), kcalHigh: Number(row!.kcal_high), proteinLow: Number(row!.protein_low), proteinHigh: Number(row!.protein_high),
          carbLow: Number(row!.carb_low), carbHigh: Number(row!.carb_high), fatLow: Number(row!.fat_low), fatHigh: Number(row!.fat_high),
        },
        fibre: null,
      }, item.servings).macros;
      expect({ kcalLow: item.kcalLow, kcalHigh: item.kcalHigh, proteinLow: item.proteinLow, proteinHigh: item.proteinHigh }).toEqual({
        kcalLow: snap.kcalLow, kcalHigh: snap.kcalHigh, proteinLow: snap.proteinLow, proteinHigh: snap.proteinHigh,
      });
    }
    const body = {
      clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'mess', mess: 'mens-veg', menuDate: r.date,
      items: plate.items.map((i) => ({ dishSlug: i.dishSlug, servings: i.servings })),
    };
    const first = await post(u, body);
    expect(first.statusCode, first.body).toBe(201);
    const logged = (first.json() as CreateLogResponse).log.items;
    expect(logged.map((i) => [i.messDishSlug, i.servings, i.kcalLow, i.kcalHigh, i.proteinLow, i.proteinHigh])).toEqual(
      plate.items.map((i) => [i.dishSlug, i.servings, i.kcalLow, i.kcalHigh, i.proteinLow, i.proteinHigh]),
    );
    const again = await post(u, body);
    expect(again.statusCode).toBe(200);
    const counted = await sql<{ count: string }[]>`select count(*)::text as count from food_logs where user_id = ${u.id}`;
    expect(Number(counted[0]?.count)).toBe(1);
    // The lunch is now logged: asking again marks it, and the default moves on.
    const after = await rec(u, '?slot=lunch');
    expect(after.slotAlreadyLogged).toBe(true);
  });

  it('a changed estimate changes the next plate; the logged snapshot does not move', async () => {
    const u = await user({ diet: 'vegetarian' });
    const r = await rec(u, '?slot=lunch');
    const item = r.plates[0]!.items[0]!;
    const logged: CreateLogResponse = (await post(u, {
      clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'mess', mess: 'mens-veg', menuDate: r.date,
      items: [{ dishSlug: item.dishSlug, servings: item.servings }],
    })).json();
    const [before] = await sql<{ kcal_low: string; kcal_high: string }[]>`select kcal_low, kcal_high from mess_dish_nutrition where dish_slug = ${item.dishSlug}`;
    await sql`update mess_dish_nutrition set kcal_high = kcal_high + 100 where dish_slug = ${item.dishSlug}`;
    try {
      const again = await rec(u, '?slot=lunch');
      const same = again.plates.flatMap((p) => p.items).find((i) => i.dishSlug === item.dishSlug && i.servings === item.servings);
      if (same !== undefined) expect(same.kcalHigh).toBeGreaterThan(item.kcalHigh);
      const day = (await app.inject({ method: 'GET', url: `/v1/nutrition/day/${r.date}`, headers: headers(u.token) })).json();
      const stored = day.logs.find((l: { clientLogId: string }) => l.clientLogId === logged.log.clientLogId).items[0];
      expect(stored.kcalHigh).toBe(logged.log.items[0]!.kcalHigh);
    } finally {
      await sql`update mess_dish_nutrition set kcal_low = ${before!.kcal_low}, kcal_high = ${before!.kcal_high} where dish_slug = ${item.dishSlug}`;
    }
  });

  // ------------------------------------------------------------ safety --

  it('allergies are a hard filter: every plate dish is confirmed free; severity changes nothing', async () => {
    const mild = await user({ diet: 'vegetarian', allergies: [{ allergen: 'peanut', severity: 'mild' }, { allergen: 'milk', severity: 'mild' }] });
    const severe = await user({ diet: 'vegetarian', allergies: [{ allergen: 'peanut', severity: 'severe' }, { allergen: 'milk', severity: 'severe' }] });
    const a = await rec(mild, '?slot=lunch');
    const b = await rec(severe, '?slot=lunch');
    expect(a.filters.allergies).toEqual(['milk', 'peanut']);
    expect(a.plates).toEqual(b.plates);
    expect(a.dishes).toEqual(b.dishes);
    for (const p of a.plates) {
      for (const i of p.items) {
        for (const al of ['peanut', 'milk'] as const) expect(allergenStatus(i.name, al, 'veg')).toBe('free');
      }
    }
    const curd = a.dishes.find((d) => d.dishSlug === 'curd');
    if (curd !== undefined) expect(curd.reasons).toContainEqual({ code: 'allergen', allergen: 'milk', status: 'contains' });
  });

  it('no data crosses users: one user\'s diet, allergies and logs never change another\'s result', async () => {
    const b = await user({ diet: 'non-vegetarian', mess: { hostelId: 'womens', messId: 'nonveg' } });
    const before = await rec(b, '?slot=dinner');
    const a = await user({ diet: 'vegetarian', allergies: [{ allergen: 'wheat', severity: 'severe' }], mess: { hostelId: 'womens', messId: 'nonveg' } });
    const aRec = await rec(a, '?slot=dinner');
    await post(a, {
      clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'quick-add', quickAdd: { kcal: 900, proteinG: 30, carbG: 100, fatG: 30 },
    });
    const after = await rec(b, '?slot=dinner');
    expect(after).toEqual(before);
    expect(aRec.filters).toEqual({ diet: 'vegetarian', allergies: ['wheat'] });
    expect(before.filters).toEqual({ diet: 'non-vegetarian', allergies: [] });
  });

  it('browsing another mess applies the caller\'s own filters', async () => {
    const u = await user({ diet: 'vegetarian' }); // mens-veg configured
    const r = await rec(u, '?mess=womens-nonveg&slot=dinner');
    expect(r.mess.code).toBe('womens-nonveg');
    const dietOf = new Map(r.dishes.map((d) => [d.dishSlug, d.diet]));
    for (const p of r.plates) for (const i of p.items) expect(dietOf.get(i.dishSlug)).toBe('veg');
    expect(r.dishes.some((d) => d.reasons.some((x) => x.code === 'diet'))).toBe(true);
  });

  // ------------------------------------------------------- the day state --

  it('tomorrow: planning only — not loggable, nothing counted as eaten, breakfast by default', async () => {
    const u = await user({ diet: 'vegetarian' });
    await post(u, { clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'quick-add', quickAdd: { kcal: 2000, proteinG: 50, carbG: 250, fatG: 60 } });
    const r = await rec(u, `?date=${addDays(today(), 1)}`);
    expect(r).toMatchObject({ date: addDays(today(), 1), slot: 'breakfast', loggable: false, slotAlreadyLogged: false, postWorkout: false });
    expect(r.target).toEqual({ share: 0.25, kcal: 600, protein: 35, carb: 72.5, fat: 17.5 });
  });

  it('the default meal is the next one not logged today', async () => {
    const u = await user({ diet: 'vegetarian' });
    const hour = localHourOf(new Date(), IST);
    const expected = defaultRecommendationSlot(true, hour, []);
    const r = await rec(u, '');
    expect(r.slot).toBe(expected.slot);
  });

  it('zero calorie budget: no plate, the protein still needed reported', async () => {
    const u = await user({ diet: 'vegetarian', targets: { kcal: 1500, protein: 120, carb: 200, fat: 50 } });
    await post(u, { clientLogId: randomUUID(), mealSlot: 'breakfast', entryMethod: 'quick-add', quickAdd: { kcal: 1600, proteinG: 40, carbG: 200, fatG: 50 } });
    const r = await rec(u, '?slot=dinner');
    expect(r.status).toBe('target-reached');
    expect(r.plates).toEqual([]);
    expect(r.target?.kcal).toBe(0);
    expect(r.target?.protein).toBeGreaterThan(0);
  });

  it('no targets yet', async () => {
    const u = await user({ targets: null });
    expect((await rec(u, '?slot=lunch')).status).toBe('no-targets');
  });

  it('an inferred menu is labelled on every plate; an unavailable one gets none; a stale copy says so', async () => {
    const u = await user({ diet: 'vegetarian', mess: { hostelId: 'womens', messId: 'special' } });
    const inferred = await rec(u, '?slot=lunch');
    expect(inferred.resolution.kind).toBe('cycle-inferred');
    expect(inferred.basis).toBe('inferred');
    for (const p of inferred.plates) expect(p.reasons.some((x) => x.code === 'inferred-menu')).toBe(true);

    const [mess] = await sql<{ id: string }[]>`select id from messes where code = 'womens-veg'`;
    const saved = await sql<{ raw_payload: unknown; payload_hash: string; dates: string[] }[]>`select raw_payload, payload_hash, dates from mess_menu_snapshots where mess_id = ${mess!.id}`;
    await sql`delete from mess_menu_snapshots where mess_id = ${mess!.id}`;
    try {
      const none = await rec(u, '?mess=womens-veg&slot=lunch');
      expect(none).toMatchObject({ status: 'menu-unavailable', plates: [], basis: null });
    } finally {
      for (const s of saved) {
        await sql`insert into mess_menu_snapshots (mess_id, raw_payload, payload_hash, dates) values (${mess!.id}, ${sql.json(s.raw_payload as never)}, ${s.payload_hash}, ${s.dates})`;
      }
    }

    await sql`update messes set last_success_at = now() - interval '25 hours' where code = 'mens-veg'`;
    try {
      const stale = await rec(u, '?mess=mens-veg&slot=lunch');
      expect(stale.mess.freshness.stale).toBe(true);
      expect(stale.status).toBe('ok');
    } finally {
      await sql`update messes set last_success_at = now() where code = 'mens-veg'`;
    }
  });

  it('a snack gets a plate (§15.1 roles)', async () => {
    const u = await user({ diet: 'non-vegetarian', mess: { hostelId: 'mens', messId: 'nonveg' } });
    const r = await rec(u, '?slot=snacks');
    expect(r.status).toBe('ok');
    expect(r.plates.length).toBeGreaterThan(0);
    for (const d of r.dishes.filter((x) => ['tea', 'coffee', 'milk'].includes(x.dishSlug))) expect(d.reasons).toEqual([{ code: 'ambient' }]);
  });

  it('post-workout: a session completed within 3 hours today counts; 4 hours ago does not', async () => {
    const u = await user({ diet: 'vegetarian' });
    const four = new Date(Date.now() - 4 * 3_600_000);
    await sql`insert into workout_sessions (user_id, name, status, started_at, completed_at, client_session_id) values (${u.id}, 'Push', 'completed', ${four}, ${four}, gen_random_uuid())`;
    expect((await rec(u, '?slot=dinner')).postWorkout).toBe(false);
    const two = new Date(Date.now() - 2 * 3_600_000);
    await sql`insert into workout_sessions (user_id, name, status, started_at, completed_at, client_session_id) values (${u.id}, 'Pull', 'completed', ${two}, ${two}, gen_random_uuid())`;
    const r = await rec(u, '?slot=dinner');
    expect(r.postWorkout).toBe(localDateOf(two, IST) === today());
    if (r.postWorkout && r.plates.length > 0) expect(r.plates[0]!.reasons.some((x) => x.code === 'post-workout-carbs')).toBe(true);
  });

  it('variety: a mess dish logged yesterday is penalised, never excluded', async () => {
    const u = await user({ diet: 'vegetarian' });
    const base = await rec(u, '?slot=lunch');
    const dish = base.plates[0]!.items[0]!.dishSlug;
    const yesterdayNoon = new Date(Date.parse(`${addDays(today(), -1)}T06:30:00Z`)).toISOString();
    const log = await post(u, {
      clientLogId: randomUUID(), loggedAt: yesterdayNoon, mealSlot: 'lunch', entryMethod: 'mess', mess: 'mens-veg', menuDate: addDays(today(), -1),
      items: [{ dishSlug: dish, servings: 1 }],
    });
    // The dish may not be on yesterday's menu; if so, log it from today's instead (still yesterday's day).
    if (log.statusCode !== 201) {
      const retry = await post(u, {
        clientLogId: randomUUID(), loggedAt: yesterdayNoon, mealSlot: 'lunch', entryMethod: 'mess', mess: 'mens-veg', menuDate: today(),
        items: [{ dishSlug: dish, servings: 1 }],
      });
      expect(retry.statusCode, retry.body).toBe(201);
    }
    const r = await rec(u, '?slot=lunch');
    const outcome = r.dishes.find((d) => d.dishSlug === dish)!;
    expect(outcome.reasons.every((x) => !['diet', 'allergen', 'disliked'].includes(x.code))).toBe(true);
    for (const p of r.plates) {
      if (p.items.some((i) => i.dishSlug === dish)) expect(p.reasons).toContainEqual({ code: 'repeat', dishSlug: dish, days: 1 });
    }
  });

  it('shortfall is the top plate\'s own gap, never inflated', async () => {
    const u = await user({ diet: 'vegetarian', targets: { kcal: 2400, protein: 200, carb: 290, fat: 70 } });
    const r = await rec(u, '?slot=dinner');
    const top = r.plates[0]!;
    const gap = r.shortfall?.protein;
    expect(gap).toBeTruthy();
    expect(gap!.gapLow).toBeCloseTo(r.target!.protein - top.totals.proteinHigh, 5);
    expect(gap!.gapHigh).toBeCloseTo(r.target!.protein - top.totals.proteinLow, 5);
  });

  it('deterministic and fast: the same request twice is identical; p95 under 200 ms', async () => {
    const u = await user({ diet: 'eggetarian', allergies: [{ allergen: 'peanut', severity: 'moderate' }] });
    const a = await rec(u, '?slot=dinner');
    const b = await rec(u, '?slot=dinner');
    expect(b).toEqual(a);
    const times: number[] = [];
    for (let i = 0; i < 20; i += 1) {
      const t = performance.now();
      const r = await get(u, `?slot=${['breakfast', 'lunch', 'snacks', 'dinner'][i % 4]}`);
      times.push(performance.now() - t);
      expect(r.statusCode).toBe(200);
    }
    times.sort((x, y) => x - y);
    expect(times[Math.floor(times.length * 0.95) - 1]).toBeLessThan(200);
  });
});
