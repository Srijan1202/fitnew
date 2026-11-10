/**
 * Beta 6.1 on real Postgres with a scripted model: POST
 * /training/program/ai-draft — premium and the AI consent first; the model
 * gets the answers and the exercises this person can do (minus what they
 * left out) and nothing about them; FITOS reads the answer and keeps each
 * session within the minutes; nothing is saved; usage is its own purpose.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, aiProgrammeDraftSchema, type AiProgrammeDraft } from '@fitos/contracts';

import { buildApp } from '../../app.js';
import { createDatabase } from '../../db/client.js';
import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import { databaseUrl, testEnv } from '../../test/build-test-app.js';
import { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { FakeAiProvider } from './fake-provider.js';
import type { AiRequest, AiResponse } from './provider.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;
const said = (json: unknown): AiResponse => ({ text: typeof json === 'string' ? json : JSON.stringify(json), toolCalls: [], finishReason: 'stop', usage: { inputTokens: 900, outputTokens: 300 } });

describeIfDb('POST /v1/training/program/ai-draft (beta 6.1, real Postgres, scripted model)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildApp>>;
  let verifier: FakeTokenVerifier;
  let ai: FakeAiProvider;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    verifier = new FakeTokenVerifier();
    ai = new FakeAiProvider();
    app = await buildApp(testEnv({ DATABASE_URL: url }), { database: createDatabase(url), tokenVerifier: verifier, aiProvider: ai });
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'aiprog-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.170.${(n % 200) + 1}` });
  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  async function user(o: { premium?: boolean; aiConsent?: boolean } = {}): Promise<{ token: string; id: string }> {
    n += 1;
    const token = `aiprog-tok-${n}`;
    verifier.accept(token, { uid: `aiprog-uid-${n}`, email: `aiprog-${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Persona Secretname', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 3, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      const r = await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(token), payload: body });
      expect(r.statusCode, r.body).toBe(200);
    }
    expect((await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`aiprog-uid-${n}`}`;
    if (o.premium !== false) await sql`update users set premium_since = now() where id = ${row!.id}`;
    if (o.aiConsent !== false) {
      expect((await app.inject({ method: 'POST', url: '/v1/user/consents', headers: auth(token), payload: { type: 'ai-processing', granted: true } })).statusCode).toBe(200);
    }
    return { token, id: row!.id };
  }

  const draft = (token: string, payload: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/training/program/ai-draft', headers: auth(token), payload });

  /** A model that builds [days] days from the first ids it was given, six sets each. */
  const builds = (days: number, seen: AiRequest[]) => (request: AiRequest): AiResponse => {
    seen.push(request);
    const ids = [...request.messages[0]!.content.matchAll(/^(E\d+): /gm)].map((m) => m[1]!);
    return said({
      name: 'Push Pull Legs',
      why: 'Three sessions, each muscle twice.',
      days: Array.from({ length: days }, (_, d) => ({
        name: ['Push', 'Pull', 'Legs'][d],
        exercises: ids.slice(d * 3, d * 3 + 3).map((id) => ({ id, sets: 6, repMin: 8, repMax: 12, rir: 2 })),
      })),
    });
  };

  it('premium and the AI consent come first; nothing is sent to the model before', async () => {
    const free = await user({ premium: false });
    expect((await draft(free.token, { sessions: 3, minutes: 60 })).statusCode).toBe(403);
    const noConsent = await user({ aiConsent: false });
    const r = await draft(noConsent.token, { sessions: 3, minutes: 60 });
    expect(r.statusCode).toBe(403);
    expect(JSON.stringify(r.json())).toContain('ai-processing');
  });

  it('a draft: the answers and the exercises go to the model, nothing about the person; FITOS trims a long session and says so; nothing is saved', async () => {
    const u = await user();
    const [squat] = await sql<{ id: string; name: string }[]>`select id, name from exercises where slug = 'barbell-back-squat'`;
    const seen: AiRequest[] = [];
    ai.script = [builds(3, seen)];
    const r = await draft(u.token, { sessions: 3, minutes: 45, focus: ['chest'], avoid: [squat!.id], note: 'my knees are fine' });
    expect(r.statusCode, r.body).toBe(200);
    const d: AiProgrammeDraft = aiProgrammeDraftSchema.parse(r.json());

    const prompt = `${seen[0]!.system}\n${seen[0]!.messages[0]!.content}`;
    expect(prompt).toContain('Sessions a week: 3. Minutes a session: 45.');
    expect(prompt).toContain('Muscles to bring up: chest.');
    expect(prompt).toContain('They add: my knees are fine');
    expect(prompt).not.toContain(squat!.name);
    expect(prompt).not.toContain('Secretname');
    expect(prompt).not.toMatch(/70 ?kg/);

    expect(d.name).toBe('Push Pull Legs');
    expect(d.days.map((x) => x.sessionName)).toEqual(['Push', 'Pull', 'Legs']);
    // Three exercises at six sets is 63 minutes; 45 (+15 %) is the most.
    for (const day of d.days) expect(day.exercises.reduce((s, x) => s + x.setCount, 0) * 3.5).toBeLessThanOrEqual(45 * 1.15);
    expect(d.adjustments.some((a) => a.includes('shortened'))).toBe(true);
    expect(d.days.flatMap((x) => x.exercises.map((e) => e.exerciseId))).not.toContain(squat!.id);

    // Nothing saved; the usage is the programme purpose.
    expect((await sql`select 1 from programs where user_id = ${u.id}`).length).toBe(0);
    expect((await sql<{ route: string; outcome: string }[]>`select route, outcome from ai_usage where user_id = ${u.id}`).map((x) => [x.route, x.outcome])).toEqual([['programme', 'ok']]);
  });

  it('an answer that is not a week of the asked size is refused and recorded as discarded', async () => {
    const u = await user();
    ai.script = [builds(2, [])];
    const r = await draft(u.token, { sessions: 3, minutes: 60 });
    expect(r.statusCode).toBeGreaterThanOrEqual(500);
    expect((await sql<{ outcome: string }[]>`select outcome from ai_usage where user_id = ${u.id}`).map((x) => x.outcome)).toEqual(['discarded']);
  });

  it('the request is checked: 2–6 sessions, 30–120 minutes, a short note', async () => {
    const u = await user();
    expect((await draft(u.token, { sessions: 7, minutes: 60 })).statusCode).toBe(422);
    expect((await draft(u.token, { sessions: 3, minutes: 20 })).statusCode).toBe(422);
    expect((await draft(u.token, { sessions: 3, minutes: 60, note: 'x'.repeat(201) })).statusCode).toBe(422);
  });
});
