/**
 * Beta 5.5 (owner) on real Postgres with the real food seed, a mirrored mess
 * menu and a scripted model: POST /nutrition/parse-photo, a meal from a
 * photo. The photo goes to the model with the mess menu's dish names; a dish
 * picked from the menu comes back at the mess table's numbers; nothing is
 * stored, not even the photo; photos have their own hourly and daily limits.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { PHOTO_MAX_BYTES, messMenuSchema, parseFoodPhotoResponseSchema, type MessMenu } from '@fitos/contracts';
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
import { PHOTO_SYSTEM, messServings, photoMenuText } from './parse.js';
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

/** A JPEG's first bytes are all the server checks; the model is scripted. */
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(60, 7)]).toString('base64');
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(60, 7)]).toString('base64');

const said = (items: Record<string, unknown>[]): AiResponse => ({
  text: JSON.stringify({ items }),
  toolCalls: [],
  finishReason: 'stop',
  usage: { inputTokens: 1300, outputTokens: 90 },
});
const item = (over: Record<string, unknown>): Record<string, unknown> => ({
  phrase: 'x', name: 'x', quantity: 1, unit: 'serving', grams: null, kcal: 100, proteinG: 5, carbG: 10, fatG: 3, confidence: 'high', menuDish: null, ...over,
});

describe('photo helpers', () => {
  it('servings of a menu dish: in quarters, 0.25–10; grams over the serving weight when the model gave grams', () => {
    expect(messServings({ quantity: 1.4, unit: 'serving' }, null)).toBe(1.5);
    expect(messServings({ quantity: 0.05, unit: 'serving' }, null)).toBe(0.25);
    expect(messServings({ quantity: 40, unit: 'serving' }, null)).toBe(10);
    expect(messServings({ quantity: 300, unit: 'g' }, 150)).toBe(2);
    expect(messServings({ quantity: 300, unit: 'g' }, null)).toBe(10);
  });

  it('the menu as the model sees it: numbered names and servings; no menu, just the meal', () => {
    expect(photoMenuText('lunch', null)).toBe('A photo of a lunch.');
    const menu = { code: 'x', menuDate: '2026-11-04', dishes: [{ slug: 'dal', name: 'Dal', servingLabel: '1 katori', servingGrams: 150, macros: { kcalLow: 1, kcalHigh: 1, proteinLow: 1, proteinHigh: 1, carbLow: 1, carbHigh: 1, fatLow: 1, fatHigh: 1 } }] };
    expect(photoMenuText('lunch', menu)).toBe("A photo of a lunch. This lunch menu is at the person's mess that day:\n1. Dal (a serving is 1 katori)");
  });
});

describeIfDb('POST /v1/nutrition/parse-photo (real Postgres, real food seed, a mirrored menu, scripted model)', { timeout: 60_000 }, () => {
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
    // Seeding and mirroring take a while when the whole suite shares the database.
  }, 60_000);

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'photo-%'`;
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
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.170.${(n % 200) + 1}` });

  async function user(o: { premium?: boolean; mess?: boolean } = {}): Promise<U> {
    n += 1;
    const token = `photo-tok-${n}`;
    verifier.accept(token, { uid: `photo-uid-${n}`, email: `photo-${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`photo-uid-${n}`}`;
    await sql`update users set timezone = ${IST} where id = ${row!.id}`;
    if (o.premium !== false) await sql`update users set premium_since = now() where id = ${row!.id}`;
    expect((await app.inject({ method: 'POST', url: '/v1/user/consents', headers: auth(token), payload: { type: 'ai-processing', granted: true } })).statusCode).toBe(200);
    if (o.mess === true) {
      const p = await app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: auth(token), payload: { isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' } } });
      expect(p.statusCode, p.body).toBe(200);
    }
    return { token, id: row!.id };
  }

  const photo = (u: U, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/nutrition/parse-photo', headers: auth(u.token), payload: { image: JPEG, mimeType: 'image/jpeg', slot: 'lunch', ...body } });
  const usage = (u: U) =>
    sql<{ route: string; outcome: string; input_tokens: number }[]>`select route::text as route, outcome::text as outcome, input_tokens from ai_usage where user_id = ${u.id} order by created_at, id`;
  const foodLogs = async (u: U) => Number((await sql<{ n: string }[]>`select count(*)::text as n from food_logs where user_id = ${u.id}`)[0]!.n);
  const issue = (r: { json: () => unknown }): string | undefined =>
    (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;
  async function lunchMenu(u: U): Promise<MessMenu> {
    const r = await app.inject({ method: 'GET', url: `/v1/mess/menu?date=${today()}`, headers: auth(u.token) });
    expect(r.statusCode, r.body).toBe(200);
    return messMenuSchema.parse(r.json());
  }

  it('default-deny; the photo must be the type it claims and at most 1.5 MB; premium; nothing reaches the model before that', async () => {
    const anon = { 'x-forwarded-for': '203.0.171.1' };
    expect((await app.inject({ method: 'POST', url: '/v1/nutrition/parse-photo', headers: anon, payload: { image: JPEG, mimeType: 'image/jpeg', slot: 'lunch' } })).statusCode).toBe(401);
    const u = await user();
    const before = ai.requests.length;
    // A PNG sent as a JPEG; text that is not base64; a photo over 1.5 MB; an unknown type; an extra field.
    const wrong = await photo(u, { image: PNG });
    expect(wrong.statusCode).toBe(422);
    expect(issue(wrong)).toBe('not a image/jpeg image');
    expect((await photo(u, { image: 'not base64 at all!!' })).statusCode).toBe(422);
    const big = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(PHOTO_MAX_BYTES, 1)]).toString('base64');
    expect((await photo(u, { image: big })).statusCode).toBe(422);
    expect((await photo(u, { mimeType: 'image/gif' })).statusCode).toBe(422);
    expect((await photo(u, { extra: 1 })).statusCode).toBe(422);
    const free = await photo(await user({ premium: false }), {});
    expect(free.statusCode).toBe(403);
    expect(issue(free)).toBe('premium-required');
    expect(ai.requests.length).toBe(before);
  });

  it("the mess menu goes with the photo; a dish picked from it is a mess dish at the mess table's numbers (twice seen = one line), loggable as a mess log; other foods as in Describe your meal; nothing stored", async () => {
    const u = await user({ mess: true });
    const menu = await lunchMenu(u);
    const dishes = menu.meals.find((m) => m.slot === 'lunch')!.dishes.filter((d) => d.nutrition !== null);
    expect(dishes.length).toBeGreaterThan(1);
    const first = dishes[0]!;
    ai.script = [
      said([
        item({ phrase: 'rice on the left', name: first.name, quantity: 1, menuDish: 1, kcal: 999 }),
        item({ phrase: 'more rice', name: first.name, quantity: 0.5, menuDish: 1 }),
        item({ phrase: '2 chapati', name: 'chapati', quantity: 2, unit: 'pieces', grams: 80 }),
        item({ phrase: 'a dish not on the menu', name: 'Qzxv special', quantity: 1, menuDish: 99, kcal: 200, proteinG: 6, carbG: 30, fatG: 6 }),
      ]),
    ];
    const r = await photo(u, {});
    expect(r.statusCode, r.body).toBe(200);
    const body = parseFoodPhotoResponseSchema.parse(r.json());
    expect(body.mess).toEqual({ code: menu.mess.code, menuDate: today() });
    expect(body.draft).toMatchObject({ source: 'ai-draft', requiresConfirmation: true });
    const [rice, chapati, special] = body.draft.data.items;
    expect(body.draft.data.items).toHaveLength(3);

    // The mess table's numbers, not the model's (it said 999 kcal); 1 + 0.5 servings on one line.
    const n1 = first.nutrition!;
    expect(rice!.messDish).toMatchObject({ dishSlug: first.slug, name: first.name, servingLabel: n1.servingLabel, servings: 1.5 });
    expect(rice!.messDish!.perServing).toEqual({ kcalLow: n1.kcalLow, kcalHigh: n1.kcalHigh, proteinLow: n1.proteinLow, proteinHigh: n1.proteinHigh, carbLow: n1.carbLow, carbHigh: n1.carbHigh, fatLow: n1.fatLow, fatHigh: n1.fatHigh });
    expect(rice!.messDish!.snapshot.kcalLow).toBeGreaterThanOrEqual(Math.floor(n1.kcalLow * 1.5) - 1);
    expect(rice!.messDish!.snapshot.kcalHigh).toBeLessThanOrEqual(Math.ceil(n1.kcalHigh * 1.5) + 1);
    expect(rice!.match).toBeNull();
    expect(rice!.estimate).toBeNull();
    // Never "high" from a photo.
    expect(rice!.confidence).toBe('medium');
    expect(chapati!.match).toMatchObject({ name: 'Chapati', servings: 2 });
    expect(chapati!.messDish).toBeNull();
    expect(chapati!.confidence).toBe('medium');
    // A menu number that is not on the menu is no dish: an estimate.
    expect(special!.messDish).toBeNull();
    expect(special!.estimate).toMatchObject({ name: 'Qzxv special', kcal: 200 });

    // What reached the model: the photo, then the numbered menu; the photo prompt; JSON mode.
    const req = ai.requests.at(-1)!;
    expect(req.system).toBe(PHOTO_SYSTEM);
    expect(req.jsonMode).toBe(true);
    expect(req.messages).toHaveLength(1);
    expect(req.messages[0]!.images).toEqual([{ mimeType: 'image/jpeg', data: JPEG }]);
    expect(req.messages[0]!.content).toContain(`1. ${first.name} (a serving is ${n1.servingLabel})`);
    expect(req.messages[0]!.content).not.toContain('@vit.ac.in');

    // Nothing stored: no log, one usage row for the purpose `photo`, and the photo is in no table.
    expect(await foodLogs(u)).toBe(0);
    expect(await usage(u)).toEqual([{ route: 'photo', outcome: 'ok', input_tokens: 1300 }]);
    const [found] = await sql<{ n: string }[]>`select count(*)::text as n from ai_usage where model like ${`%${JPEG.slice(0, 20)}%`}`;
    expect(found!.n).toBe('0');

    // The draft logs as it says: the mess dish as a mess log for that menu.
    const logged = await app.inject({
      method: 'POST',
      url: '/v1/nutrition/logs',
      headers: auth(u.token),
      payload: { clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'mess', mess: body.mess!.code, menuDate: body.mess!.menuDate, items: [{ dishSlug: rice!.messDish!.dishSlug, servings: rice!.messDish!.servings }] },
    });
    expect(logged.statusCode, logged.body).toBeLessThan(300);
    expect(await foodLogs(u)).toBe(1);
  });

  it('no mess: only the photo and the meal; a menu number the model invents is ignored', async () => {
    const u = await user();
    ai.script = [said([item({ phrase: '2 chapati', name: 'chapati', quantity: 2, unit: 'pieces', grams: 80, menuDish: 1 })])];
    const body = parseFoodPhotoResponseSchema.parse((await photo(u, { slot: 'dinner' })).json());
    expect(body.mess).toBeNull();
    expect(body.draft.data.items[0]!.match).toMatchObject({ name: 'Chapati' });
    expect(ai.requests.at(-1)!.messages[0]!.content).toBe('A photo of a dinner.');
  });

  it('no food in the photo: an empty draft, recorded as discarded; a malformed answer is a failure', async () => {
    const u = await user();
    ai.script = [said([])];
    const empty = parseFoodPhotoResponseSchema.parse((await photo(u, {})).json());
    expect(empty.draft.data.items).toEqual([]);
    expect(empty.draft.confidence).toBe('low');
    ai.script = [{ text: 'a plate of food', toolCalls: [], finishReason: 'stop' }];
    expect((await photo(u, {})).statusCode).toBeGreaterThanOrEqual(500);
    expect((await usage(u)).map((x) => x.outcome)).toEqual(['discarded', 'failed']);
  });

  it('photos have a cap per day (20), apart from the hourly limit; Describe your meal still works', async () => {
    const u = await user();
    for (let i = 0; i < 20; i += 1) {
      await sql`insert into ai_usage (user_id, route, model, outcome, created_at) values (${u.id}, 'photo', 'fake-1', 'ok', now() - interval '3 hours')`;
    }
    const before = ai.requests.length;
    const r = await photo(u, {});
    expect(r.statusCode).toBe(429);
    expect(issue(r)).toBe('daily photo limit');
    expect(ai.requests.length).toBe(before);
    ai.script = [said([item({ phrase: 'dal', name: 'dal tadka', quantity: 1, unit: 'katori', grams: 150 })])];
    expect((await app.inject({ method: 'POST', url: '/v1/nutrition/parse', headers: auth(u.token), payload: { text: 'a katori of dal' } })).statusCode).toBe(200);
  });
});
