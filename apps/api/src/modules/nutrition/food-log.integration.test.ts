/**
 * Food logging through the HTTP surface on real Postgres with the real food
 * seed (Phase 8). §31: rollups across timezone boundaries, macros snapshotted
 * at log time that do not change when the food table is corrected, idempotent
 * re-log; deleting a log updates totals; the day boundary follows
 * users.timezone. Plus the owner's J-decisions: ranges, unknown fibre, target
 * history, 30 days back, quick add, saved meals, recent foods, the daily
 * cache equal to a recompute, and the latency budget.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  ENTRY_METHODS,
  MEAL_SLOTS,
  type CreateLogResponse,
  type Food,
  type FoodSearchResponse,
  type NutritionDay,
  type RecentFoodsResponse,
  type SavedMeal,
  type SavedMealsResponse,
} from '@fitos/contracts';
import { ENTRY_METHODS as CORE_ENTRY_METHODS, MEAL_SLOTS as CORE_MEAL_SLOTS, addDays, localDateOf } from '@fitos/core/nutrition/log';

import { createDatabase } from '../../db/client.js';
import { seedFoods } from '../../db/food-seed/load.js';
import { migrateUp } from '../../db/migrate.js';
import { rebuildNutrition } from '../../db/rebuild-nutrition.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { rebuildDailyNutrition } from './log-repository.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describe('vocabulary', () => {
  it('meal slots and entry methods are the same in core and the contract', () => {
    expect([...MEAL_SLOTS]).toEqual([...CORE_MEAL_SLOTS]);
    expect([...ENTRY_METHODS]).toEqual([...CORE_ENTRY_METHODS]);
  });
});

describeIfDb('/v1/nutrition logging (real Postgres, real food seed)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let ip = 0;
  const foodId = new Map<string, string>();
  const IST = 'Asia/Kolkata';
  const today = () => localDateOf(new Date(), IST);

  beforeAll(async () => {
    await migrateUp(url);
    await seedFoods(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
    const rows = await sql<{ slug: string; id: string }[]>`select slug, id from foods where owner_user_id is null`;
    for (const r of rows) foodId.set(r.slug, r.id);
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'flog-%'`;
    // The immutability tests correct seed rows; put the seed back as it was.
    await seedFoods(url);
    await app.close();
    await sql.end({ timeout: 5 });
  });

  // A fresh client address per request keeps the per-IP limiter (120/min) out of the bulk runs.
  const headers = (token: string) => {
    ip += 1;
    return { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.18.${Math.floor(ip / 250) % 250}.${ip % 250}` };
  };

  interface TestUser {
    token: string;
    id: string;
  }

  async function user(): Promise<TestUser> {
    n += 1;
    const token = `flog-tok-${n}`;
    verifier.accept(token, { uid: `flog-uid-${n}`, email: `flog${n}@vit.ac.in` });
    const r = await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} });
    expect(r.statusCode, r.body).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`flog-uid-${n}`}`;
    return { token, id: row!.id };
  }

  async function setTargets(u: TestUser, effectiveFrom: string, kcal: number, proteinG: number): Promise<void> {
    await sql`
      insert into nutrition_targets (user_id, effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale, reason)
      values (${u.id}, ${effectiveFrom}, ${kcal}, ${proteinG}, 250, 70, 30, 1700, 2500, ${sql.json(['test'])}, 'onboarding')`;
  }

  const post = (u: TestUser, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/nutrition/logs', headers: headers(u.token), payload: body });
  const del = (u: TestUser, clientLogId: string) =>
    app.inject({ method: 'DELETE', url: `/v1/nutrition/logs/${clientLogId}`, headers: headers(u.token) });
  const get = (u: TestUser, path: string) => app.inject({ method: 'GET', url: `/v1${path}`, headers: headers(u.token) });

  async function day(u: TestUser, date?: string): Promise<NutritionDay> {
    const r = await get(u, date === undefined ? '/nutrition/today' : `/nutrition/day/${date}`);
    expect(r.statusCode, r.body).toBe(200);
    return r.json();
  }

  const food = (slug: string, basis: 'per_100g' | 'per_serving', servingLabel: string, portion: { servings?: number; grams?: number }) => ({
    foodId: foodId.get(slug)!,
    basis,
    servingLabel,
    ...portion,
  });

  const logBody = (items: unknown[], extra: Record<string, unknown> = {}) => ({
    clientLogId: randomUUID(),
    mealSlot: 'lunch',
    entryMethod: 'search',
    items,
    ...extra,
  });

  async function logOk(u: TestUser, body: Record<string, unknown>): Promise<CreateLogResponse> {
    const r = await post(u, body);
    expect(r.statusCode, r.body).toBe(201);
    return r.json();
  }

  // ------------------------------------------------------------- basics --

  it('401 without a session on every route', async () => {
    for (const [method, path] of [
      ['GET', '/v1/nutrition/today'],
      ['GET', `/v1/nutrition/day/${today()}`],
      ['POST', '/v1/nutrition/logs'],
      ['DELETE', `/v1/nutrition/logs/${randomUUID()}`],
      ['GET', '/v1/nutrition/foods/recent'],
      ['GET', '/v1/nutrition/saved-meals'],
      ['POST', '/v1/nutrition/saved-meals'],
    ] as const) {
      const r = await app.inject(method === 'POST' ? { method, url: path, payload: {} } : { method, url: path });
      expect(r.statusCode, `${method} ${path}`).toBe(401);
    }
  });

  it('an empty day: zero consumed, nothing unknown, no logs; no targets yet → no remaining', async () => {
    const u = await user();
    const d = await day(u);
    expect(d).toMatchObject({ date: today(), today: today(), timezone: IST, targets: null, remaining: null, logs: [] });
    expect(d.totals).toMatchObject({ kcalLow: 0, kcalHigh: 0, fibreUnknownItems: 0, itemCount: 0 });
  });

  // ---------------------------------------------------------- create --

  it('create: 201, the item is a snapshot of the row × portion, totals follow in the same response', async () => {
    const u = await user();
    await setTargets(u, addDays(today(), -60), 2400, 140);
    const r = await logOk(u, logBody([food('dal-tadka', 'per_serving', '1 katori', { servings: 1.5 })]));
    const item = r.log.items[0]!;
    expect(item).toMatchObject({
      position: 0,
      foodId: foodId.get('dal-tadka'),
      foodName: 'Dal tadka',
      foodSource: 'estimated',
      basis: 'per_serving',
      servingLabel: '1 katori',
      servingGrams: 150,
      servings: 1.5,
      grams: 225,
      kcalLow: 180,
      kcalHigh: 278,
      proteinLow: 9,
      proteinHigh: 13.5,
      fibreLow: null,
      fibreHigh: null,
      confidence: 'medium',
    });
    expect(r.log).toMatchObject({ localDate: today(), mealSlot: 'lunch', entryMethod: 'search', savedMealId: null });
    expect(r.day.totals).toMatchObject({ kcalLow: 180, kcalHigh: 278, fibreUnknownItems: 1, itemCount: 1 });
    expect(r.day.remaining!.kcal).toEqual({ target: 2400, low: 2122, high: 2220, state: 'under' });
    expect(r.day.logs.map((l) => l.clientLogId)).toEqual([r.log.clientLogId]);
  });

  it('an exact USDA row stays exact; grams convert on a per-100 g row; several items in one log', async () => {
    const u = await user();
    const r = await logOk(u, logBody([
      food('honey', 'per_serving', '1 tbsp', { servings: 2 }),
      food('milk-whole', 'per_100g', '100 g', { grams: 250 }),
    ]));
    expect(r.log.items.map((i) => [i.kcalLow, i.kcalHigh, i.servings, i.grams])).toEqual([
      [128, 128, 2, 42],
      [150, 150, 2.5, 250],
    ]);
    expect(r.log.items[0]!.fibreLow).toBe(0); // USDA reports 0 g in a tbsp: known
    expect(r.log.items[1]!.fibreLow).toBeNull(); // USDA does not report milk fibre: unknown
    expect(r.log.totals).toMatchObject({ kcalLow: 278, kcalHigh: 278, fibreKnownLow: 0, fibreUnknownItems: 1, itemCount: 2 });
  });

  it('portion rules: 0.01 steps, bounds, grams only where the row has a weight, the row must exist', async () => {
    const u = await user();
    const bad = [
      food('dal-tadka', 'per_serving', '1 katori', { servings: 1.005 }),
      food('dal-tadka', 'per_serving', '1 katori', { servings: 0.05 }),
      food('dal-tadka', 'per_serving', '1 katori', { servings: 21 }),
      food('dal-tadka', 'per_serving', '1 katori', { grams: 5001 }),
      food('dal-tadka', 'per_serving', '1 katori', { servings: 1, grams: 150 }),
      food('dal-tadka', 'per_serving', '2 katori', { servings: 1 }),
      food('dal-tadka', 'per_100g', '100 g', { servings: 1 }),
    ];
    for (const item of bad) expect((await post(u, logBody([item]))).statusCode, JSON.stringify(item)).toBe(422);
    // A custom serving with no weight takes servings, not grams.
    const custom: Food = (
      await app.inject({
        method: 'POST',
        url: '/v1/nutrition/foods',
        headers: headers(u.token),
        payload: { clientFoodId: randomUUID(), name: 'Mess Laddu', basis: 'per_serving', servingLabel: '1 laddu', kcal: 180, proteinG: 3, carbG: 25, fatG: 8 },
      })
    ).json();
    const grams = await post(u, logBody([{ foodId: custom.id, basis: 'per_serving', servingLabel: '1 laddu', grams: 40 }]));
    expect(grams.statusCode).toBe(422);
    expect(grams.json().error.details[0].issue).toMatch(/no weight/);
    const ok = await logOk(u, logBody([{ foodId: custom.id, basis: 'per_serving', servingLabel: '1 laddu', servings: 2 }]));
    expect(ok.log.items[0]).toMatchObject({ grams: null, servingGrams: null, kcalLow: 360, foodSource: 'user' });
    expect((await day(u)).totals.itemCount).toBe(1);
  });

  // ------------------------------------------------------- idempotency --

  it('replay: the same clientLogId returns the same log with 200 and counts nothing twice', async () => {
    const u = await user();
    const body = logBody([food('chapati', 'per_serving', '1 piece', { servings: 3 })]);
    const first = await post(u, body);
    const second = await post(u, body);
    const changed = await post(u, { ...body, items: [food('honey', 'per_serving', '1 cup', { servings: 1 })] });
    expect([first.statusCode, second.statusCode, changed.statusCode]).toEqual([201, 200, 200]);
    expect((second.json() as CreateLogResponse).log.id).toBe((first.json() as CreateLogResponse).log.id);
    expect((changed.json() as CreateLogResponse).log.items[0]!.foodName).toBe('Chapati');
    const d = await day(u);
    expect(d.logs).toHaveLength(1);
    expect(d.totals).toMatchObject({ kcalLow: 255, kcalHigh: 360, itemCount: 1 });
  });

  it('concurrent replays of one log make one log and add once', async () => {
    const u = await user();
    const body = logBody([food('chapati', 'per_serving', '1 piece', { servings: 2 })]);
    const rs = await Promise.all([post(u, body), post(u, body), post(u, body), post(u, body)]);
    expect(rs.filter((r) => r.statusCode === 201)).toHaveLength(1);
    expect(rs.every((r) => r.statusCode === 200 || r.statusCode === 201)).toBe(true);
    expect(new Set(rs.map((r) => (r.json() as CreateLogResponse).log.id)).size).toBe(1);
    const d = await day(u);
    expect(d.totals).toMatchObject({ kcalLow: 170, kcalHigh: 240, itemCount: 1 });
    const [c] = await sql<{ n: number }[]>`select count(*)::int as n from food_logs where client_log_id = ${body.clientLogId}`;
    expect(c!.n).toBe(1);
  });

  // ------------------------------------------------------------ delete --

  it('delete removes exactly that log from the totals; a replayed delete is 200; unknown is 404', async () => {
    const u = await user();
    const a = await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 2 })]));
    const b = await logOk(u, logBody([food('honey', 'per_serving', '1 tbsp', { servings: 1 })], { mealSlot: 'snacks' }));
    expect(b.day.totals).toMatchObject({ kcalLow: 234, kcalHigh: 304, itemCount: 2 });
    const r1 = await del(u, a.log.clientLogId);
    expect(r1.statusCode, r1.body).toBe(200);
    const after = (r1.json() as { day: NutritionDay }).day;
    expect(after.totals).toMatchObject({ kcalLow: 64, kcalHigh: 64, itemCount: 1, fibreUnknownItems: 0 });
    expect(after.logs.map((l) => l.clientLogId)).toEqual([b.log.clientLogId]);
    const r2 = await del(u, a.log.clientLogId);
    expect(r2.statusCode).toBe(200);
    expect((r2.json() as { day: NutritionDay }).day.totals.itemCount).toBe(1);
    expect((await del(u, randomUUID())).statusCode).toBe(404);
    // Soft delete: the row stays, marked.
    const [row] = await sql<{ deleted_at: Date | null }[]>`select deleted_at from food_logs where user_id = ${u.id} and client_log_id = ${a.log.clientLogId}`;
    expect(row!.deleted_at).not.toBeNull();
    // Deleting the last item leaves no cache row — what a rebuild would produce.
    await del(u, b.log.clientLogId);
    const rows = await sql`select * from daily_nutrition where user_id = ${u.id}`;
    expect(rows).toHaveLength(0);
    expect((await day(u)).totals.itemCount).toBe(0);
  });

  it('a replayed create after its delete does not resurrect it', async () => {
    const u = await user();
    const body = logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })]);
    await logOk(u, body);
    await del(u, body.clientLogId);
    const replay = await post(u, body);
    expect(replay.statusCode).toBe(200);
    expect((await day(u)).totals.itemCount).toBe(0);
  });

  it("another user's log cannot be deleted or seen", async () => {
    const a = await user();
    const b = await user();
    const log = await logOk(a, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })]));
    expect((await del(b, log.log.clientLogId)).statusCode).toBe(404);
    expect((await day(b)).logs).toEqual([]);
    expect((await day(a)).totals.itemCount).toBe(1);
    // The same clientLogId is a separate log for another user (unique per user, owner J12).
    const theirs = await post(b, logBody([food('chapati', 'per_serving', '1 piece', { servings: 2 })], { clientLogId: log.log.clientLogId }));
    expect(theirs.statusCode).toBe(201);
  });

  // -------------------------------------------------- snapshot integrity --

  it('CORRECTING the food later changes nothing already logged (§31) — at the API and in the database', async () => {
    const u = await user();
    const honeyId = foodId.get('honey')!;
    const r = await logOk(u, logBody([food('honey', 'per_serving', '1 tbsp', { servings: 2 })]));
    const before = await day(u);
    // The food table is corrected: new values, a new name.
    await sql`update food_nutrition set kcal_low = 99, kcal_high = 99, protein_low = 9, protein_high = 9 where food_id = ${honeyId} and serving_label = '1 tbsp'`;
    await sql`update foods set name = 'Honey (corrected)' where id = ${honeyId}`;
    const after = await day(u);
    expect(after.logs).toEqual(before.logs);
    expect(after.totals).toEqual(before.totals);
    expect(after.logs[0]!.items[0]).toMatchObject({ foodName: 'Honey', kcalLow: 128, kcalHigh: 128, proteinLow: 0.2 });
    const [row] = await sql<{ food_name: string; kcal_low: string; serving_label: string; serving_grams: string; servings: string; grams: string; food_source: string }[]>`
      select food_name, kcal_low, serving_label, serving_grams, servings, grams, food_source from food_log_items i
      join food_logs l on l.id = i.food_log_id where l.client_log_id = ${r.log.clientLogId}`;
    expect(row).toEqual({ food_name: 'Honey', kcal_low: '128.00', serving_label: '1 tbsp', serving_grams: '21.00', servings: '2.0000', grams: '42.0', food_source: 'usda' });
    // A NEW log snapshots the corrected values.
    const later = await logOk(u, logBody([food('honey', 'per_serving', '1 tbsp', { servings: 2 })]));
    expect(later.log.items[0]).toMatchObject({ foodName: 'Honey (corrected)', kcalLow: 198 });
    await seedFoods(url); // restore the seed row
  });

  it('REMOVING the food keeps the logged item whole (food_id set null, snapshot intact)', async () => {
    const u = await user();
    const custom: Food = (
      await app.inject({
        method: 'POST',
        url: '/v1/nutrition/foods',
        headers: headers(u.token),
        payload: { clientFoodId: randomUUID(), name: 'Protein Bar X', basis: 'per_serving', servingLabel: '1 bar', servingGrams: 60, kcal: 220, proteinG: 20, carbG: 22, fatG: 7, fibreG: 5 },
      })
    ).json();
    await logOk(u, logBody([{ foodId: custom.id, basis: 'per_serving', servingLabel: '1 bar', servings: 1 }]));
    await sql`delete from foods where id = ${custom.id}`;
    const item = (await day(u)).logs[0]!.items[0]!;
    expect(item).toMatchObject({ foodId: null, foodName: 'Protein Bar X', kcalLow: 220, proteinLow: 20, fibreLow: 5, servingLabel: '1 bar', servingGrams: 60, foodSource: 'user' });
  });

  // ------------------------------------------------------------ dates --

  it('the IST day boundary: 23:59 and 00:01 land on their own days; totals roll up per day', async () => {
    const u = await user();
    const d1 = addDays(today(), -2);
    const d2 = addDays(today(), -1);
    const late = await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })], { loggedAt: `${d1}T23:59:00+05:30`, mealSlot: 'dinner' }));
    const early = await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 2 })], { loggedAt: `${d2}T00:01:00+05:30`, mealSlot: 'snacks' }));
    // The same instants in UTC (18:29Z / 18:31Z) — the server's clock zone is irrelevant.
    expect(late.log.localDate).toBe(d1);
    expect(early.log.localDate).toBe(d2);
    expect((await day(u, d1)).totals).toMatchObject({ kcalLow: 85, itemCount: 1 });
    expect((await day(u, d2)).totals).toMatchObject({ kcalLow: 170, itemCount: 1 });
    expect((await day(u)).totals.itemCount).toBe(0);
  });

  it('the day is fixed at write time in users.timezone: a later zone change does not move it (owner J3)', async () => {
    const u = await user();
    const d = addDays(today(), -3);
    // 20:00 UTC is already the next day in IST.
    const r = await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })], { loggedAt: `${addDays(d, -1)}T20:00:00Z` }));
    expect(r.log.localDate).toBe(d);
    await sql`update users set timezone = 'UTC' where id = ${u.id}`;
    expect((await day(u, d)).logs.map((l) => l.clientLogId)).toEqual([r.log.clientLogId]);
    const utc = await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })], { loggedAt: `${addDays(d, -1)}T20:00:00Z` }));
    expect(utc.log.localDate).toBe(addDays(d, -1));
    expect((await day(u, d)).timezone).toBe('UTC');
  });

  it('future days are rejected; today and 30 days back are allowed; 31 days back is not (owner J4)', async () => {
    const u = await user();
    const tomorrow = addDays(today(), 1);
    expect((await post(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })], { loggedAt: `${tomorrow}T08:00:00+05:30` }))).statusCode).toBe(422);
    expect((await get(u, `/nutrition/day/${tomorrow}`)).statusCode).toBe(422);
    const d30 = addDays(today(), -30);
    expect((await post(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })], { loggedAt: `${d30}T12:00:00+05:30` }))).statusCode).toBe(201);
    const d31 = addDays(today(), -31);
    expect((await post(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 1 })], { loggedAt: `${d31}T12:00:00+05:30` }))).statusCode).toBe(422);
    expect((await get(u, '/nutrition/day/2026-13-01')).statusCode).toBe(422);
  });

  // ---------------------------------------------------------- targets --

  it("each day shows the target that was in effect THEN (owner J2); over target is shown as over", async () => {
    const u = await user();
    const old = addDays(today(), -20);
    const recent = addDays(today(), -5);
    await setTargets(u, old, 2000, 120);
    await setTargets(u, recent, 2600, 150);
    const d10 = addDays(today(), -10);
    expect((await day(u, d10)).targets).toMatchObject({ effectiveFrom: old, kcal: 2000 });
    expect((await day(u)).targets).toMatchObject({ effectiveFrom: recent, kcal: 2600 });
    expect((await day(u, addDays(today(), -25))).targets).toBeNull();
    // Over the older target on that day: remaining is negative, state over — never clamped.
    await logOk(u, logBody([food('honey', 'per_serving', '1 cup', { servings: 2 })], { loggedAt: `${d10}T13:00:00+05:30` }));
    const over = await day(u, d10);
    expect(over.remaining!.kcal).toEqual({ target: 2000, low: -62, high: -62, state: 'over' });
    // No target columns were copied anywhere: the cache has none.
    const cols = await sql<{ column_name: string }[]>`select column_name from information_schema.columns where table_name = 'daily_nutrition'`;
    expect(cols.map((c) => c.column_name).filter((c) => c.includes('target'))).toEqual([]);
  });

  // ------------------------------------------------------ custom foods --

  it("another user's custom food cannot be logged and never shows in recents", async () => {
    const a = await user();
    const b = await user();
    const custom: Food = (
      await app.inject({
        method: 'POST',
        url: '/v1/nutrition/foods',
        headers: headers(a.token),
        payload: { clientFoodId: randomUUID(), name: 'Private Shake', basis: 'per_serving', servingLabel: '1 glass', kcal: 300, proteinG: 30, carbG: 20, fatG: 10 },
      })
    ).json();
    const r = await post(b, logBody([{ foodId: custom.id, basis: 'per_serving', servingLabel: '1 glass', servings: 1 }]));
    expect(r.statusCode).toBe(404);
    await logOk(a, logBody([{ foodId: custom.id, basis: 'per_serving', servingLabel: '1 glass', servings: 1 }]));
    const recentB: RecentFoodsResponse = (await get(b, '/nutrition/foods/recent')).json();
    expect(recentB.items).toEqual([]);
    const recentA: RecentFoodsResponse = (await get(a, '/nutrition/foods/recent')).json();
    expect(recentA.items[0]!.food).toMatchObject({ id: custom.id, isCustom: true });
  });

  // --------------------------------------------------------- quick add --

  it('quick add: the user values, exact, unverified source, fibre unknown unless given (owner J6)', async () => {
    const u = await user();
    const r = await logOk(u, { clientLogId: randomUUID(), mealSlot: 'snacks', entryMethod: 'quick-add', quickAdd: { kcal: 250, proteinG: 12.5, carbG: 30, fatG: 9 } });
    expect(r.log.items[0]).toMatchObject({
      foodId: null,
      foodName: 'Quick add',
      foodSource: 'user',
      basis: null,
      servingLabel: null,
      servings: 1,
      grams: null,
      kcalLow: 250,
      kcalHigh: 250,
      proteinLow: 12.5,
      fibreLow: null,
      confidence: 'medium',
    });
    const named = await logOk(u, { clientLogId: randomUUID(), mealSlot: 'snacks', entryMethod: 'quick-add', quickAdd: { name: 'Canteen samosa', kcal: 260, proteinG: 4, carbG: 28, fatG: 15, fibreG: 2 } });
    expect(named.log.items[0]).toMatchObject({ foodName: 'Canteen samosa', fibreLow: 2 });
    expect(named.day.totals).toMatchObject({ kcalLow: 510, kcalHigh: 510, fibreKnownLow: 2, fibreUnknownItems: 1, itemCount: 2 });
    expect((await post(u, { clientLogId: randomUUID(), mealSlot: 'snacks', entryMethod: 'quick-add', quickAdd: { kcal: 250, proteinG: 1, carbG: 1 } })).statusCode).toBe(422);
  });

  // ------------------------------------------------------- saved meals --

  it('saved meals: made from logs, retry-safe, listed with a preview row, logged in one tap with CURRENT values, deleted', async () => {
    const u = await user();
    const a = await logOk(u, logBody([food('dal-tadka', 'per_serving', '1 katori', { servings: 1 }), food('chapati', 'per_serving', '1 piece', { servings: 2 })], { mealSlot: 'dinner' }));
    const b = await logOk(u, { clientLogId: randomUUID(), mealSlot: 'dinner', entryMethod: 'quick-add', quickAdd: { name: 'Curd', kcal: 60, proteinG: 3, carbG: 4, fatG: 3 } });
    const create = { clientMealId: randomUUID(), name: 'Usual dinner', fromClientLogIds: [a.log.clientLogId, b.log.clientLogId] };
    const r1 = await app.inject({ method: 'POST', url: '/v1/nutrition/saved-meals', headers: headers(u.token), payload: create });
    const r2 = await app.inject({ method: 'POST', url: '/v1/nutrition/saved-meals', headers: headers(u.token), payload: create });
    expect([r1.statusCode, r2.statusCode]).toEqual([201, 200]);
    const meal: SavedMeal = r1.json();
    expect((r2.json() as SavedMeal).id).toBe(meal.id);
    expect(meal.items.map((i) => (i.kind === 'food' ? [i.kind, i.foodName, i.servings] : i.kind === 'quick-add' ? [i.kind, i.name, i.kcal] : [i.kind, i.name, i.servings]))).toEqual([
      ['food', 'Dal tadka', 1],
      ['food', 'Chapati', 2],
      ['quick-add', 'Curd', 60],
    ]);
    expect(meal.items[0]!.kind === 'food' && meal.items[0]!.row).toMatchObject({ servingLabel: '1 katori', kcalLow: 120 });
    const list: SavedMealsResponse = (await get(u, '/nutrition/saved-meals')).json();
    expect(list.items.map((m) => m.id)).toEqual([meal.id]);

    // The food is corrected between saving and re-logging: the new log takes today's values.
    await sql`update food_nutrition set kcal_low = 100, kcal_high = 100 where food_id = ${foodId.get('chapati')!}`;
    const again = await logOk(u, { clientLogId: randomUUID(), mealSlot: 'dinner', entryMethod: 'saved-meal', savedMealId: meal.id });
    expect(again.log).toMatchObject({ entryMethod: 'saved-meal', savedMealId: meal.id });
    expect(again.log.items.map((i) => [i.foodName, i.kcalLow, i.kcalHigh])).toEqual([
      ['Dal tadka', 120, 185],
      ['Chapati', 200, 200],
      ['Curd', 60, 60],
    ]);
    // …and the original log is unchanged.
    const orig = (await day(u)).logs.find((l) => l.clientLogId === a.log.clientLogId)!;
    expect(orig.items[1]).toMatchObject({ kcalLow: 170, kcalHigh: 240 });
    await seedFoods(url);

    // Not yours / not there.
    const other = await user();
    expect((await post(other, { clientLogId: randomUUID(), mealSlot: 'dinner', entryMethod: 'saved-meal', savedMealId: meal.id })).statusCode).toBe(404);
    expect((await app.inject({ method: 'POST', url: '/v1/nutrition/saved-meals', headers: headers(other.token), payload: { ...create, clientMealId: randomUUID() } })).statusCode).toBe(404);

    // Deleting the meal keeps the logs made from it.
    const d = await app.inject({ method: 'DELETE', url: `/v1/nutrition/saved-meals/${meal.id}`, headers: headers(u.token) });
    expect(d.statusCode).toBe(204);
    expect((await app.inject({ method: 'DELETE', url: `/v1/nutrition/saved-meals/${meal.id}`, headers: headers(u.token) })).statusCode).toBe(404);
    const kept = (await day(u)).logs.find((l) => l.clientLogId === again.log.clientLogId)!;
    expect(kept).toMatchObject({ savedMealId: null });
    expect(kept.items).toHaveLength(3);
  });

  // ------------------------------------------------------ recent foods --

  it('recent foods: newest first, one per food with its last portion, deleted logs and quick adds excluded', async () => {
    const u = await user();
    await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 2 })], { loggedAt: new Date(Date.now() - 3 * 3600_000).toISOString() }));
    await logOk(u, logBody([food('honey', 'per_serving', '1 tbsp', { servings: 1 })], { loggedAt: new Date(Date.now() - 2 * 3600_000).toISOString() }));
    await logOk(u, logBody([food('chapati', 'per_serving', '1 piece', { servings: 4 })], { loggedAt: new Date(Date.now() - 3600_000).toISOString() }));
    const gone = await logOk(u, logBody([food('dal-tadka', 'per_serving', '1 katori', { servings: 1 })]));
    await del(u, gone.log.clientLogId);
    await logOk(u, { clientLogId: randomUUID(), mealSlot: 'snacks', entryMethod: 'quick-add', quickAdd: { kcal: 100, proteinG: 1, carbG: 1, fatG: 1 } });
    const r: RecentFoodsResponse = (await get(u, '/nutrition/foods/recent')).json();
    expect(r.items.map((i) => [i.food.slug, i.lastServingLabel, i.lastServings])).toEqual([
      ['chapati', '1 piece', 4],
      ['honey', '1 tbsp', 1],
    ]);
    expect(r.items[0]!.food.nutrition.length).toBeGreaterThan(0);
    const one: RecentFoodsResponse = (await get(u, '/nutrition/foods/recent?limit=1')).json();
    expect(one.items).toHaveLength(1);
    expect((await get(u, '/nutrition/foods/recent?limit=51')).statusCode).toBe(422);
  });

  // ------------------------------------------------------------ cache --

  it('the daily cache equals a recompute after creates, replays and deletes; the rebuild script agrees', async () => {
    const u = await user();
    const ids: string[] = [];
    for (let i = 0; i < 12; i += 1) {
      const d = addDays(today(), -(i % 3));
      const r = await logOk(u, logBody([food(i % 2 === 0 ? 'dal-tadka' : 'honey', 'per_serving', i % 2 === 0 ? '1 katori' : '1 tbsp', { servings: 1 + i / 4 })], { loggedAt: `${d}T12:0${i % 10}:00+05:30` }));
      ids.push(r.log.clientLogId);
    }
    for (const id of ids.slice(0, 4)) await del(u, id);
    await del(u, ids[0]!); // replayed delete
    const snapshot = async () =>
      sql`select local_date, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high,
                 fibre_known_low, fibre_known_high, fibre_unknown_items, item_count
          from daily_nutrition where user_id = ${u.id} order by local_date`;
    const cached = await snapshot();
    const handle = createDatabase(url);
    try {
      await rebuildDailyNutrition(handle.db, u.id);
    } finally {
      await handle.client.end({ timeout: 5 });
    }
    expect(await snapshot()).toEqual(cached);
    // The whole-database script gives the same rows again.
    await rebuildNutrition(url);
    expect(await snapshot()).toEqual(cached);
    expect(cached).toHaveLength(3);
  });

  // ------------------------------------------------------ performance --

  it('p95 < 200 ms for POST /nutrition/logs and GET /nutrition/today with 30 days × 10 logs', async () => {
    const u = await user();
    await setTargets(u, addDays(today(), -40), 2400, 140);
    const slugs = [
      ['dal-tadka', 'per_serving', '1 katori'],
      ['chapati', 'per_serving', '1 piece'],
      ['honey', 'per_serving', '1 tbsp'],
      ['white-rice-cooked', 'per_serving', '1 katori'],
      ['milk-whole', 'per_100g', '100 g'],
    ] as const;
    const postTimes: number[] = [];
    for (let d = 29; d >= 0; d -= 1) {
      const date = addDays(today(), -d);
      for (let i = 0; i < 10; i += 1) {
        const [slug, basis, label] = slugs[i % slugs.length]!;
        const body = logBody([food(slug, basis, label, { servings: 1 })], { loggedAt: `${date}T0${Math.min(9, i)}:${String(i * 5).padStart(2, '0')}:00+05:30`, mealSlot: MEAL_SLOTS[i % 4] });
        const t = performance.now();
        const r = await post(u, body);
        postTimes.push(performance.now() - t);
        expect(r.statusCode).toBe(201);
      }
    }
    const [count] = await sql<{ n: number }[]>`select count(*)::int as n from food_logs where user_id = ${u.id}`;
    expect(count!.n).toBe(300);
    const getTimes: number[] = [];
    for (let i = 0; i < 5; i += 1) await get(u, '/nutrition/today'); // warm-up
    for (let i = 0; i < 60; i += 1) {
      const t = performance.now();
      const r = await get(u, i % 2 === 0 ? '/nutrition/today' : `/nutrition/day/${addDays(today(), -(i % 30))}`);
      getTimes.push(performance.now() - t);
      expect(r.statusCode).toBe(200);
    }
    const p95 = (xs: number[]) => [...xs].sort((a, b) => a - b)[Math.ceil(xs.length * 0.95) - 1] as number;
    const p50 = (xs: number[]) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)] as number;
    console.info(`POST /nutrition/logs over ${postTimes.length}: p50 ${p50(postTimes).toFixed(1)} ms, p95 ${p95(postTimes).toFixed(1)} ms`);
    console.info(`GET today/day over ${getTimes.length}: p50 ${p50(getTimes).toFixed(1)} ms, p95 ${p95(getTimes).toFixed(1)} ms`);
    expect(p95(postTimes)).toBeLessThan(200);
    expect(p95(getTimes)).toBeLessThan(200);
    const today0 = await day(u);
    expect(today0.logs).toHaveLength(10);
    expect(today0.totals.itemCount).toBe(10);
  }, 120_000);

  it('the food search still ranks as Phase 7 did (recent-first is a separate list, owner J13)', async () => {
    const u = await user();
    await logOk(u, logBody([food('honey', 'per_serving', '1 tbsp', { servings: 1 })]));
    const r: FoodSearchResponse = (await get(u, '/nutrition/foods/search?q=rice')).json();
    expect(r.items[0]).toMatchObject({ slug: 'white-rice-cooked', match: 'alias' });
  });
});
