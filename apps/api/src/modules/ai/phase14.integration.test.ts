/**
 * Phase 14 (ADR-020) on real Postgres with the real food seed and a scripted
 * model: POST /nutrition/parse (a meal in words → an AiDraft, never stored),
 * POST /ai/explain (a TODAY reason reworded, numbers checked), the kill
 * switch, the hourly limits and the daily token budget counted from
 * `ai_usage`.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  CURRENT_POLICY_VERSION,
  explainResponseSchema,
  parseFoodResponseSchema,
  todayActionsResponseSchema,
  type ParseFoodResponse,
} from '@fitos/contracts';

import { buildApp } from '../../app.js';
import { createDatabase } from '../../db/client.js';
import { seedFoods } from '../../db/food-seed/load.js';
import { migrateUp } from '../../db/migrate.js';
import type { Env } from '../../lib/env.js';
import { databaseUrl, testEnv } from '../../test/build-test-app.js';
import { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { FakeAiProvider } from './fake-provider.js';
import { EXPLAIN_SYSTEM } from './explain.js';
import { PARSE_SYSTEM } from './parse.js';
import type { AiResponse } from './provider.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

/** A model answer for the parser: the JSON it must produce. */
function answer(items: Record<string, unknown>[], usage?: AiResponse['usage']): AiResponse {
  return { text: JSON.stringify({ items }), toolCalls: [], finishReason: 'stop', ...(usage !== undefined ? { usage } : {}) };
}
const item = (over: Record<string, unknown>): Record<string, unknown> => ({
  phrase: 'x', name: 'x', quantity: 1, unit: 'serving', grams: null, kcal: 100, proteinG: 5, carbG: 10, fatG: 3, confidence: 'high', ...over,
});
const said = (text: string): AiResponse => ({ text, toolCalls: [], finishReason: 'stop' });

describeIfDb('Phase 14 AI features (real Postgres, real food seed, scripted model)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let n = 0;

  interface Rig {
    app: Awaited<ReturnType<typeof buildApp>>;
    verifier: FakeTokenVerifier;
    ai: FakeAiProvider;
  }
  const rigs: Rig[] = [];
  async function rig(overrides: Partial<Env> = {}): Promise<Rig> {
    const verifier = new FakeTokenVerifier();
    const ai = new FakeAiProvider();
    const app = await buildApp(testEnv({ ...overrides, DATABASE_URL: url }), { database: createDatabase(url), tokenVerifier: verifier, aiProvider: ai });
    const r = { app, verifier, ai };
    rigs.push(r);
    return r;
  }
  let main: Rig;

  beforeAll(async () => {
    await migrateUp(url);
    await seedFoods(url);
    sql = postgres(url, { max: 1 });
    main = await rig();
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'p14-%'`;
    for (const r of rigs) await r.app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.150.${(n % 200) + 1}` });

  async function user(r: Rig = main): Promise<U> {
    n += 1;
    const token = `p14-tok-${n}`;
    r.verifier.accept(token, { uid: `p14-uid-${n}`, email: `p14-${n}@vit.ac.in` });
    expect((await r.app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`p14-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  /** Chat needs a profile: the onboarding answers, as in the Phase 6.6 suite. */
  async function onboard(u: U, r: Rig = main): Promise<void> {
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Persona', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      const a = await r.app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(u.token), payload: body });
      expect(a.statusCode, a.body).toBe(200);
    }
    expect((await r.app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(u.token), payload: {} })).statusCode).toBe(200);
  }

  const parse = (u: U, text: string, r: Rig = main) =>
    r.app.inject({ method: 'POST', url: '/v1/nutrition/parse', headers: auth(u.token), payload: { text } });
  const explain = (u: U, actionId: string, r: Rig = main) =>
    r.app.inject({ method: 'POST', url: '/v1/ai/explain', headers: auth(u.token), payload: { actionId } });
  const usage = (u: U) =>
    sql<{ route: string; model: string; input_tokens: number; output_tokens: number; outcome: string }[]>`
      select route, model, input_tokens, output_tokens, outcome from ai_usage where user_id = ${u.id} order by created_at, id`;
  const foodLogs = async (u: U) => Number((await sql<{ n: string }[]>`select count(*)::text as n from food_logs where user_id = ${u.id}`)[0]!.n);
  const issue = (r: { json: () => unknown }): string | undefined =>
    (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  /** A TODAY action the user owns (a bare user always has log-weight). */
  async function action(u: U, r: Rig = main): Promise<{ id: string; headline: string; detail: string }> {
    const t = todayActionsResponseSchema.parse((await r.app.inject({ method: 'GET', url: '/v1/today', headers: auth(u.token) })).json());
    const a = t.actions.find((x) => x.kind === 'log-weight')!;
    return { id: a.id, headline: a.headline, detail: a.detail };
  }

  /* ------------------------------------------------------------ access -- */

  it('both routes are default-deny and validate their body', async () => {
    const anon = { 'x-forwarded-for': '203.0.151.1' };
    expect((await main.app.inject({ method: 'POST', url: '/v1/nutrition/parse', headers: anon, payload: { text: 'two chapati' } })).statusCode).toBe(401);
    expect((await main.app.inject({ method: 'POST', url: '/v1/ai/explain', headers: anon, payload: { actionId: randomUUID() } })).statusCode).toBe(401);
    const u = await user();
    expect((await parse(u, '')).statusCode).toBe(422);
    expect((await parse(u, 'x'.repeat(501))).statusCode).toBe(422);
    expect((await main.app.inject({ method: 'POST', url: '/v1/nutrition/parse', headers: auth(u.token), payload: { text: 'dal', extra: 1 } })).statusCode).toBe(422);
    expect((await explain(u, 'not-a-uuid')).statusCode).toBe(422);
    expect(main.ai.requests).toHaveLength(0);
  });

  /* ------------------------------------------------------------- parse -- */

  it('parse: database foods at their own portions, an unknown food as a bounded estimate, an unbelievable one as a problem — a draft that needs confirmation, nothing stored', async () => {
    const u = await user();
    main.ai.script = [
      answer(
        [
          item({ phrase: '2 chapati', name: 'chapati', quantity: 2, unit: 'pieces', grams: 80, kcal: 999, proteinG: 99 }),
          item({ phrase: 'a katori of dal', name: 'dal tadka', quantity: 1, unit: 'katori', grams: 150 }),
          item({ phrase: 'a zqxv bar', name: 'Zqxv crunch bar', quantity: 1, unit: 'piece', grams: 40, kcal: 180, proteinG: 8, carbG: 22, fatG: 7, confidence: 'medium' }),
          item({ phrase: 'mystery shake', name: 'Qwzx mega shake', quantity: 1, unit: 'glass', grams: 100, kcal: 5000, proteinG: 10, carbG: 10, fatG: 10 }),
        ],
        { inputTokens: 300, outputTokens: 120 },
      ),
    ];
    const r = await parse(u, 'had 2 chapati, a katori of dal, a zqxv bar and a mystery shake');
    expect(r.statusCode, r.body).toBe(200);
    const body: ParseFoodResponse = parseFoodResponseSchema.parse(r.json());
    expect(body.model).toBe('fake-1');
    expect(body.draft).toMatchObject({ source: 'ai-draft', requiresConfirmation: true });
    const [chapati, dal, bar, shake] = body.draft.data.items;

    // The database's numbers, not the model's (it said 999 kcal).
    expect(chapati!.match).toMatchObject({ name: 'Chapati', matchKind: 'exact', basis: 'per_serving', servingLabel: '1 piece', servings: 2 });
    expect(chapati!.match!.snapshot).toMatchObject({ kcalLow: 170, kcalHigh: 240 });
    expect(chapati!.confidence).toBe('high');
    expect(chapati!.estimate).toBeNull();
    expect(dal!.match).toMatchObject({ name: 'Dal tadka', servingLabel: '1 katori', servings: 1 });
    expect(dal!.match!.snapshot).toMatchObject({ kcalLow: 120, kcalHigh: 185 });

    // Not in FITOS: the model's estimate, always low confidence.
    expect(bar!.match).toBeNull();
    expect(bar!.estimate).toEqual({ name: 'Zqxv crunch bar', grams: 40, kcal: 180, proteinG: 8, carbG: 22, fatG: 7 });
    expect(bar!.confidence).toBe('low');
    expect(shake!.match).toBeNull();
    expect(shake!.estimate).toBeNull();
    expect(shake!.problem).toMatch(/not believable/);
    expect(body.draft.confidence).toBe('low');

    // Only the text reached the model: the fixed prompt, one user message, JSON mode.
    const req = main.ai.requests.at(-1)!;
    expect(req.system).toBe(PARSE_SYSTEM);
    expect(req.messages).toEqual([{ role: 'user', content: 'had 2 chapati, a katori of dal, a zqxv bar and a mystery shake' }]);
    expect(req.jsonMode).toBe(true);
    expect(req.tools ?? []).toEqual([]);

    // Returned, never stored; one usage row with its tokens.
    expect(await foodLogs(u)).toBe(0);
    expect(await usage(u)).toEqual([{ route: 'parse', model: 'fake-1', input_tokens: 300, output_tokens: 120, outcome: 'ok' }]);
  });

  it('parse: found in the live smoke — a fuzzy-only hit is not a FITOS food (an estimate instead); a count meets a counting serving', async () => {
    const u = await user();
    main.ai.script = [
      answer([
        item({ phrase: '2 slices of brown bread', name: 'brown bread', quantity: 2, unit: 'slice', grams: 60, kcal: 150, proteinG: 6, carbG: 26, fatG: 2 }),
        item({ phrase: '2 boiled eggs', name: 'boiled eggs', quantity: 2, unit: 'piece', grams: 100 }),
      ]),
    ];
    const items = parseFoodResponseSchema.parse((await parse(u, '2 boiled eggs and 2 slices of brown bread')).json()).draft.data.items;
    expect(items[0]!.match).toBeNull();
    expect(items[0]!.estimate).toMatchObject({ name: 'brown bread', kcal: 150 });
    expect(items[1]!.match).toMatchObject({ servingLabel: '2 eggs', servings: 1 });
  });

  it('parse → confirm: the matched items log through POST /nutrition/logs as a search entry, the estimate as a quick add', async () => {
    const u = await user();
    main.ai.script = [
      answer([
        item({ phrase: '2 chapati', name: 'chapati', quantity: 2, unit: 'piece' }),
        item({ phrase: 'a zqxv bar', name: 'Zqxv crunch bar', quantity: 1, unit: 'piece', grams: 40, kcal: 180, proteinG: 8, carbG: 22, fatG: 7 }),
      ]),
    ];
    const draft = parseFoodResponseSchema.parse((await parse(u, '2 chapati and a zqxv bar')).json()).draft;
    const m = draft.data.items[0]!.match!;
    const logged = await main.app.inject({
      method: 'POST', url: '/v1/nutrition/logs', headers: auth(u.token),
      payload: { clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'search', items: [{ foodId: m.foodId, basis: m.basis, servingLabel: m.servingLabel, servings: m.servings }] },
    });
    expect(logged.statusCode, logged.body).toBe(201);
    const e = draft.data.items[1]!.estimate!;
    const quick = await main.app.inject({
      method: 'POST', url: '/v1/nutrition/logs', headers: auth(u.token),
      payload: { clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'quick-add', quickAdd: { name: e.name, kcal: e.kcal, proteinG: e.proteinG, carbG: e.carbG, fatG: e.fatG } },
    });
    expect(quick.statusCode, quick.body).toBe(201);
    expect(await foodLogs(u)).toBe(2);
  });

  it('parse: a fenced answer is read; nothing edible is an empty draft (outcome discarded); a malformed answer is 503 and counted as failed', async () => {
    const u = await user();
    main.ai.script = [{ text: '```json\n' + JSON.stringify({ items: [item({ name: 'idli', quantity: 2, unit: 'piece' })] }) + '\n```', toolCalls: [], finishReason: 'stop' }];
    const fenced = parseFoodResponseSchema.parse((await parse(u, 'two idli')).json());
    // Idli's serving is "2 pieces": two pieces are one serving.
    expect(fenced.draft.data.items[0]!.match).toMatchObject({ name: 'Idli', servingLabel: '2 pieces', servings: 1 });

    main.ai.script = [answer([])];
    const empty = parseFoodResponseSchema.parse((await parse(u, 'nothing today')).json());
    expect(empty.draft.data.items).toEqual([]);

    main.ai.script = [said('Sure! You ate chapati.')];
    const bad = await parse(u, 'chapati');
    expect(bad.statusCode).toBe(503);
    main.ai.script = [answer([{ phrase: 'x' }])];
    expect((await parse(u, 'chapati')).statusCode).toBe(503);

    expect((await usage(u)).map((x) => x.outcome)).toEqual(['ok', 'discarded', 'failed', 'failed']);
    expect(await foodLogs(u)).toBe(0);
  });

  /* ----------------------------------------------------------- explain -- */

  it('explain: a rewording with only the input\'s numbers is the AI\'s; one that adds a number falls back to the engine\'s words', async () => {
    const u = await user();
    const a = await action(u);
    main.ai.script = [said('Step on the scale this morning so your trend stays honest.')];
    const ok = await explain(u, a.id);
    expect(ok.statusCode, ok.body).toBe(200);
    expect(explainResponseSchema.parse(ok.json())).toEqual({ text: 'Step on the scale this morning so your trend stays honest.', source: 'ai', discarded: null });

    // What the model saw: the action's own words and facts, nothing else.
    const req = main.ai.requests.at(-1)!;
    expect(req.system).toBe(EXPLAIN_SYSTEM);
    const input = JSON.parse(req.messages[0]!.content) as Record<string, unknown>;
    expect(Object.keys(input).sort()).toEqual(['detail', 'facts', 'headline']);
    expect(input).toMatchObject({ headline: a.headline, detail: a.detail });

    main.ai.script = [said('Weigh yourself 47 times a week.')];
    expect((await explain(u, a.id)).json()).toEqual({ text: a.detail, source: 'engine', discarded: 'new-number' });
    main.ai.script = [said('Weigh yourself forty-seven times.')];
    expect((await explain(u, a.id)).json()).toEqual({ text: a.detail, source: 'engine', discarded: 'new-number' });
    main.ai.script = [said('   ')];
    expect((await explain(u, a.id)).json()).toMatchObject({ source: 'engine', discarded: 'empty' });

    expect((await usage(u)).map((x) => `${x.route}:${x.outcome}`)).toEqual(['explain:ok', 'explain:discarded', 'explain:discarded', 'explain:discarded']);
  });

  it('explain: another user\'s action and an unknown id are 404, before any model call', async () => {
    const a = await user();
    const b = await user();
    const theirs = await action(a);
    const before = main.ai.requests.length;
    expect((await explain(b, theirs.id)).statusCode).toBe(404);
    expect((await explain(b, randomUUID())).statusCode).toBe(404);
    expect(main.ai.requests.length).toBe(before);
    expect(await usage(b)).toEqual([]);
  });

  /* -------------------------------------------------------- kill switch -- */

  it('AI_ENABLED=false: status says so; chat, parse and explain answer 503 "disabled" without calling the model; the rest of the app works', async () => {
    const off = await rig({ AI_ENABLED: false });
    const u = await user(off);
    const status = await off.app.inject({ method: 'GET', url: '/v1/ai/status', headers: auth(u.token) });
    expect(status.json()).toMatchObject({ enabled: false, configured: true });
    const a = await action(u, off);
    for (const r of [
      await off.app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(u.token), payload: { message: 'hi' } }),
      await parse(u, 'two chapati', off),
      await explain(u, a.id, off),
    ]) {
      expect(r.statusCode, r.body).toBe(503);
      expect(issue(r)).toBe('disabled');
    }
    expect(off.ai.requests).toHaveLength(0);
    expect(await usage(u)).toEqual([]);
    expect((await off.app.inject({ method: 'GET', url: '/v1/nutrition/foods/search?q=chapati', headers: auth(u.token) })).statusCode).toBe(200);
  });

  /* ------------------------------------------------------------ limits -- */

  it('hourly limit per purpose, per user, from ai_usage: the third parse is 429; explain and another user are unaffected', async () => {
    const tight = await rig({ AI_PARSE_PER_HOUR: 2 });
    const u = await user(tight);
    const v = await user(tight);
    for (let i = 0; i < 2; i += 1) {
      tight.ai.script = [answer([item({ name: 'chapati', quantity: 1, unit: 'piece' })])];
      expect((await parse(u, 'chapati', tight)).statusCode).toBe(200);
    }
    const before = tight.ai.requests.length;
    const third = await parse(u, 'chapati', tight);
    expect(third.statusCode).toBe(429);
    expect(issue(third)).toBe('hourly limit (parse)');
    expect(tight.ai.requests.length).toBe(before);

    tight.ai.script = [said('Weigh in today.')];
    expect((await explain(u, (await action(u, tight)).id, tight)).statusCode).toBe(200);
    tight.ai.script = [answer([])];
    expect((await parse(v, 'chapati', tight)).statusCode).toBe(200);

    // An hour on, the old calls no longer count.
    await sql`update ai_usage set created_at = now() - interval '61 minutes' where user_id = ${u.id} and route = 'parse'`;
    tight.ai.script = [answer([])];
    expect((await parse(u, 'chapati', tight)).statusCode).toBe(200);
  });

  it('daily token budget across purposes: once used up, chat, parse and explain are 429 until the day rolls past', async () => {
    const small = await rig({ AI_DAILY_TOKEN_BUDGET: 100 });
    const u = await user(small);
    small.ai.script = [answer([], { inputTokens: 80, outputTokens: 30 })];
    expect((await parse(u, 'chapati', small)).statusCode).toBe(200);
    const a = await action(u, small);
    for (const r of [
      await parse(u, 'chapati', small),
      await explain(u, a.id, small),
      await small.app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(u.token), payload: { message: 'hi' } }),
    ]) {
      expect(r.statusCode, r.body).toBe(429);
      expect(issue(r)).toBe('daily token budget');
    }
    await sql`update ai_usage set created_at = now() - interval '25 hours' where user_id = ${u.id}`;
    small.ai.script = [said('Weigh in today.')];
    expect((await explain(u, a.id, small)).statusCode).toBe(200);
  });

  it('chat writes a usage row per model round', async () => {
    const u = await user();
    await onboard(u);
    main.ai.script = [{ text: 'Hello.', toolCalls: [], finishReason: 'stop', usage: { inputTokens: 900, outputTokens: 12 } }];
    expect((await main.app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(u.token), payload: { message: 'hi' } })).statusCode).toBe(200);
    expect(await usage(u)).toEqual([{ route: 'chat', model: 'fake-1', input_tokens: 900, output_tokens: 12, outcome: 'ok' }]);
  });
});
