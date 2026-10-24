/**
 * Beta 3.6 (owner, F15) on real Postgres with the real food seed, a
 * mirrored mess menu and a scripted model: POST /nutrition/guide, "What
 * should I eat?" from what the person has and the mess menu. The model
 * picks; FITOS checks and supplies every number.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { foodGuideResponseSchema, type FoodGuideResponse } from '@fitos/contracts';
import { VIT_ENDPOINTS } from '@fitos/core/mess/providers/vit/config';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';

import { buildApp } from '../../app.js';
import { createDatabase, type DatabaseHandle } from '../../db/client.js';
import { seedFoods } from '../../db/food-seed/load.js';
import { migrateUp } from '../../db/migrate.js';
import { seedMesses } from '../../db/seed-mess.js';
import { databaseUrl, testEnv } from '../../test/build-test-app.js';
import { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { runMirror, type FetchOutcome, type MirrorFetcher } from '../mess/mirror.js';
import { FakeAiProvider } from './fake-provider.js';
import { FoodRepository } from '../nutrition/repository.js';
import { FoodService } from '../nutrition/service.js';
import { GUIDE_STAPLES, foodWords } from './guide.js';
import type { AiResponse } from './provider.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

const IST = 'Asia/Kolkata';
const today = (): string => localDateOf(new Date(), IST);
const FIXTURES = new URL('../../../../../packages/core/test/fixtures/messit-2026-09-24/', import.meta.url);
const CAPTURE_DAY = '2026-09-24';
const daysBetween = (a: string, b: string): number => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
/** The capture with every date moved so that 2026-09-24 is today. */
function shifted(name: string): string {
  const payload = JSON.parse(readFileSync(fileURLToPath(new URL(`${name}.json`, FIXTURES)), 'utf8')) as { menu: { date: string }[] };
  const by = daysBetween(CAPTURE_DAY, today());
  return JSON.stringify({ ...payload, menu: payload.menu.map((d) => ({ ...d, date: addDays(d.date, by) })) });
}
const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);
const scripted = (bodies: Record<string, string>): MirrorFetcher => async (url): Promise<FetchOutcome> => {
  const body = bodies[/(hostel-\d-mess-\d)\.json$/.exec(url)?.[1] ?? url];
  return body === undefined ? { ok: false } : { ok: true, body };
};

const said = (json: unknown): AiResponse => ({ text: typeof json === 'string' ? json : JSON.stringify(json), toolCalls: [], finishReason: 'stop', usage: { inputTokens: 300, outputTokens: 60 } });

describe('foodWords', () => {
  it('drops the amount, keeps the food', () => {
    expect(foodWords('2 eggs')).toBe('eggs');
    expect(foodWords('1 cup curd')).toBe('curd');
    expect(foodWords('100 g paneer')).toBe('paneer');
    expect(foodWords('Banana')).toBe('Banana');
  });
});

describeIfDb('POST /v1/nutrition/guide (real Postgres, real food seed, a mirrored menu, scripted model)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let handle: DatabaseHandle;
  let app: Awaited<ReturnType<typeof buildApp>>;
  let verifier: FakeTokenVerifier;
  let ai: FakeAiProvider;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedFoods(url);
    sql = postgres(url, { max: 1 });
    handle = createDatabase(url);
    await seedMesses(handle.db);
    await sql`delete from mess_menu_snapshots`;
    await sql`delete from mess_dish_nutrition`;
    await runMirror(handle, { fetcher: scripted(Object.fromEntries(NAMES.map((name) => [name, shifted(name)]))) });
    verifier = new FakeTokenVerifier();
    ai = new FakeAiProvider();
    app = await buildApp(testEnv({ DATABASE_URL: url }), { database: createDatabase(url), tokenVerifier: verifier, aiProvider: ai });
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'guide-%'`;
    await sql`delete from feature_flags where key = 'food-guide'`;
    await sql`delete from mess_menu_snapshots`;
    await sql`delete from mess_dish_nutrition`;
    await app.close();
    await handle.client.end({ timeout: 5 });
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.160.${(n % 200) + 1}` });

  async function user(o: { premium?: boolean; consent?: boolean; diet?: string; allergies?: string[]; mess?: boolean; admin?: boolean } = {}): Promise<U> {
    n += 1;
    const token = `guide-tok-${n}`;
    verifier.accept(token, { uid: `guide-uid-${n}`, email: `guide-${n}@vit.ac.in`, claims: o.admin === true ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`guide-uid-${n}`}`;
    if (o.premium !== false) await sql`update users set premium_since = now() where id = ${row!.id}`;
    if (o.consent !== false) {
      expect((await app.inject({ method: 'POST', url: '/v1/user/consents', headers: auth(token), payload: { type: 'ai-processing', granted: true } })).statusCode).toBe(200);
    }
    if (o.mess === true) {
      const p = await app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: auth(token), payload: { isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' } } });
      expect(p.statusCode, p.body).toBe(200);
    }
    const d = await app.inject({
      method: 'PUT',
      url: '/v1/user/diet-preferences',
      headers: auth(token),
      payload: { dietType: o.diet ?? 'vegetarian', allergies: (o.allergies ?? []).map((allergen) => ({ allergen, severity: 'severe' })) },
    });
    expect(d.statusCode, d.body).toBe(200);
    await sql`
      insert into nutrition_targets (user_id, effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale, reason)
      values (${row!.id}, '2026-01-01', 2400, 120, 290, 70, 30, 1700, 2500, ${sql.json(['test'])}, 'onboarding')`;
    return { token, id: row!.id };
  }

  const guide = (u: U, body: Record<string, unknown>) => app.inject({ method: 'POST', url: '/v1/nutrition/guide', headers: auth(u.token), payload: body });
  const usage = (u: U) => sql<{ route: string; outcome: string }[]>`select route::text as route, outcome::text as outcome from ai_usage where user_id = ${u.id} order by created_at, id`;

  it('every pinned staple is still a food in the seed, found by its exact name', async () => {
    const u = await user();
    const foods = new FoodService(new FoodRepository(handle.db));
    for (const [said, name] of Object.entries(GUIDE_STAPLES)) {
      const hits = (await foods.search(u.id, { q: name, limit: 3 })).items;
      expect(hits.some((h) => h.match === 'exact' && h.name === name), `${said} → ${name}`).toBe(true);
    }
  });

  it('a staple is the plain food (banana is a banana, not a shake); a loose prefix match is not taken', async () => {
    const u = await user({ diet: 'non-vegetarian' });
    ai.script = [said({ options: [{ title: 'Snack', items: [{ id: 'H1', servings: 1 }, { id: 'H2', servings: 1 }] }] })];
    const g = foodGuideResponseSchema.parse((await guide(u, { slot: 'snacks', fromMess: false, have: ['Banana', 'Apple', 'milk'], feel: null })).json());
    expect(g.options[0]!.items.map((i) => i.name)).toEqual(['Bananas, raw', "Apples, raw, with skin (Includes foods for USDA's Food Distribution Program)"]);
    expect(g.unknown).toEqual(['milk']);
  });

  it('401 signed out; premium only; the AI consent; something to choose from (422)', async () => {
    const before = ai.requests.length;
    expect((await app.inject({ method: 'POST', url: '/v1/nutrition/guide', payload: { slot: 'lunch', fromMess: false, have: ['curd'], feel: null } })).statusCode).toBe(401);
    const free = await user({ premium: false });
    expect((await guide(free, { slot: 'lunch', fromMess: false, have: ['curd'], feel: null })).statusCode).toBe(403);
    const noConsent = await user({ consent: false });
    expect((await guide(noConsent, { slot: 'lunch', fromMess: false, have: ['curd'], feel: null })).statusCode).toBe(403);
    const u = await user();
    expect((await guide(u, { slot: 'lunch', fromMess: false, have: [], feel: null })).statusCode).toBe(422);
    expect((await guide(u, { slot: 'brunch', fromMess: false, have: ['curd'], feel: null })).statusCode).toBe(422);
    expect(ai.requests).toHaveLength(before);
  });

  it('what they have: known foods only, diet and allergens respected, the numbers the database\'s; the model never sees who they are', async () => {
    const u = await user({ diet: 'vegetarian', allergies: ['peanut'] });
    ai.script = [said({ options: [{ title: 'Curd bowl', why: 'Light and filling.', items: [{ id: 'H1', servings: 1.5 }, { id: 'H9', servings: 1 }] }] })];
    const r = await guide(u, { slot: 'snacks', fromMess: false, have: ['1 cup curd', 'chicken 65', 'peanut butter toast', 'zzqx berries', 'curd'], feel: 'something cool' });
    expect(r.statusCode, r.body).toBe(200);
    const g = foodGuideResponseSchema.parse(r.json()) as FoodGuideResponse;
    expect(g.refused.sort()).toEqual(['chicken 65', 'peanut butter toast']);
    expect(g.unknown).toEqual(['zzqx berries']);
    expect(g.mess).toBeNull();
    expect(g.remaining).toEqual({ kcal: 2400, proteinG: 120 });
    expect(g.options).toHaveLength(1);
    const [item] = g.options[0]!.items;
    expect(g.options[0]!.items).toHaveLength(1);
    expect(item).toMatchObject({ source: 'have', name: 'Curd', servings: 1.5, dishSlug: null });
    expect(item!.food).not.toBeNull();
    expect(item!.food!.servings).toBe(1.5);
    expect(item!.food!.snapshot).toEqual(item!.macros);
    expect(item!.macros.kcalLow).toBeGreaterThanOrEqual(Math.floor(item!.food!.row.kcalLow * 1.5) - 1);
    expect(item!.macros.kcalHigh).toBeLessThanOrEqual(Math.ceil(item!.food!.row.kcalHigh * 1.5) + 1);
    expect(g.options[0]!.totals).toEqual(item!.macros);

    const prompt = ai.requests.at(-1)!;
    const text = prompt.messages.map((m) => m.content).join('\n');
    expect(text).toContain('H1: Curd (they have it)');
    expect(text).toContain('They feel like: something cool');
    expect(text).toContain('Left for today: about 2400 kcal and 120 g protein.');
    expect(text).not.toContain('Chicken');
    expect(text).not.toContain('Peanut');
    expect(text).not.toContain('zzqx');
    expect(text).not.toContain('@vit.ac.in');
    expect(await usage(u)).toEqual([{ route: 'guide', outcome: 'ok' }]);
  });

  it('the mess menu: only dishes that pass the diet rules, with the stored numbers; a plate logs as mess dishes', async () => {
    const u = await user({ diet: 'vegetarian', mess: true });
    ai.script = [said({ options: [{ title: 'Mess thali', why: 'Protein from dal.', items: [{ id: 'M1', servings: 2 }] }, { title: 'Light', items: [{ id: 'M2', servings: 1 }] }] })];
    const r = await guide(u, { slot: 'lunch', fromMess: true, have: [], feel: null });
    expect(r.statusCode, r.body).toBe(200);
    const g = foodGuideResponseSchema.parse(r.json());
    expect(g.mess).toEqual({ code: expect.any(String), menuDate: today() });
    expect(g.messNote).toBeNull();
    const text = ai.requests.at(-1)!.messages.map((m) => m.content).join('\n');
    expect(text).toContain('M1: ');
    expect(text).toContain('(from the mess)');
    const m1 = /M1: (.+?) \(from the mess\)/.exec(text)![1];
    const first = g.options[0]!.items[0]!;
    expect(first).toMatchObject({ source: 'mess', name: m1, servings: 2, food: null });
    expect(first.dishSlug).not.toBeNull();
    const [stored] = await sql<{ kcal_low: string; kcal_high: string }[]>`select kcal_low::text, kcal_high::text from mess_dish_nutrition where dish_slug = ${first.dishSlug!}`;
    expect(first.macros.kcalLow).toBe(Math.floor(Number(stored!.kcal_low) * 2));
    expect(first.macros.kcalHigh).toBe(Math.ceil(Number(stored!.kcal_high) * 2));
    expect(g.options[1]!.title).toBe('Light');
    expect(g.options[1]!.why).toBe('');
  });

  it('no mess chosen: said so; nothing to choose from: no model call; a malformed answer is 503 and counted failed', async () => {
    const u = await user();
    const calls = ai.requests.length;
    const none = foodGuideResponseSchema.parse((await guide(u, { slot: 'dinner', fromMess: true, have: ['zzqx berries'], feel: null })).json());
    expect(none.messNote).toBe('Choose your mess in Profile to use its menu.');
    expect(none.options).toEqual([]);
    expect(none.unknown).toEqual(['zzqx berries']);
    expect(ai.requests.length).toBe(calls);

    ai.script = [said('not json at all')];
    expect((await guide(u, { slot: 'dinner', fromMess: false, have: ['curd'], feel: null })).statusCode).toBe(503);
    ai.script = [said({ plates: [] })];
    expect((await guide(u, { slot: 'dinner', fromMess: false, have: ['curd'], feel: null })).statusCode).toBe(503);
    ai.script = [said('```json\n{"options":[]}\n```')];
    const empty = foodGuideResponseSchema.parse((await guide(u, { slot: 'dinner', fromMess: false, have: ['curd'], feel: null })).json());
    expect(empty.options).toEqual([]);
    expect((await usage(u)).map((x) => x.outcome)).toEqual(['failed', 'failed', 'discarded']);
  });

  it('behind the food-guide switch (403 feature-off when the admin turns it off)', async () => {
    const admin = await user({ admin: true });
    const u = await user();
    const off = await app.inject({ method: 'PUT', url: '/v1/admin/flags/food-guide', headers: auth(admin.token), payload: { enabled: false } });
    expect(off.statusCode, off.body).toBe(200);
    try {
      const r = await guide(u, { slot: 'lunch', fromMess: false, have: ['curd'], feel: null });
      expect(r.statusCode).toBe(403);
      expect(r.body).toContain('feature-off');
    } finally {
      await app.inject({ method: 'PUT', url: '/v1/admin/flags/food-guide', headers: auth(admin.token), payload: { enabled: true } });
    }
  });
});
