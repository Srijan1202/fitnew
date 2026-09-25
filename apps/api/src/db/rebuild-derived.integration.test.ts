/**
 * `rebuild-derived` (Phase 12, MASTER-SPEC §9.4 and §31 "derived rebuild
 * reproduces cached values exactly"; ADR-018). History is made through the
 * real API — sessions completed in order (records and weekly volume written
 * by the completion path) and food logged (the day cache written by the
 * logging path) — then the three caches are rebuilt from source rows and
 * must come out byte-for-byte the same, from a corrupted state too, and
 * again on a second run.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type WorkoutSession } from '@fitos/contracts';

import { createDatabase, type DatabaseHandle } from './client.js';
import { migrateUp } from './migrate.js';
import { rebuildDerivedOn } from './rebuild-derived.js';
import { seedExercises } from './seed.js';
import type { FakeTokenVerifier } from '../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('rebuild-derived (real Postgres, real seed)', { timeout: 120_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let handle: DatabaseHandle;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  const ids: string[] = [];

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    handle = createDatabase(url);
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'rd-%'`;
    await app.close();
    await handle.client.end({ timeout: 5 });
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  async function history(n: number): Promise<void> {
    const token = `rd-tok-${n}`;
    const auth = { authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.170.${n}` };
    verifier.accept(token, { uid: `rd-uid-${n}`, email: `rd${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth, payload: {} })).statusCode).toBe(200);
    const [u] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`rd-uid-${n}`}`;
    ids.push(u!.id);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Persona', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      expect((await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth, payload: body })).statusCode).toBe(200);
    }
    expect((await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth, payload: {} })).statusCode).toBe(200);
    const program: Program = (await app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth, payload: {} })).json();
    const day = program.days.find((d) => !d.isRest)!;

    // Four sessions over three weeks, loads rising on two lifts: records, and volume in several ISO weeks.
    for (const [ago, load] of [[20, 50], [13, 55], [6, 57.5], [1, 60]] as const) {
      const completedAt = new Date(Date.now() - ago * 86_400_000);
      const startedAt = new Date(completedAt.getTime() - 50 * 60_000).toISOString();
      const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth, payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt } })).json();
      const sets = [0, 1].flatMap((i) =>
        s.exercises[i]!.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: s.exercises[i]!.id, setIndex: t.setIndex, weightKg: load + i * 10, reps: 8 + (ago % 3), rir: 2, loggedAt: startedAt })),
      );
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth, payload: { sets } })).statusCode).toBe(200);
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth, payload: { completedAt: completedAt.toISOString() } })).statusCode).toBe(200);
    }
    // Food on three days (today's and earlier logs, including one deleted).
    for (const [ago, slot] of [[0, 'lunch'], [0, 'dinner'], [2, 'breakfast'], [5, 'snacks']] as const) {
      const r = await app.inject({
        method: 'POST', url: '/v1/nutrition/logs', headers: auth,
        payload: { clientLogId: randomUUID(), mealSlot: slot, entryMethod: 'quick-add', loggedAt: new Date(Date.now() - ago * 86_400_000).toISOString(), quickAdd: { kcal: 400 + ago * 10, proteinG: 25, carbG: 40, fatG: 12 } },
      });
      expect(r.statusCode, r.body).toBe(201);
    }
    const [log] = await sql<{ client_log_id: string }[]>`select client_log_id from food_logs where user_id = ${u!.id} order by logged_at limit 1`;
    expect((await app.inject({ method: 'DELETE', url: `/v1/nutrition/logs/${log!.client_log_id}`, headers: auth })).statusCode).toBe(200);
  }

  /** The three caches for the test users, in a canonical order, without surrogate ids or write times. */
  async function caches() {
    const prs = await sql`
      select user_id, exercise_id, pr_type, value::text, previous::text, reason, achieved_at, set_log_id
      from exercise_prs where user_id in ${sql(ids)} order by set_log_id, pr_type`;
    const flags = await sql`
      select l.id, l.is_pr from set_logs l join session_exercises e on e.id = l.session_exercise_id
      join workout_sessions s on s.id = e.session_id where s.user_id in ${sql(ids)} order by l.id`;
    const volume = await sql`
      select user_id, iso_week, muscle_group, hard_sets::text, tonnage_kg::text
      from muscle_volume_weekly where user_id in ${sql(ids)} order by user_id, iso_week, muscle_group`;
    const nutrition = await sql`
      select user_id, local_date, kcal_low::text, kcal_high::text, protein_low::text, protein_high::text, carb_low::text, carb_high::text,
        fat_low::text, fat_high::text, fibre_known_low::text, fibre_known_high::text, fibre_unknown_items, item_count
      from daily_nutrition where user_id in ${sql(ids)} order by user_id, local_date`;
    return { prs: [...prs], flags: [...flags], volume: [...volume], nutrition: [...nutrition] };
  }

  it('reproduces exercise_prs (+ is_pr), muscle_volume_weekly and daily_nutrition exactly; restores a corrupted cache; idempotent', async () => {
    await history(1);
    await history(2);
    const live = await caches();
    expect(live.prs.length).toBeGreaterThan(0);
    expect(live.volume.length).toBeGreaterThan(0);
    expect(live.nutrition.length).toBeGreaterThan(0);
    expect(new Set(live.volume.map((v) => v['iso_week'])).size).toBeGreaterThan(1);

    const first = await rebuildDerivedOn(handle.db);
    expect(await caches()).toEqual(live);
    expect(first.prs).toBeGreaterThanOrEqual(live.prs.length);

    // Corrupt all three, then rebuild: the source rows decide.
    await sql`delete from exercise_prs where user_id = ${ids[0]!}`;
    await sql`update set_logs set is_pr = false`;
    await sql`update muscle_volume_weekly set hard_sets = 99 where user_id = ${ids[1]!}`;
    await sql`insert into muscle_volume_weekly (user_id, iso_week, muscle_group, hard_sets, tonnage_kg) values (${ids[0]!}, '2020-W01', 'chest', 5, 100)`;
    await sql`update daily_nutrition set kcal_low = 1 where user_id = ${ids[0]!}`;
    await rebuildDerivedOn(handle.db);
    expect(await caches()).toEqual(live);

    // Idempotent: a second run changes nothing.
    await rebuildDerivedOn(handle.db);
    expect(await caches()).toEqual(live);
  });
});
