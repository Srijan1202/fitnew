/**
 * Phase 6.6 Gate 4 on real Postgres: the context assembled from a real
 * onboarded user with a programme and a completed session; the chat
 * route through the app with a scripted model; ownership between two
 * users; what never leaves the process (Health Connect, secrets).
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type WorkoutSession } from '@fitos/contracts';

import { buildApp } from '../../app.js';
import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import { databaseUrl, testEnv } from '../../test/build-test-app.js';
import { createDatabase } from '../../db/client.js';
import { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { FakeAiProvider } from './fake-provider.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

// The context as the model receives it, parsed back for assertions.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Loose = Record<string, any>;
function contextOf(system: string): Loose {
  const marker = 'FITOS CONTEXT (JSON):';
  return JSON.parse(system.slice(system.indexOf(marker) + marker.length)) as Loose;
}

describeIfDb('/v1/ai (real Postgres, scripted model)', () => {
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
    await sql`delete from users where firebase_uid like 'ai-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.116.${(n % 200) + 1}` });

  async function onboarded(name: string): Promise<string> {
    n += 1;
    const token = `ai-tok-${n}`;
    verifier.accept(token, { uid: `ai-uid-${n}`, email: `ai${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: name, sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      const r = await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(token), payload: body });
      expect(r.statusCode, r.body).toBe(200);
    }
    expect((await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(token), payload: {} })).statusCode).toBe(200);
    return token;
  }

  async function withProgramAndSession(name: string): Promise<{ token: string; program: Program; session: WorkoutSession }> {
    const token = await onboarded(name);
    const program: Program = (await app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth(token), payload: {} })).json();
    const day = program.days.find((d) => !d.isRest)!;
    const started = new Date(Date.now() - 2 * 86_400_000).toISOString();
    const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt: started } })).json();
    const x = s.exercises[0]!;
    await app.inject({
      method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth(token),
      payload: { sets: x.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: t.setIndex, weightKg: 50, reps: 12, rir: 1, loggedAt: started })) },
    });
    const session: WorkoutSession = (await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(token), payload: { completedAt: new Date(Date.now() - 2 * 86_400_000 + 3_000_000).toISOString() } })).json();
    return { token, program, session };
  }

  const chat = (token: string, message: string) =>
    app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(token), payload: { message } });

  it('chat and status are default-deny', async () => {
    expect((await app.inject({ method: 'POST', url: '/v1/ai/chat', headers: { 'x-forwarded-for': '203.0.116.250' }, payload: { message: 'hi' } })).statusCode).toBe(401);
    expect((await app.inject({ method: 'GET', url: '/v1/ai/status', headers: { 'x-forwarded-for': '203.0.116.250' } })).statusCode).toBe(401);
  });

  it('the context is the real user: name, goal targets, programme, today, the completed session with its sets; food and Health Connect stated as absent', async () => {
    const { token, program, session } = await withProgramAndSession('Persona');
    ai.script = [{ text: 'Answer.', toolCalls: [], finishReason: 'stop' }];
    const r = await chat(token, 'What is my programme?');
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json()).toMatchObject({ text: 'Answer.', toolsUsed: [], model: 'fake-1' });
    const system = ai.requests.at(-1)!.system;
    const ctx = contextOf(system);
    expect(ctx['profile']).toMatchObject({ displayName: 'Persona', heightCm: 175, latestWeightKg: 70, equipment: ['barbell', 'dumbbell', 'machine', 'cable'], timezone: 'Asia/Kolkata' });
    expect(ctx['profile']['ageYears']).toBe(22);
    expect(ctx['goal']).toMatchObject({ type: 'muscle-gain', targets: { kcal: expect.any(Number), proteinG: expect.any(Number) } });
    expect(ctx['programme']).toMatchObject({ name: program.name, splitType: program.splitType, mesocycleWeek: 1 });
    expect(ctx['programme']['days']).toHaveLength(7);
    expect(ctx['today']).toMatchObject({ status: expect.stringMatching(/ready|rest/), deload: { state: 'none' } });
    expect(ctx['recentSessions']).toHaveLength(1);
    expect(ctx['recentSessions'][0]).toMatchObject({ sessionId: session.id, name: session.name, workingSets: session.exercises[0]!.targets.length });
    expect(ctx['recentSessions'][0]['exercises'][0]['sets'][0]).toBe('50kg×12@1');
    expect(ctx['nutrition']).toMatchObject({ loggingAvailable: false });
    expect(ctx['health']).toMatchObject({ availableToServer: false });
    // Nothing that only the phone knows: no health *values*, only the
    // statement that they are unavailable. And nothing internal.
    expect(ctx['health']).toEqual({ availableToServer: false, note: expect.any(String) });
    expect(system).not.toMatch(/"(steps|sleep|restingHeartRate|bodyFat|activeCalories|weekSteps|fetchedAt)"\s*:/);
    expect(system).not.toMatch(/firebase_uid|ai-uid-|password|GEMINI|api[_-]?key/i);
    // Bounded: the whole instruction fits in a modest budget.
    expect(system.length).toBeLessThan(20_000);
  });

  it('with no history and no programme the context says so instead of inventing', async () => {
    const token = await onboarded('Fresh');
    ai.script = [{ text: 'Answer.', toolCalls: [], finishReason: 'stop' }];
    expect((await chat(token, 'What did I do last workout?')).statusCode).toBe(200);
    const system = ai.requests.at(-1)!.system;
    const ctx = contextOf(system);
    expect(ctx['programme']).toBeNull();
    expect(ctx['recentSessions']).toEqual([]);
    expect(ctx['today']).toMatchObject({ status: 'no-programme' });
  });

  it('tools run against the authenticated user only: user B never sees user A through the loop', async () => {
    const a = await withProgramAndSession('Alpha');
    const b = await onboarded('Bravo');
    // The model asks for the recent workouts and the profile; B has none.
    ai.script = [
      { text: '', toolCalls: [{ name: 'get_recent_workouts', args: { limit: 3 } }, { name: 'get_user_profile', args: {} }], finishReason: 'tool' },
      (req) => {
        const results = req.toolResults!;
        expect(results[0]!.result).toEqual({ sessions: [] });
        expect(results[1]!.result).toMatchObject({ profile: { displayName: 'Bravo' } });
        expect(JSON.stringify(results)).not.toContain('Alpha');
        return { text: "You haven't completed a workout yet.", toolCalls: [], finishReason: 'stop' };
      },
    ];
    const r = await chat(b, 'What did I do last workout?');
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json()).toMatchObject({ toolsUsed: ['get_recent_workouts', 'get_user_profile'], actions: expect.arrayContaining([{ type: 'open-history', label: 'History' }, { type: 'open-profile', label: 'Profile and targets' }]) });
    // A's session id, handed to B as an argument, is NOT_FOUND for B.
    ai.script = [
      { text: '', toolCalls: [{ name: 'get_workout', args: { sessionId: a.session.id } }], finishReason: 'tool' },
      (req) => {
        expect(req.toolResults![0]!.result).toMatchObject({ error: expect.stringMatching(/not found|no such/i) });
        return { text: 'I do not have that session.', toolCalls: [], finishReason: 'stop' };
      },
    ];
    expect((await chat(b, 'show me session ' + a.session.id)).statusCode).toBe(200);
  });

  it('tools answer real data: today, progression, volume, the library search; the response is the assistant\'s text plus actions, never the raw model', async () => {
    const { token, program } = await withProgramAndSession('Charlie');
    const day = program.days.find((d) => !d.isRest)!;
    const lift = day.exercises[0]!;
    ai.script = [
      { text: '', toolCalls: [{ name: 'get_today', args: {} }, { name: 'get_progression', args: { exerciseId: lift.exerciseId } }, { name: 'get_training_volume', args: {} }, { name: 'search_exercises', args: { equipment: 'dumbbell', muscle: 'chest', limit: 3 } }], finishReason: 'tool' },
      (req) => {
        const [today, progression, volume, search] = req.toolResults!.map((r) => r.result) as Loose[];
        expect(today!['today']).toMatchObject({ sessionName: expect.any(String) });
        expect(progression!['progression']).toMatchObject({ exerciseId: lift.exerciseId, recommendation: { reason: expect.any(String) } });
        expect(volume!['current']['muscles'].length).toBeGreaterThan(0);
        expect(search!['items'].length).toBeGreaterThan(0);
        expect(search!['items'].every((x: { equipment: string[] }) => x.equipment.every((e) => e === 'dumbbell' || e === 'bodyweight'))).toBe(true);
        return { text: `Stay at the plan: ${progression!['progression']['recommendation']['reason']}`, toolCalls: [], finishReason: 'stop' };
      },
    ];
    const r = await chat(token, 'Should I increase?');
    expect(r.statusCode, r.body).toBe(200);
    const body = r.json();
    expect(body.text).toMatch(/^Stay at the plan: /);
    expect(body.toolsUsed).toEqual(['get_today', 'get_progression', 'get_training_volume', 'search_exercises']);
    expect(body.actions).toEqual(expect.arrayContaining([{ type: 'open-workout', label: "Open today's workout" }, { type: 'open-progression', label: 'See the lift', exerciseId: lift.exerciseId }, { type: 'open-volume', label: 'Training volume' }]));
    expect(Object.keys(body).sort()).toEqual(['actions', 'model', 'text', 'toolsUsed']);
  });

  it('a bad enum in search_exercises is an invalid-arguments result, not a 422 to the user', async () => {
    const token = await onboarded('Delta');
    ai.script = [
      { text: '', toolCalls: [{ name: 'search_exercises', args: { muscle: 'wings' } }], finishReason: 'tool' },
      (req) => {
        expect(req.toolResults![0]!.result).toMatchObject({ error: 'invalid arguments' });
        return { text: 'No such muscle.', toolCalls: [], finishReason: 'stop' };
      },
    ];
    expect((await chat(token, 'wings?')).statusCode).toBe(200);
  });

  it('request validation: an empty message and an over-long message are 422; extra fields are rejected', async () => {
    const token = await onboarded('Echo');
    expect((await app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(token), payload: { message: '' } })).statusCode).toBe(422);
    expect((await app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(token), payload: { message: 'x'.repeat(2001) } })).statusCode).toBe(422);
    expect((await app.inject({ method: 'POST', url: '/v1/ai/chat', headers: auth(token), payload: { message: 'hi', userId: 'other' } })).statusCode).toBe(422);
  });

  it('a malformed or unavailable model is a 503 envelope with a safe message', async () => {
    const token = await onboarded('Foxtrot');
    const { AiProviderError } = await import('./provider.js');
    ai.script = [() => { throw new AiProviderError('malformed', 'upstream body: {"key":"AIza-secret"}'); }];
    let r = await chat(token, 'hi');
    expect(r.statusCode).toBe(503);
    expect(r.json().error).toMatchObject({ code: 'UPSTREAM_UNAVAILABLE' });
    expect(r.body).not.toContain('AIza');
    ai.script = [() => { throw new AiProviderError('rate_limited', 'x', 429); }];
    r = await chat(token, 'hi');
    expect(r.statusCode).toBe(429);
    ai.script = [() => { throw new AiProviderError('blocked', 'x'); }];
    r = await chat(token, 'hi');
    expect(r.statusCode).toBe(422);
  });

  it('status is configured with the fake', async () => {
    const token = await onboarded('Golf');
    const r = await app.inject({ method: 'GET', url: '/v1/ai/status', headers: auth(token) });
    expect(r.json()).toEqual({ configured: true, provider: 'fake', model: 'fake-1', excludes: ['health-connect', 'food-log'] });
  });

  it('nothing the assistant does writes to the database', async () => {
    const { token } = await withProgramAndSession('Hotel');
    const before = await sql<{ n: number }[]>`select (select count(*) from set_logs)::int + (select count(*) from workout_sessions)::int + (select count(*) from programs)::int + (select count(*) from users)::int as n`;
    ai.script = [
      { text: '', toolCalls: TOOL_LIKE_CALLS, finishReason: 'tool' },
      { text: 'Done looking.', toolCalls: [], finishReason: 'stop' },
    ];
    expect((await chat(token, 'do everything')).statusCode).toBe(200);
    const after = await sql<{ n: number }[]>`select (select count(*) from set_logs)::int + (select count(*) from workout_sessions)::int + (select count(*) from programs)::int + (select count(*) from users)::int as n`;
    expect(after[0]!.n).toBe(before[0]!.n);
  });
});

const TOOL_LIKE_CALLS = [
  { name: 'get_user_profile', args: {} },
  { name: 'get_active_goal', args: {} },
  { name: 'get_nutrition_targets', args: {} },
  { name: 'get_today', args: {} },
  { name: 'get_current_workout', args: {} },
  { name: 'get_recent_workouts', args: { limit: 2 } },
  { name: 'get_training_volume', args: {} },
  { name: 'get_active_program', args: {} },
  { name: 'get_deload_state', args: {} },
];
