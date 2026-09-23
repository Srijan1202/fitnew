/**
 * The food library through the HTTP surface, on real Postgres with the real
 * seed (Phase 7). Search ranking (exact name > exact alias > prefix > fuzzy),
 * who sees which food, retry-safe custom foods, validation, honest nutrition
 * (ranges for estimates, unknown fibre stays unknown), the seed runner's
 * idempotence and the search latency budget (p95 < 200 ms).
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import type { Food, FoodSearchResponse, FoodSearchResult } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import { readFoodSeed, seedFoods } from '../../db/food-seed/load.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/nutrition/foods (real Postgres, real seed)', () => {
  const url = databaseUrl as string;
  const seed = readFoodSeed();
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let ip = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedFoods(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'food-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  // A fresh client address per request keeps the per-IP limiter (120/min) out of the latency run.
  const auth = (token: string) => {
    ip += 1;
    return { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.51.${Math.floor(ip / 250) % 250}.${ip % 250}` };
  };

  async function user(): Promise<string> {
    n += 1;
    const token = `food-tok-${n}`;
    verifier.accept(token, { uid: `food-uid-${n}`, email: `food${n}@vit.ac.in` });
    const r = await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} });
    expect(r.statusCode, r.body).toBe(200);
    return token;
  }

  const searchRaw = (token: string, q: string, limit?: number) =>
    app.inject({
      method: 'GET',
      url: `/v1/nutrition/foods/search?q=${encodeURIComponent(q)}${limit === undefined ? '' : `&limit=${limit}`}`,
      headers: auth(token),
    });

  async function search(token: string, q: string, limit?: number): Promise<FoodSearchResult[]> {
    const r = await searchRaw(token, q, limit);
    expect(r.statusCode, r.body).toBe(200);
    return (r.json() as FoodSearchResponse).items;
  }

  const create = (token: string, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/nutrition/foods', headers: auth(token), payload: body });

  const label = (overrides: Record<string, unknown> = {}) => ({
    clientFoodId: randomUUID(),
    name: 'Amul Protein Lassi',
    brand: 'Amul',
    basis: 'per_serving',
    servingLabel: '1 bottle (200 ml)',
    servingGrams: 200,
    kcal: 160,
    proteinG: 15,
    carbG: 20,
    fatG: 2,
    ...overrides,
  });

  // ------------------------------------------------------------ the seed --

  it('the seed is applied: every seed food is a global row with its nutrition and aliases', async () => {
    const [counts] = await sql<{ foods: number; rows: number; aliases: number }[]>`
      select (select count(*)::int from foods where owner_user_id is null) as foods,
             (select count(*)::int from food_nutrition fn join foods f on f.id = fn.food_id where f.owner_user_id is null) as rows,
             (select count(*)::int from food_aliases fa join foods f on f.id = fa.food_id where f.owner_user_id is null) as aliases`;
    expect(counts).toEqual({
      foods: seed.length,
      rows: seed.reduce((s, f) => s + f.nutrition.length, 0),
      aliases: seed.reduce((s, f) => s + f.aliases.length, 0),
    });
  });

  it('seeding twice changes nothing: same ids, same counts, no duplicates', async () => {
    const before = await sql<{ id: string; slug: string }[]>`select id, slug from foods where owner_user_id is null order by slug`;
    const first = await seedFoods(url);
    const second = await seedFoods(url);
    expect(second).toEqual(first);
    expect(first.foods).toBe(seed.length);
    const after = await sql<{ id: string; slug: string }[]>`select id, slug from foods where owner_user_id is null order by slug`;
    expect(after).toEqual(before);
  });

  it('401 without a session', async () => {
    const r = await app.inject({ method: 'GET', url: '/v1/nutrition/foods/search?q=rice' });
    expect(r.statusCode).toBe(401);
    const p = await app.inject({ method: 'POST', url: '/v1/nutrition/foods', payload: label() });
    expect(p.statusCode).toBe(401);
  });

  // ------------------------------------------------------------- ranking --

  it('an exact name ranks first, whatever the case or punctuation', async () => {
    const token = await user();
    for (const q of ['Honey', '  HONEY!! ', 'honey']) {
      const items = await search(token, q);
      expect(items[0]).toMatchObject({ slug: 'honey', match: 'exact' });
    }
    expect((await search(token, 'dal tadka'))[0]).toMatchObject({ slug: 'dal-tadka', match: 'exact' });
    expect((await search(token, 'Dal (Tadka)'))[0]).toMatchObject({ slug: 'dal-tadka', match: 'exact' });
  });

  it('the approved spelling variants resolve through aliases', async () => {
    const token = await user();
    const expected: Record<string, string> = {
      dhal: 'dal-tadka',
      daal: 'dal-tadka',
      'panneer 65': 'paneer-65',
      chapathi: 'chapati',
      roti: 'chapati',
      idly: 'idli',
      dosai: 'plain-dosa',
      sambhar: 'sambar',
      biriyani: 'veg-biryani',
      dahi: 'curd',
      raitha: 'raita',
      poori: 'puri',
    };
    for (const [q, slug] of Object.entries(expected)) {
      expect((await search(token, q))[0], q).toMatchObject({ slug, match: 'alias' });
    }
  });

  it('exact alias outranks prefix: "rice" is cooked white rice before every "Rice, …" record', async () => {
    const token = await user();
    const items = await search(token, 'rice', 50);
    expect(items[0]).toMatchObject({ slug: 'white-rice-cooked', match: 'alias' });
    const tiers = items.map((i) => ['exact', 'alias', 'prefix', 'fuzzy'].indexOf(i.match));
    expect(tiers).toEqual([...tiers].sort((a, b) => a - b));
    expect(items.slice(1).some((i) => i.slug === 'rice-white-long-grain-cooked' && i.match === 'prefix')).toBe(true);
  });

  it('prefixes match names, words inside names and aliases', async () => {
    const token = await user();
    const paneer = await search(token, 'panee');
    expect(paneer.length).toBeGreaterThan(0);
    for (const i of paneer.slice(0, 3)) expect(i.match).toBe('prefix');
    expect(paneer.map((i) => i.slug)).toEqual(expect.arrayContaining(['paneer-65', 'paneer-butter-masala']));
    // A word inside the name: "tadka" finds dal tadka.
    expect((await search(token, 'tadka')).map((i) => i.slug)).toContain('dal-tadka');
  });

  it('a misspelling still finds the food, labelled fuzzy, after every better match', async () => {
    const token = await user();
    const items = await search(token, 'chapatii');
    expect(items.length).toBeGreaterThan(0);
    expect(items[0]).toMatchObject({ slug: 'chapati', match: 'fuzzy' });
    expect((await search(token, 'sambaar'))[0]).toMatchObject({ slug: 'sambar', match: 'fuzzy' });
  });

  it('nonsense finds nothing; a query of only punctuation is an empty result, not an error', async () => {
    const token = await user();
    expect(await search(token, 'xqzvjw')).toEqual([]);
    expect(await search(token, '!!!')).toEqual([]);
  });

  it('limit is honoured and bounded; q is required', async () => {
    const token = await user();
    expect(await search(token, 'rice', 3)).toHaveLength(3);
    expect((await searchRaw(token, 'rice', 51)).statusCode).toBe(422);
    expect((await searchRaw(token, 'rice', 0)).statusCode).toBe(422);
    expect((await app.inject({ method: 'GET', url: '/v1/nutrition/foods/search', headers: auth(token) })).statusCode).toBe(422);
    expect((await searchRaw(token, '   ')).statusCode).toBe(422);
    expect((await searchRaw(token, 'a'.repeat(81))).statusCode).toBe(422);
  });

  // -------------------------------------------------- honest nutrition --

  it('USDA foods are verified, exact, high confidence and carry their FDC provenance', async () => {
    const token = await user();
    const honey = (await search(token, 'honey'))[0] as Food;
    expect(honey).toMatchObject({ source: 'usda', isVerified: true, isCustom: false });
    expect(honey.sourceRef).toMatch(/^USDA FoodData Central · .+ · FDC \d+$/);
    const per100 = honey.nutrition[0]!;
    expect(per100).toMatchObject({ basis: 'per_100g', servingLabel: '100 g', servingGrams: 100, confidence: 'high' });
    expect(per100.kcalLow).toBe(per100.kcalHigh);
  });

  it('estimates are unverified ranges with their provenance, never high confidence', async () => {
    const token = await user();
    for (const q of ['dal tadka', 'masala dosa', 'chicken biryani']) {
      const f = (await search(token, q))[0] as Food;
      expect(f.source, q).toBe('estimated');
      expect(f.isVerified).toBe(false);
      expect(f.sourceRef).toMatch(/^FITOS estimate · /);
      for (const row of f.nutrition) {
        expect(row.confidence).not.toBe('high');
        expect(row.kcalLow).toBeLessThan(row.kcalHigh);
      }
    }
  });

  it('fibre USDA does not report is null, never zero', async () => {
    const token = await user();
    const milk = (await search(token, 'Milk, whole, 3.25% milkfat, with added vitamin D'))[0] as Food;
    expect(milk.slug).toBe('milk-whole');
    for (const row of milk.nutrition) {
      expect(row.fibreLow).toBeNull();
      expect(row.fibreHigh).toBeNull();
    }
  });

  // ---------------------------------------------------- custom foods --

  it('creates a custom food: 201, the user\'s own, unverified, exact label values', async () => {
    const token = await user();
    const body = label();
    const r = await create(token, body);
    expect(r.statusCode, r.body).toBe(201);
    const food: Food = r.json();
    expect(food).toMatchObject({ name: 'Amul Protein Lassi', brand: 'Amul', source: 'user', isVerified: false, isCustom: true, aliases: [] });
    expect(food.slug).toMatch(/^custom-/);
    expect(food.nutrition).toEqual([
      {
        basis: 'per_serving',
        servingLabel: '1 bottle (200 ml)',
        servingGrams: 200,
        kcalLow: 160,
        kcalHigh: 160,
        proteinLow: 15,
        proteinHigh: 15,
        carbLow: 20,
        carbHigh: 20,
        fatLow: 2,
        fatHigh: 2,
        fibreLow: null,
        fibreHigh: null,
        confidence: 'medium',
      },
    ]);
  });

  it('a retry with the same clientFoodId returns the same food (200) and stores one row', async () => {
    const token = await user();
    const body = label({ name: 'Retry Bar' });
    const first = await create(token, body);
    const second = await create(token, body);
    const third = await create(token, { ...body, kcal: 999 }); // a changed resend is still the same food
    expect(first.statusCode).toBe(201);
    expect(second.statusCode).toBe(200);
    expect(third.statusCode).toBe(200);
    expect((second.json() as Food).id).toBe((first.json() as Food).id);
    expect((third.json() as Food).nutrition[0]!.kcalLow).toBe(160);
    const [row] = await sql<{ count: number }[]>`select count(*)::int as count from foods where client_food_id = ${body.clientFoodId}`;
    expect(row?.count).toBe(1);
  });

  it('concurrent duplicates resolve to one food', async () => {
    const token = await user();
    const body = label({ name: 'Race Bar' });
    const results = await Promise.all([create(token, body), create(token, body), create(token, body)]);
    const ids = new Set(results.map((r) => (r.json() as Food).id));
    expect(ids.size).toBe(1);
    expect(results.filter((r) => r.statusCode === 201)).toHaveLength(1);
  });

  it('a custom food is private: its owner finds it, nobody else does', async () => {
    const owner = await user();
    const other = await user();
    const body = label({ name: 'Hostel Mess Poha Special' });
    const food: Food = (await create(owner, body)).json();
    const mine = await search(owner, 'hostel mess poha special');
    expect(mine[0]).toMatchObject({ id: food.id, match: 'exact', isCustom: true });
    expect((await search(other, 'hostel mess poha special')).map((i) => i.id)).not.toContain(food.id);
    expect((await search(other, 'hostel mess')).map((i) => i.id)).not.toContain(food.id);
    // The same clientFoodId from another user is that user's own, separate food.
    const theirs = await create(other, body);
    expect(theirs.statusCode).toBe(201);
    expect((theirs.json() as Food).id).not.toBe(food.id);
  });

  it('two users may use the same clientFoodId without colliding', async () => {
    const a = await user();
    const b = await user();
    const clientFoodId = randomUUID();
    const ra = await create(a, label({ clientFoodId, name: 'Shared Id A' }));
    const rb = await create(b, label({ clientFoodId, name: 'Shared Id B' }));
    expect([ra.statusCode, rb.statusCode]).toEqual([201, 201]);
    expect((ra.json() as Food).id).not.toBe((rb.json() as Food).id);
  });

  it('on an equal match, source precedence decides: USDA "Honey" before a custom "Honey"', async () => {
    const token = await user();
    const mine: Food = (await create(token, label({ name: 'Honey', brand: null, servingLabel: '1 tbsp', servingGrams: 21, kcal: 64, proteinG: 0, carbG: 17, fatG: 0 }))).json();
    const items = await search(token, 'honey');
    expect(items.slice(0, 2).map((i) => [i.slug, i.match])).toEqual([
      ['honey', 'exact'],
      [mine.slug, 'exact'],
    ]);
  });

  it('per 100 g labels are stored on a 100 g basis; stated fibre is kept, including zero', async () => {
    const token = await user();
    const r = await create(token, label({ name: 'Oats Label', basis: 'per_100g', servingLabel: undefined, servingGrams: undefined, kcal: 389, proteinG: 13.2, carbG: 67.7, fatG: 7.6, fibreG: 10.1 }));
    expect(r.statusCode, r.body).toBe(201);
    expect((r.json() as Food).nutrition[0]).toMatchObject({ basis: 'per_100g', servingLabel: '100 g', servingGrams: 100, fibreLow: 10.1, fibreHigh: 10.1 });
    const zero = await create(token, label({ name: 'Zero Fibre Drink', fibreG: 0 }));
    expect((zero.json() as Food).nutrition[0]).toMatchObject({ fibreLow: 0, fibreHigh: 0 });
  });

  it('impossible labels and unknown fields are rejected with 422', async () => {
    const token = await user();
    const bad: Record<string, unknown>[] = [
      label({ basis: 'per_100g', servingLabel: undefined, servingGrams: undefined, kcal: 950 }),
      label({ basis: 'per_100g', servingLabel: undefined, servingGrams: undefined, proteinG: 60, carbG: 60 }),
      label({ servingGrams: 20 }),
      label({ servingLabel: undefined }),
      label({ kcal: -1 }),
      label({ clientFoodId: 'not-a-uuid' }),
      label({ name: '   ' }),
      label({ source: 'usda' }),
      label({ isVerified: true }),
    ];
    for (const body of bad) {
      const r = await create(token, body);
      expect(r.statusCode, JSON.stringify(body)).toBe(422);
    }
    const [row] = await sql<{ count: number }[]>`
      select count(*)::int as count from foods f join users u on u.id = f.owner_user_id where u.firebase_uid = ${`food-uid-${n}`}`;
    expect(row?.count).toBe(0);
  });

  it('re-seeding never touches custom foods', async () => {
    const token = await user();
    const food: Food = (await create(token, label({ name: 'Survives Reseed' }))).json();
    await seedFoods(url);
    expect((await search(token, 'survives reseed'))[0]).toMatchObject({ id: food.id, isCustom: true });
  });

  // ---------------------------------------------------------- latency --

  it('search p95 stays under 200 ms across exact, alias, prefix, fuzzy and empty queries', async () => {
    const token = await user();
    const queries = ['honey', 'dal', 'roti', 'panee', 'chapatii', 'rice', 'chicken', 'milk', 'masala dosa', 'xqzvjw', 'egg', 'biriyani'];
    for (const q of queries) await search(token, q); // warm-up
    const samples: number[] = [];
    for (let round = 0; round < 5; round += 1) {
      for (const q of queries) {
        const start = performance.now();
        const r = await searchRaw(token, q);
        samples.push(performance.now() - start);
        expect(r.statusCode).toBe(200);
      }
    }
    samples.sort((a, b) => a - b);
    const p95 = samples[Math.ceil(samples.length * 0.95) - 1] as number;
    console.info(`food search latency over ${samples.length} requests: p50 ${samples[Math.floor(samples.length / 2)]!.toFixed(1)} ms, p95 ${p95.toFixed(1)} ms`);
    expect(p95).toBeLessThan(200);
  });
});
