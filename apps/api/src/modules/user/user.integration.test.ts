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

  const call = (method: 'GET' | 'PUT' | 'PATCH' | 'POST' | 'DELETE', path: string, payload?: Record<string, unknown>) =>
    // One client address per user, as the session calls do: the API rate-limits by IP.
    app.inject({
      method,
      url: `/v1${path}`,
      headers: { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.51.100.${100 + n}` },
      ...(payload !== undefined ? { payload } : {}),
    });

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
      { step: 'about', displayName: 'Persona', sex: 'male', birthDate: '2000-06-01', heightCm: 178, weightKg: 82, consent },
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

  describe('your own targets (beta 3.2, ADR-031)', () => {
    type View = { current: { kcal: number; proteinG: number; carbG: number; fatG: number; source: string; reason: string }; suggestion: { kcal: number; proteinG: number }; limits: Record<string, number> };
    const view = async () => (await call('GET', '/user/targets')).json() as View;

    it("GET: FITOS's targets in effect, its suggestion beside them, and the limits for this weight (82 kg)", async () => {
      const v = await view();
      expect(v.current).toMatchObject({ source: 'fitos', reason: 'onboarding' });
      expect(v.suggestion).toMatchObject({ kcal: v.current.kcal, proteinG: v.current.proteinG });
      // Protein 0.6–3.3 g/kg of 82 kg: 50–270 g.
      expect(v.limits).toEqual({ kcalMin: 1200, kcalMax: 6000, proteinMinG: 50, proteinMaxG: 270 });
    });

    it('PUT sets calories and protein; FITOS splits the rest; a new history row marked custom, shown wherever targets are', async () => {
      const before = (await targetRows()) ?? 0;
      const r = await call('PUT', '/user/targets/custom', { kcal: 2200, proteinG: 170 });
      expect(r.statusCode, r.body).toBe(200);
      // fat = max(0.8 × 82 = 65.6, 2200 × 0.22 / 9 = 53.8) → 66; carbs = (2200 − 680 − 594) / 4 = 231.5 → 232; fibre 30.8 → 31.
      expect(r.json().targets).toMatchObject({ kcal: 2200, proteinG: 170, fatG: 66, carbG: 232, fiberG: 31, source: 'custom', reason: 'custom' });
      expect(r.json().warnings).toEqual(expect.any(Array));
      expect(r.json().targets.rationale[0]).toBe('Your own target: 2200 kcal and 170 g protein.');
      expect(await targetRows()).toBe(before + 1);
      expect((await call('GET', '/user/goal')).json().targets).toMatchObject({ kcal: 2200, source: 'custom' });
      expect((await view()).current).toMatchObject({ kcal: 2200, source: 'custom' });
    });

    it('limits are refused with the field (422); nothing is written', async () => {
      const before = (await targetRows()) ?? 0;
      const field = async (body: Record<string, unknown>) => {
        const r = await call('PUT', '/user/targets/custom', body);
        expect(r.statusCode, JSON.stringify(body)).toBe(422);
        return (r.json() as { error: { details: { path: string }[] } }).error.details[0]?.path;
      };
      expect(await field({ kcal: 1100, proteinG: 150 })).toBe('kcal');
      expect(await field({ kcal: 6100, proteinG: 150 })).toBe('kcal');
      expect(await field({ kcal: 2200, proteinG: 49 })).toBe('proteinG');
      expect(await field({ kcal: 2200, proteinG: 271 })).toBe('proteinG');
      // 270 g protein (1080 kcal) and the 66 g fat floor (594 kcal) do not fit in 1300 kcal.
      expect(await field({ kcal: 1300, proteinG: 270 })).toBe('kcal');
      expect((await call('PUT', '/user/targets/custom', { kcal: 2200, proteinG: 150, carbG: 200 })).statusCode).toBe(422);
      expect((await call('PUT', '/user/targets/custom', { kcal: 2200.5, proteinG: 150 })).statusCode).toBe(422);
      expect(await targetRows()).toBe(before);
    });

    it('far from the suggestion: allowed, with plain warnings', async () => {
      const s = (await view()).suggestion;
      const kcal = Math.round(s.kcal * 1.4);
      const r = await call('PUT', '/user/targets/custom', { kcal, proteinG: 60 });
      expect(r.statusCode, r.body).toBe(200);
      expect(r.json().warnings).toEqual([
        expect.stringMatching(/^4\d % above FITOS's suggestion of \d+ kcal\.$/),
        '0.7 g protein per kg is below the 1.2–2.2 g that supports training.',
      ]);
    });

    it('a weight or profile change keeps your own target; a goal change goes back to FITOS', async () => {
      await call('PUT', '/user/targets/custom', { kcal: 2200, proteinG: 170 });
      const rows = (await targetRows()) ?? 0;
      expect((await call('PATCH', '/user/profile', { weightKg: 80 })).statusCode).toBe(200);
      expect((await call('PATCH', '/user/profile', { activityLevel: 'moderate' })).statusCode).toBe(200);
      expect(await targetRows()).toBe(rows);
      expect((await view()).current).toMatchObject({ kcal: 2200, proteinG: 170, source: 'custom' });
      // The suggestion follows the new weight and activity.
      expect((await view()).limits).toMatchObject({ proteinMinG: 48, proteinMaxG: 264 });
      const g = await call('PUT', '/user/goal', { goalType: 'muscle-gain' });
      expect(g.statusCode, g.body).toBe(200);
      expect(g.json().targets).toMatchObject({ source: 'fitos', reason: 'goal-change' });
      expect((await view()).current.source).toBe('fitos');
    });

    it("DELETE goes back to FITOS's suggestion once; again is a no-op", async () => {
      await call('PUT', '/user/targets/custom', { kcal: 2200, proteinG: 170 });
      const rows = (await targetRows()) ?? 0;
      const r = await call('DELETE', '/user/targets/custom');
      expect(r.statusCode, r.body).toBe(200);
      expect(r.json().current).toMatchObject({ source: 'fitos', reason: 'reset-to-fitos', kcal: r.json().suggestion.kcal, proteinG: r.json().suggestion.proteinG });
      expect(await targetRows()).toBe(rows + 1);
      expect((await call('DELETE', '/user/targets/custom')).statusCode).toBe(200);
      expect(await targetRows()).toBe(rows + 1);
    });
  });

  describe('display name (Phase 6.6)', () => {
    it('is stored by the about step, echoed on the session and the profile, and editable by PATCH', async () => {
      // The about step above answered "Persona".
      expect((await call('GET', '/user/profile')).json().displayName).toBe('Persona');
      const session = await app.inject({
        method: 'POST', url: '/v1/auth/session',
        headers: { authorization: `Bearer ${token}`, 'x-forwarded-for': `198.51.100.${100 + n}` },
        payload: {},
      });
      expect(session.json().user.displayName).toBe('Persona');
      // Trimmed on the way in; bounds enforced.
      expect((await call('PATCH', '/user/profile', { displayName: '  Srijan  ' })).json().displayName).toBe('Srijan');
      expect((await call('GET', '/user/profile')).json().displayName).toBe('Srijan');
      expect((await call('PATCH', '/user/profile', { displayName: '   ' })).statusCode).toBe(422);
      expect((await call('PATCH', '/user/profile', { displayName: 'x'.repeat(41) })).statusCode).toBe(422);
    });

    it('a user who never answered has null, never a placeholder', async () => {
      n += 1;
      const fresh = `us-tok-${n}`;
      verifier.accept(fresh, { uid: `us-uid-${n}` });
      const r = await app.inject({
        method: 'POST', url: '/v1/auth/session',
        headers: { authorization: `Bearer ${fresh}`, 'x-forwarded-for': `198.51.100.${100 + n}` },
        payload: {},
      });
      expect(r.json().user.displayName).toBeNull();
    });
  });

  describe('personal details editor (Phase 6.6 Gate 7)', () => {
    const latest = async () =>
      (await sql<{ weight_kg: string; source: string; measured_on: string }[]>`
        select weight_kg, source, measured_on from body_metrics
        where user_id = (select id from users where firebase_uid = ${'us-uid-' + n}) and deleted_at is null
        order by measured_on desc`);
    const reasons = async () =>
      (await sql<{ reason: string; kcal: number }[]>`
        select reason, kcal from nutrition_targets
        where user_id = (select id from users where firebase_uid = ${'us-uid-' + n})
        order by created_at`).map((r) => r.reason);

    it('sex is editable and recomputes targets through the server; the earlier targets row is kept', async () => {
      const before = (await call('GET', '/user/goal')).json().targets;
      const r = await call('PATCH', '/user/profile', { sex: 'female' });
      expect(r.statusCode, r.body).toBe(200);
      expect(r.json().sex).toBe('female');
      const after = (await call('GET', '/user/goal')).json().targets;
      expect(after.bmr).toBeLessThan(before.bmr);
      expect(await reasons()).toEqual(['onboarding', 'profile-change']);
    });

    it('weight is recorded as the manual reading of today (one per day), shown as the latest, and recomputes targets as a weight change', async () => {
      const before = (await call('GET', '/user/goal')).json().targets;
      const r = await call('PATCH', '/user/profile', { weightKg: 76.5 });
      expect(r.statusCode, r.body).toBe(200);
      expect(r.json().latestWeightKg).toBe(76.5);
      const rows = await latest();
      // Onboarding recorded today too: the same day's reading is replaced, not duplicated.
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ weight_kg: '76.50', source: 'manual' });
      const after = (await call('GET', '/user/goal')).json().targets;
      expect(after.kcal).not.toBe(before.kcal);
      expect(await reasons()).toEqual(['onboarding', 'weight-change']);
    });

    it('the reading of an earlier day is history, not overwritten', async () => {
      await sql`update body_metrics set measured_on = '2026-01-01'
        where user_id = (select id from users where firebase_uid = ${'us-uid-' + n})`;
      await call('PATCH', '/user/profile', { weightKg: 80 });
      const rows = await latest();
      expect(rows.map((x) => [x.measured_on === '2026-01-01' ? 'earlier' : 'today', x.weight_kg, x.source])).toEqual([
        ['today', '80.00', 'manual'],
        ['earlier', '82.00', 'onboarding'],
      ]);
      expect((await call('GET', '/user/profile')).json().latestWeightKg).toBe(80);
    });

    it('name, sex, height, weight and activity in one save: one targets recompute, all stored', async () => {
      const r = await call('PATCH', '/user/profile', { displayName: 'Asha', sex: 'female', heightCm: 165, weightKg: 60, activityLevel: 'moderate' });
      expect(r.statusCode, r.body).toBe(200);
      expect(r.json()).toMatchObject({ displayName: 'Asha', sex: 'female', heightCm: 165, latestWeightKg: 60, activityLevel: 'moderate' });
      expect(await reasons()).toEqual(['onboarding', 'profile-change']);
    });

    it('the contract bounds apply: impossible weight, unknown sex, and targets are never client-writable', async () => {
      expect((await call('PATCH', '/user/profile', { weightKg: 20 })).statusCode).toBe(422);
      expect((await call('PATCH', '/user/profile', { weightKg: 301 })).statusCode).toBe(422);
      expect((await call('PATCH', '/user/profile', { sex: 'other' })).statusCode).toBe(422);
      expect((await call('PATCH', '/user/profile', { kcal: 1500 })).statusCode).toBe(422);
      expect((await call('PATCH', '/user/profile', { targets: { kcal: 1500 } })).statusCode).toBe(422);
      expect(await reasons()).toEqual(['onboarding']);
    });

    it('a goal change goes through PUT /user/goal: the old goal is closed and targets recompute as a goal change', async () => {
      const r = await call('PUT', '/user/goal', { goalType: 'muscle-gain' });
      expect(r.statusCode, r.body).toBe(200);
      expect(r.json().goal.goalType).toBe('muscle-gain');
      expect(await reasons()).toEqual(['onboarding', 'goal-change']);
    });
  });

  describe('profile', () => {
    it('GET returns what onboarding stored, with numerics as numbers', async () => {
      const r = await call('GET', '/user/profile');
      expect(r.statusCode).toBe(200);
      expect(r.json()).toMatchObject({
        displayName: 'Persona',
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
