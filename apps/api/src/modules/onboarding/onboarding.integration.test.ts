/**
 * Onboarding end to end on real Postgres. Covers the four §31 Phase 2 tests —
 * target computation per goal, protein never above 2.2 g/kg, onboarding
 * resumes after interruption, under-18 rejected — plus consent evidence and
 * the manual-calculation check §31 asks for.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { CURRENT_POLICY_VERSION } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('onboarding (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'ob-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  /** A fresh signed-in user with a session row, returning their bearer token. */
  async function newUser(): Promise<string> {
    n += 1;
    const token = `ob-tok-${n}`;
    verifier.accept(token, { uid: `ob-uid-${n}`, email: `ob${n}@vit.ac.in` });
    // Each user arrives from its own IP: /auth/session is 10/min/IP (§10) and
    // this suite creates more users than that. trustProxy honours the header.
    const r = await app.inject({
      method: 'POST',
      url: '/v1/auth/session',
      headers: { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.51.100.${n}` },
      payload: { timezone: 'Asia/Kolkata' },
    });
    expect(r.statusCode).toBe(200);
    return token;
  }

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  const answer = (token: string, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: { authorization: `Bearer ${token}` }, payload: body });
  const state = (token: string) =>
    app.inject({ method: 'GET', url: '/v1/onboarding/state', headers: { authorization: `Bearer ${token}` } });
  const complete = (token: string) =>
    app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: { authorization: `Bearer ${token}` } });

  /** Persona C from the spec: 20-year-old woman, 163 cm, 59 kg, light activity, 4 days. */
  const personaC = [
    { step: 'goal', goalType: 'muscle-gain' },
    { step: 'about', sex: 'female', birthDate: '2006-03-15', heightCm: 163, weightKg: 59, consent },
    { step: 'experience', experienceLevel: 'beginner', trainingDaysPerWeek: 4, activityLevel: 'light' },
    { step: 'training', trainingLocation: 'campus-gym', equipment: ['dumbbell', 'machine'] },
    { step: 'food', dietType: 'vegetarian', allergies: [{ allergen: 'peanut', severity: 'severe' }] },
    { step: 'vit', isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: 'womens', messId: 'veg' } },
  ];

  let token: string;
  beforeEach(async () => {
    token = await newUser();
  });

  it('a new user starts at goal with nothing answered', async () => {
    const r = await state(token);
    expect(r.statusCode).toBe(200);
    expect(r.json().stage).toBe('goal');
    expect(r.json().answered).toEqual([]);
    expect(r.json().missing).toEqual(['goal', 'about', 'experience', 'training', 'food']);
    expect(r.json().policyVersion).toBe(CURRENT_POLICY_VERSION);
  });

  it('walks all six screens and completes with REAL targets that match a manual calculation', async () => {
    for (const a of personaC) {
      const r = await answer(token, a);
      expect(r.statusCode, a.step as string).toBe(200);
    }
    const s = await state(token);
    expect(s.json().stage).toBe('complete');
    expect(s.json().missing).toEqual([]);

    const done = await complete(token);
    expect(done.statusCode).toBe(200);
    const { targets, profile, goal } = done.json();

    // Manual calculation (§13.1), age 20 as of 2026-09-21:
    //   BMR (Mifflin, female) = 10*59 + 6.25*163 - 5*20 - 161 = 590 + 1018.75 - 100 - 161 = 1347.75 -> 1348
    //   TDEE = 1348 * (1.375 + 4*0.04) = 1348 * 1.535 = 2069.2 -> 2069
    //   kcal (muscle gain +10%) = 2276
    //   protein = 59 * 1.8 = 106.2 -> 106
    //   fat = max(59*0.8, 2276*0.22/9) = max(47.2, 55.6) -> 56
    //   carbs = (2276 - 106*4 - 56*9) / 4 = (2276 - 424 - 504)/4 = 337
    expect(targets.bmr).toBe(1348);
    expect(targets.tdeeEstimate).toBe(2069);
    expect(targets.kcal).toBe(2276);
    expect(targets.proteinG).toBe(106);
    expect(targets.fatG).toBe(56);
    expect(targets.carbG).toBe(337);
    expect(targets.fiberG).toBe(Math.round((2276 / 1000) * 14));
    expect(targets.reason).toBe('onboarding');
    expect(targets.rationale.join(' ')).toContain('Mifflin-St Jeor');
    expect(targets.effectiveFrom).toMatch(/^\d{4}-\d{2}-\d{2}$/);

    expect(profile.onboardingStage).toBe('complete');
    expect(profile.mess).toEqual({ providerId: 'vit-vellore', hostelId: 'womens', messId: 'veg' });
    expect(profile.latestWeightKg).toBe(59);
    expect(goal.goalType).toBe('muscle-gain');

    // Persisted as a history row, and the preferences row now exists with defaults.
    const rows = await sql<{ n: number }[]>`select count(*)::int as n from nutrition_targets where user_id = (select id from users where firebase_uid = ${'ob-uid-' + n})`;
    expect(rows[0]?.n).toBe(1);
    const prefs = await app.inject({ method: 'GET', url: '/v1/user/preferences', headers: { authorization: `Bearer ${token}` } });
    expect(prefs.json().units).toBe('metric');
  });

  it('never prescribes protein above 2.2 g/kg, for every goal, through the API', async () => {
    for (const a of personaC) await answer(token, a);
    for (const goalType of ['muscle-gain', 'fat-loss', 'recomposition', 'strength', 'general', 'maintenance']) {
      const r = await app.inject({
        method: 'PUT',
        url: '/v1/user/goal',
        headers: { authorization: `Bearer ${token}` },
        payload: { goalType },
      });
      expect(r.statusCode, goalType).toBe(200);
      const t = r.json().targets;
      expect(t, goalType).not.toBeNull();
      expect(t.proteinG / 59, goalType).toBeLessThanOrEqual(2.2 + 0.01); // rounding slack
      expect(t.reason).toBe('goal-change');
    }
    // Six goal changes = six history rows plus none from onboarding (not completed).
    const rows = await sql<{ n: number }[]>`select count(*)::int as n from nutrition_targets where user_id = (select id from users where firebase_uid = ${'ob-uid-' + n})`;
    expect(rows[0]?.n).toBe(6);
  });

  it('resumes after interruption: a fresh read returns every stored answer', async () => {
    await answer(token, personaC[0]!);
    await answer(token, personaC[1]!);
    await answer(token, personaC[2]!);
    // "Kill the app": nothing client-side survives. A new GET must know where we were.
    const r = await state(token);
    expect(r.json().stage).toBe('training');
    expect(r.json().answered).toEqual(['goal', 'about', 'experience']);
    expect(r.json().goalType).toBe('muscle-gain');
    expect(r.json().profile.sex).toBe('female');
    expect(r.json().profile.heightCm).toBe(163);
    expect(r.json().profile.latestWeightKg).toBe(59);
    expect(r.json().profile.trainingDaysPerWeek).toBe(4);
    expect(r.json().profile.onboardingStage).toBe('training');
  });

  it('"back" works: re-answering a step replaces it and does not move the stage backwards', async () => {
    for (const a of personaC.slice(0, 3)) await answer(token, a);
    const r = await answer(token, { step: 'goal', goalType: 'fat-loss' });
    expect(r.statusCode).toBe(200);
    expect(r.json().goalType).toBe('fat-loss');
    expect(r.json().stage).toBe('training'); // still the first gap, not 'about'
    // Exactly one goal row is active; the earlier one was closed, not stacked.
    const rows = await sql<{ n: number }[]>`select count(*)::int as n from user_goals where ended_at is null and user_id = (select id from users where firebase_uid = ${'ob-uid-' + n})`;
    expect(rows[0]?.n).toBe(1);
  });

  it('rejects an under-18 birth date and stores nothing from that step', async () => {
    const r = await answer(token, { ...personaC[1]!, birthDate: '2010-01-01' });
    expect(r.statusCode).toBe(422);
    expect(r.json().error.code).toBe('VALIDATION_FAILED');
    expect(r.json().error.details[0].path).toBe('birthDate');
    const s = await state(token);
    expect(s.json().answered).not.toContain('about');
    expect(s.json().profile.sex).toBeNull();
    const consents = await sql<{ n: number }[]>`select count(*)::int as n from consent_records where user_id = (select id from users where firebase_uid = ${'ob-uid-' + n})`;
    expect(consents[0]?.n).toBe(0);
  });

  it('accepts someone who turns 18 today and rejects someone who turns 18 tomorrow', async () => {
    const todayIST = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
    const [y, m, d] = todayIST.split('-').map(Number) as [number, number, number];
    const pad = (x: number) => String(x).padStart(2, '0');
    const eighteenToday = `${y - 18}-${pad(m)}-${pad(d)}`;
    const tomorrow = new Date(Date.UTC(y - 18, m - 1, d + 1));
    const eighteenTomorrow = `${tomorrow.getUTCFullYear()}-${pad(tomorrow.getUTCMonth() + 1)}-${pad(tomorrow.getUTCDate())}`;

    expect((await answer(token, { ...personaC[1]!, birthDate: eighteenToday })).statusCode).toBe(200);
    const t2 = await newUser();
    expect((await answer(t2, { ...personaC[1]!, birthDate: eighteenTomorrow })).statusCode).toBe(422);
  });

  it('records consent with the policy version and a hashed IP, before any health data', async () => {
    await answer(token, personaC[1]!);
    const rows = await sql<{ consent_type: string; granted: boolean; policy_version: string; ip_hash: string | null }[]>`
      select consent_type, granted, policy_version, ip_hash from consent_records
      where user_id = (select id from users where firebase_uid = ${'ob-uid-' + n}) order by consent_type
    `;
    // Postgres orders an enum by declaration, not alphabetically; compare as sets.
    expect(rows.map((r) => r.consent_type).sort()).toEqual(['health-data-processing', 'privacy-policy']);
    for (const r of rows) {
      expect(r.granted).toBe(true);
      expect(r.policy_version).toBe(CURRENT_POLICY_VERSION);
      expect(r.ip_hash).toMatch(/^[0-9a-f]{64}$/);
    }
  });

  it('refuses partial consent and a stale policy version', async () => {
    const partial = await answer(token, { ...personaC[1]!, consent: { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy'] } });
    expect(partial.statusCode).toBe(422);
    expect(partial.json().error.details[0].path).toBe('consent.types');
    const stale = await answer(token, { ...personaC[1]!, consent: { ...consent, policyVersion: '1999-01-01' } });
    expect(stale.statusCode).toBe(422);
    expect(stale.json().error.details[0].path).toBe('consent.policyVersion');
  });

  it('refuses to complete with the missing steps named, and vit is not one of them', async () => {
    await answer(token, personaC[0]!);
    await answer(token, personaC[1]!);
    const r = await complete(token);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('CONFLICT');
    expect(r.json().error.details.map((d: { path: string }) => d.path)).toEqual(['experience', 'training', 'food']);
    // Only the five required; a non-VIT user completes without screen 6.
    for (const a of personaC.slice(2, 5)) await answer(token, a);
    expect((await complete(token)).statusCode).toBe(200);
  });

  it('a Firebase account with no session row gets 401, not a crash', async () => {
    verifier.accept('ob-nosession', { uid: 'ob-uid-nosession' });
    const r = await state('ob-nosession');
    expect(r.statusCode).toBe(401);
    expect(r.json().error.message).toMatch(/session/i);
  });
});
