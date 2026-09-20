/**
 * /v1/user/* on real Postgres. PUT /user/goal is exercised heavily by the
 * onboarding suite; this covers profile, diet and preferences.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { CURRENT_POLICY_VERSION } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/user (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let token: string;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'us-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const call = (method: 'GET' | 'PUT' | 'PATCH' | 'POST', path: string, payload?: Record<string, unknown>) =>
    app.inject({ method, url: `/v1${path}`, headers: { authorization: `Bearer ${token}` }, ...(payload !== undefined ? { payload } : {}) });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  /** Sign in and complete onboarding so targets exist. */
  async function onboardedUser(): Promise<void> {
    n += 1;
    token = `us-tok-${n}`;
    verifier.accept(token, { uid: `us-uid-${n}` });
    await app.inject({
      method: 'POST', url: '/v1/auth/session',
      headers: { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.51.100.${100 + n}` },
      payload: {},
    });
    for (const a of [
      { step: 'goal', goalType: 'fat-loss' },
      { step: 'about', sex: 'male', birthDate: '2000-06-01', heightCm: 178, weightKg: 82, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 3, activityLevel: 'sedentary' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      expect((await call('POST', '/onboarding/answer', a)).statusCode).toBe(200);
    }
    expect((await call('POST', '/onboarding/complete')).statusCode).toBe(200);
  }

  beforeEach(onboardedUser);

  const targetRows = async () =>
    (await sql<{ n: number }[]>`select count(*)::int as n from nutrition_targets where user_id = (select id from users where firebase_uid = ${'us-uid-' + n})`)[0]?.n;

  describe('profile', () => {
    it('GET returns what onboarding stored, with numerics as numbers', async () => {
      const r = await call('GET', '/user/profile');
      expect(r.statusCode).toBe(200);
      expect(r.json()).toMatchObject({
        sex: 'male', heightCm: 178, latestWeightKg: 82, trainingDaysPerWeek: 3,
        activityLevel: 'sedentary', equipment: ['barbell', 'dumbbell'], onboardingStage: 'complete', mess: null,
      });
    });

    it('PATCH of a formula input recomputes targets; PATCH of anything else does not', async () => {
      expect(await targetRows()).toBe(1);
      const r = await call('PATCH', '/user/profile', { activityLevel: 'high' });
      expect(r.statusCode).toBe(200);
      expect(r.json().activityLevel).toBe('high');
      expect(await targetRows()).toBe(2);
      const latest = await call('GET', '/user/goal');
      expect(latest.json().targets.reason).toBe('profile-change');

      await call('PATCH', '/user/profile', { preferredSessionMinutes: 45 });
      expect(await targetRows()).toBe(2); // unchanged
    });

    it('PATCH timezone updates the user row and is reflected in the profile', async () => {
      const r = await call('PATCH', '/user/profile', { timezone: 'Europe/London' });
      expect(r.json().timezone).toBe('Europe/London');
      expect((await call('PATCH', '/user/profile', { timezone: 'IST' })).statusCode).toBe(422);
    });

    it('rejects unknown keys — a client cannot smuggle a userId', async () => {
      expect((await call('PATCH', '/user/profile', { userId: 'x' })).statusCode).toBe(422);
    });
  });

  describe('diet preferences', () => {
    it('PUT replaces the allergy list wholesale — a removed allergen is gone', async () => {
      await call('PUT', '/user/diet-preferences', {
        dietType: 'eggetarian',
        allergies: [{ allergen: 'peanut', severity: 'severe' }, { allergen: 'milk', severity: 'mild' }],
      });
      let r = await call('GET', '/user/diet-preferences');
      expect(r.json().dietType).toBe('eggetarian');
      expect(r.json().allergies.map((a: { allergen: string }) => a.allergen).sort()).toEqual(['milk', 'peanut']);

      await call('PUT', '/user/diet-preferences', { dietType: 'eggetarian', allergies: [{ allergen: 'milk', severity: 'moderate' }] });
      r = await call('GET', '/user/diet-preferences');
      expect(r.json().allergies).toEqual([{ allergen: 'milk', severity: 'moderate' }]);
    });

    it('rejects an allergen the contract does not list', async () => {
      const r = await call('PUT', '/user/diet-preferences', { dietType: 'vegetarian', allergies: [{ allergen: 'gluten', severity: 'mild' }] });
      expect(r.statusCode).toBe(422);
    });
  });

  describe('preferences', () => {
    it('exist with defaults after onboarding and PATCH partially', async () => {
      expect((await call('GET', '/user/preferences')).json()).toEqual({ units: 'metric', notificationSettings: {}, featureFlags: {} });
      const r = await call('PATCH', '/user/preferences', { units: 'imperial' });
      expect(r.json().units).toBe('imperial');
      expect(r.json().featureFlags).toEqual({});
    });
  });

  describe('goal', () => {
    it('GET returns the active goal with the latest targets', async () => {
      const r = await call('GET', '/user/goal');
      expect(r.statusCode).toBe(200);
      expect(r.json().goal.goalType).toBe('fat-loss');
      expect(r.json().targets.reason).toBe('onboarding');
    });

    it('PUT closes the previous goal — history is kept, exactly one is active', async () => {
      await call('PUT', '/user/goal', { goalType: 'maintenance', targetWeightKg: 78 });
      const rows = await sql<{ goal_type: string; ended: boolean; target: string | null }[]>`
        select goal_type, (ended_at is not null) as ended, target_weight_kg::text as target
        from user_goals where user_id = (select id from users where firebase_uid = ${'us-uid-' + n}) order by started_at
      `;
      expect(rows).toEqual([
        { goal_type: 'fat-loss', ended: true, target: null },
        { goal_type: 'maintenance', ended: false, target: '78.00' },
      ]);
    });
  });
});
