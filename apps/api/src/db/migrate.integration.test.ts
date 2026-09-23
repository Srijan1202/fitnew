/**
 * Migrations verified in BOTH directions against a real Postgres (rule 17,
 * §26.1). Skipped without DATABASE_URL; CI always sets it.
 *
 * Runs in its own schema-free way: it rolls everything back first so it starts
 * from a clean state regardless of what a previous run left behind, and it
 * leaves the database fully migrated so the health integration test and any
 * later suite find the schema present.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { migrateUp, rollbackLastMigration } from './migrate.js';

// Never the developer's database: the suite below drops every table (src/test/test-database.ts).
const url = process.env['TEST_DATABASE_URL'];
const describeIfDb = url !== undefined && url !== '' ? describe : describe.skip;

async function tableExists(client: postgres.Sql, name: string): Promise<boolean> {
  const rows = await client<{ exists: boolean }[]>`
    select exists (
      select 1 from information_schema.tables
      where table_schema = 'public' and table_name = ${name}
    ) as exists
  `;
  return rows[0]?.exists ?? false;
}

/** Enum labels by type NAME (not a cached OID — the type may have been rebuilt). */
async function enumLabels(client: postgres.Sql, typname: string): Promise<string[]> {
  const rows = await client<{ v: string }[]>`
    select e.enumlabel as v from pg_enum e join pg_type t on t.oid = e.enumtypid
    where t.typname = ${typname} order by e.enumsortorder`;
  return rows.map((r) => r.v);
}

async function appliedCount(client: postgres.Sql): Promise<number> {
  const rows = await client<{ count: string }[]>`
    select count(*)::text as count from drizzle.__drizzle_migrations
  `.catch(() => [{ count: '0' }]);
  return Number(rows[0]?.count ?? 0);
}

describeIfDb('migrations (real Postgres)', () => {
  const connectionString = url as string;
  let client: postgres.Sql;

  beforeAll(async () => {
    client = postgres(connectionString, { max: 1 });
    // Start clean whatever state the database is in.
    while ((await rollbackLastMigration(connectionString)) !== null) {
      /* keep rolling back */
    }
  });

  afterAll(async () => {
    // Leave the schema present for everything that runs after us.
    await migrateUp(connectionString);
    await client.end({ timeout: 5 });
  });

  const PHASE2_TABLES = [
    'user_profiles', 'user_goals', 'user_preferences', 'diet_preferences',
    'user_allergies', 'user_limitations', 'consent_records', 'nutrition_targets',
    'body_metrics',
  ];
  const PHASE3_TABLES = [
    'exercises', 'exercise_muscles', 'exercise_alternatives', 'exercise_contraindications',
  ];
  const PHASE4_TABLES = ['programs', 'program_days', 'planned_exercises'];
  const PHASE5_TABLES = ['workout_sessions', 'session_exercises', 'set_logs', 'exercise_prs'];
  const PHASE6_TABLES = ['muscle_volume_weekly', 'exercise_rejections'];
  const TOTAL_MIGRATIONS = 10;

  it('starts from nothing', async () => {
    expect(await tableExists(client, 'users')).toBe(false);
    expect(await appliedCount(client)).toBe(0);
  });

  it('up creates users with the §9.1 conventions', async () => {
    await migrateUp(connectionString);
    expect(await tableExists(client, 'users')).toBe(true);
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);

    const cols = await client<{ column_name: string; data_type: string; is_nullable: string }[]>`
      select column_name, data_type, is_nullable
      from information_schema.columns
      where table_name = 'users'
      order by ordinal_position
    `;
    const byName = new Map(cols.map((c) => [c.column_name, c]));

    expect(byName.get('id')?.data_type).toBe('uuid');
    expect(byName.get('firebase_uid')?.is_nullable).toBe('NO');
    expect(byName.get('timezone')?.is_nullable).toBe('NO');
    expect(byName.get('created_at')?.data_type).toBe('timestamp with time zone');
    expect(byName.get('deleted_at')?.is_nullable).toBe('YES');
    // No credential columns, ever (§11).
    expect(byName.has('password')).toBe(false);
    expect(byName.has('password_hash')).toBe(false);
  });

  it('up creates every Phase 2 table and enum type', async () => {
    for (const t of PHASE2_TABLES) expect(await tableExists(client, t), t).toBe(true);
    const types = await client<{ typname: string }[]>`
      select typname from pg_type where typtype = 'e' order by typname
    `;
    expect(types.map((t) => t.typname)).toEqual(
      expect.arrayContaining(['goal_type', 'sex', 'diet_type', 'allergen', 'consent_type', 'onboarding_stage']),
    );
  });

  it('up creates the Phase 3 exercise library with its integrity rules', async () => {
    for (const t of PHASE3_TABLES) expect(await tableExists(client, t), t).toBe(true);
    // An exercise with no equipment is rejected by the table, not just by Zod.
    await expect(
      client`insert into exercises (slug, name, movement_pattern, equipment, difficulty, default_increment_kg, instructions)
             values ('mig-x', 'X', 'squat', '{}', 'beginner', 2.5, '{"a"}')`,
    ).rejects.toThrow(/exercises_equipment_nonempty/);
    // A muscle cannot be both primary and secondary for one exercise.
    const [x] = await client<{ id: string }[]>`
      insert into exercises (slug, name, movement_pattern, equipment, difficulty, default_increment_kg, instructions)
      values ('mig-x', 'X', 'squat', '{barbell}', 'beginner', 2.5, '{"a"}') returning id`;
    await client`insert into exercise_muscles values (${x!.id}, 'quads', 'primary', 1)`;
    await expect(
      client`insert into exercise_muscles values (${x!.id}, 'quads', 'secondary', 0.5)`,
    ).rejects.toThrow(/exercise_muscles_exercise_id_muscle_group_pk/);
    // An exercise cannot be its own alternative.
    await expect(
      client`insert into exercise_alternatives values (${x!.id}, ${x!.id}, 'preference')`,
    ).rejects.toThrow(/exercise_alternatives_not_self/);
    // Deleting an exercise cascades through its rows.
    await client`insert into exercise_contraindications values (${x!.id}, 'knee')`;
    await client`delete from exercises where id = ${x!.id}`;
    expect((await client`select 1 from exercise_muscles where exercise_id = ${x!.id}`).length).toBe(0);
    expect((await client`select 1 from exercise_contraindications where exercise_id = ${x!.id}`).length).toBe(0);
  });

  it('up creates the Phase 4 programme tables; one active programme per user is a database fact', async () => {
    for (const t of PHASE4_TABLES) expect(await tableExists(client, t), t).toBe(true);
    await client`insert into users (firebase_uid) values ('mig-prog')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-prog'`;
    await client`insert into programs (user_id, name, split_type, days_per_week, source) values (${u!.id}, 'A', 'full-body', 3, 'generated')`;
    await expect(
      client`insert into programs (user_id, name, split_type, days_per_week, source) values (${u!.id}, 'B', 'custom', 2, 'custom')`,
    ).rejects.toThrow(/one_active_program/);
    // Deactivating (or soft-deleting) the first frees the slot.
    await client`update programs set active = false where user_id = ${u!.id}`;
    await client`insert into programs (user_id, name, split_type, days_per_week, source) values (${u!.id}, 'B', 'custom', 2, 'custom')`;
    // Days per week outside 2–6 and an inverted rep range are rejected by the table.
    await expect(
      client`insert into programs (user_id, name, split_type, days_per_week, source, active) values (${u!.id}, 'C', 'custom', 7, 'custom', false)`,
    ).rejects.toThrow(/programs_days_range/);
    const [p] = await client<{ id: string }[]>`select id from programs where user_id = ${u!.id} and active`;
    const [d] = await client<{ id: string }[]>`insert into program_days (program_id, day_of_week, session_name) values (${p!.id}, 1, 'A') returning id`;
    const [x] = await client<{ id: string }[]>`select id from exercises limit 1`;
    if (x !== undefined) {
      await expect(
        client`insert into planned_exercises (program_day_id, exercise_id, order_index, set_count, rep_min, rep_max, target_rir, increment_kg) values (${d!.id}, ${x.id}, 0, 3, 12, 6, 2, 2.5)`,
      ).rejects.toThrow(/planned_exercises_reps_ordered/);
    }
    await client`delete from users where firebase_uid = 'mig-prog'`;
    expect((await client`select 1 from programs where user_id = ${u!.id}`).length).toBe(0);
  });

  it('0004: planned_sets with its CHECKs, template source and split values, template_slug', async () => {
    expect(await tableExists(client, 'planned_sets')).toBe(true);
    expect(await enumLabels(client, 'program_source')).toEqual(['generated', 'template', 'custom']);
    const splits = await enumLabels(client, 'split_type');
    expect(splits).toContain('bro-split');
    expect(splits).toContain('push-pull-legs-6');

    await client`insert into users (firebase_uid) values ('mig-sets')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-sets'`;
    const [p] = await client<{ id: string }[]>`
      insert into programs (user_id, name, split_type, days_per_week, source, template_slug)
      values (${u!.id}, 'T', 'bro-split', 5, 'template', 'bro-split') returning id`;
    const [d] = await client<{ id: string }[]>`insert into program_days (program_id, day_of_week, session_name) values (${p!.id}, 1, 'Chest') returning id`;
    const [x] = await client<{ id: string }[]>`select id from exercises limit 1`;
    if (x !== undefined) {
      const [pe] = await client<{ id: string }[]>`
        insert into planned_exercises (program_day_id, exercise_id, order_index, set_count, rep_min, rep_max, target_rir, increment_kg)
        values (${d!.id}, ${x.id}, 0, 3, 6, 12, 2, 2.5) returning id`;
      await client`insert into planned_sets (planned_exercise_id, set_index, reps_min, reps_max, weight_kg, rir) values (${pe!.id}, 1, 10, 10, 40, 2)`;
      await client`insert into planned_sets (planned_exercise_id, set_index, reps_min, reps_max, weight_kg, rir) values (${pe!.id}, 2, 6, 12, null, 2)`;
      // Same set index twice, inverted reps, negative weight: all rejected by the table.
      await expect(
        client`insert into planned_sets (planned_exercise_id, set_index, reps_min, reps_max, weight_kg, rir) values (${pe!.id}, 1, 8, 8, 40, 2)`,
      ).rejects.toThrow(/planned_sets_exercise_index/);
      await expect(
        client`insert into planned_sets (planned_exercise_id, set_index, reps_min, reps_max, weight_kg, rir) values (${pe!.id}, 3, 12, 6, 40, 2)`,
      ).rejects.toThrow(/planned_sets_reps_ordered/);
      await expect(
        client`insert into planned_sets (planned_exercise_id, set_index, reps_min, reps_max, weight_kg, rir) values (${pe!.id}, 3, 8, 8, -1, 2)`,
      ).rejects.toThrow(/planned_sets_weight_nonnegative/);
      // Deleting the exercise cascades to its sets.
      await client`delete from planned_exercises where id = ${pe!.id}`;
      expect((await client`select 1 from planned_sets where planned_exercise_id = ${pe!.id}`).length).toBe(0);
    }
    await client`delete from users where firebase_uid = 'mig-sets'`;
  });

  it('0005: exercise_muscles.position exists, defaults to 0, and orders a read back the way it was written', async () => {
    const cols = await client<{ column_name: string; column_default: string | null }[]>`
      select column_name, column_default from information_schema.columns
      where table_name = 'exercise_muscles' and column_name = 'position'`;
    expect(cols).toHaveLength(1);
    expect(cols[0]!.column_default).toBe('0');
    const [x] = await client<{ id: string }[]>`select id from exercises limit 1`;
    if (x !== undefined) {
      await client`delete from exercise_muscles where exercise_id = ${x.id}`;
      // Written triceps-first (as the seed lists close-grip bench), read back the same.
      await client`insert into exercise_muscles (exercise_id, muscle_group, role, contribution, position) values (${x.id}, 'triceps', 'primary', 1, 0)`;
      await client`insert into exercise_muscles (exercise_id, muscle_group, role, contribution, position) values (${x.id}, 'chest', 'primary', 1, 1)`;
      const rows = await client<{ muscle_group: string }[]>`
        select muscle_group from exercise_muscles where exercise_id = ${x.id} and role = 'primary' order by position, muscle_group`;
      expect(rows.map((r) => r.muscle_group)).toEqual(['triceps', 'chest']);
      await client`delete from exercise_muscles where exercise_id = ${x.id}`;
    }
  });

  it('0006: logging tables, one active session per user, client ids unique, set CHECKs, cascades', async () => {
    for (const t of PHASE5_TABLES) expect(await tableExists(client, t), t).toBe(true);
    expect(await enumLabels(client, 'set_type')).toEqual(['warmup', 'working', 'drop', 'backoff']);
    expect(await enumLabels(client, 'session_status')).toEqual(['active', 'completed', 'abandoned']);
    expect(await enumLabels(client, 'pr_type')).toEqual(['1rm_est', 'weight', 'reps', 'volume']);

    await client`insert into users (firebase_uid) values ('mig-log')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-log'`;
    const cs1 = '10000000-0000-4000-8000-000000000001';
    const cs2 = '10000000-0000-4000-8000-000000000002';
    const [s1] = await client<{ id: string }[]>`
      insert into workout_sessions (user_id, name, started_at, client_session_id)
      values (${u!.id}, 'Push', now(), ${cs1}) returning id`;
    // A second ACTIVE session for the same user is refused by the database.
    await expect(
      client`insert into workout_sessions (user_id, name, started_at, client_session_id) values (${u!.id}, 'Pull', now(), ${cs2})`,
    ).rejects.toThrow(/one_active_session/);
    // The same client id twice is refused (offline replay is a no-op).
    await expect(
      client`insert into workout_sessions (user_id, name, status, started_at, client_session_id) values (${u!.id}, 'Pull', 'completed', now(), ${cs1})`,
    ).rejects.toThrow(/workout_sessions_client_id/);
    // Once completed, a new active one is fine.
    await client`update workout_sessions set status = 'completed', completed_at = now() where id = ${s1!.id}`;
    await client`insert into workout_sessions (user_id, name, started_at, client_session_id) values (${u!.id}, 'Pull', now(), ${cs2})`;

    const [x] = await client<{ id: string }[]>`select id from exercises limit 1`;
    if (x !== undefined) {
      const ce = '20000000-0000-4000-8000-000000000001';
      const [se] = await client<{ id: string }[]>`
        insert into session_exercises (session_id, exercise_id, order_index, client_exercise_id)
        values (${s1!.id}, ${x.id}, 0, ${ce}) returning id`;
      const set1 = '30000000-0000-4000-8000-000000000001';
      await client`insert into set_logs (session_exercise_id, set_index, weight_kg, reps, rir, logged_at, client_set_id) values (${se!.id}, 1, 60, 10, 2, now(), ${set1})`;
      // Replay: same client id → refused; same position while live → refused.
      await expect(
        client`insert into set_logs (session_exercise_id, set_index, weight_kg, reps, rir, logged_at, client_set_id) values (${se!.id}, 2, 60, 10, 2, now(), ${set1})`,
      ).rejects.toThrow(/set_logs_client_id/);
      await expect(
        client`insert into set_logs (session_exercise_id, set_index, weight_kg, reps, rir, logged_at, client_set_id) values (${se!.id}, 1, 60, 10, 2, now(), '30000000-0000-4000-8000-000000000002')`,
      ).rejects.toThrow(/set_logs_live_position/);
      // A soft-deleted row frees its position.
      await client`update set_logs set deleted_at = now() where client_set_id = ${set1}`;
      await client`insert into set_logs (session_exercise_id, set_index, weight_kg, reps, rir, logged_at, client_set_id) values (${se!.id}, 1, 60, 10, 2, now(), '30000000-0000-4000-8000-000000000002')`;
      // CHECKs.
      await expect(
        client`insert into set_logs (session_exercise_id, set_index, weight_kg, reps, rir, logged_at, client_set_id) values (${se!.id}, 3, 60, 10, 6, now(), '30000000-0000-4000-8000-000000000003')`,
      ).rejects.toThrow(/set_logs_rir_range/);
      await expect(
        client`insert into set_logs (session_exercise_id, set_index, weight_kg, reps, rir, logged_at, client_set_id) values (${se!.id}, 3, -1, 10, 2, now(), '30000000-0000-4000-8000-000000000003')`,
      ).rejects.toThrow(/set_logs_weight_nonnegative/);
      // A record row, then the session goes: sets and records cascade with it.
      const [live] = await client<{ id: string }[]>`select id from set_logs where session_exercise_id = ${se!.id} and deleted_at is null`;
      await client`insert into exercise_prs (user_id, exercise_id, pr_type, value, previous, reason, achieved_at, set_log_id) values (${u!.id}, ${x.id}, 'weight', 60, 55, 'r', now(), ${live!.id})`;
      await client`delete from workout_sessions where id = ${s1!.id}`;
      expect((await client`select 1 from set_logs where session_exercise_id = ${se!.id}`).length).toBe(0);
      expect((await client`select 1 from exercise_prs where user_id = ${u!.id}`).length).toBe(0);
    }
    await client`delete from users where firebase_uid = 'mig-log'`;
  });

  it('0007: volume cache keyed per user/week/muscle, rejections, programme deload columns', async () => {
    for (const t of PHASE6_TABLES) expect(await tableExists(client, t), t).toBe(true);
    const cols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'programs'`;
    for (const c of ['deload_started_at', 'deload_snoozed_until', 'mesocycle_reset_at']) {
      expect(cols.map((x) => x.column_name)).toContain(c);
    }
    await client`insert into users (firebase_uid) values ('mig-vol')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-vol'`;
    await client`insert into muscle_volume_weekly (user_id, iso_week, muscle_group, hard_sets, tonnage_kg) values (${u!.id}, '2026-W39', 'chest', 12.5, 3400)`;
    // Same key twice is refused: one row per user, week and muscle.
    await expect(
      client`insert into muscle_volume_weekly (user_id, iso_week, muscle_group, hard_sets, tonnage_kg) values (${u!.id}, '2026-W39', 'chest', 1, 1)`,
    ).rejects.toThrow(/muscle_volume_weekly/);
    await client`delete from users where firebase_uid = 'mig-vol'`;
    expect((await client`select 1 from muscle_volume_weekly where user_id = ${u!.id}`).length).toBe(0);
  });

  it('0008: users.display_name, nullable, the canonical display name (Phase 6.6)', async () => {
    const cols = await client<{ column_name: string; is_nullable: string }[]>`
      select column_name, is_nullable from information_schema.columns where table_name = 'users' and column_name = 'display_name'`;
    expect(cols).toHaveLength(1);
    expect(cols[0]!.is_nullable).toBe('YES');
    await client`insert into users (firebase_uid, display_name) values ('mig-name', 'Srijan')`;
    const [u] = await client<{ display_name: string }[]>`select display_name from users where firebase_uid = 'mig-name'`;
    expect(u!.display_name).toBe('Srijan');
    await client`delete from users where firebase_uid = 'mig-name'`;
  });

  it('0009: food library — ranges enforced, fibre both-or-neither, ownership follows source, estimates never verified, aliases normalised, cascades (Phase 7)', async () => {
    for (const t of ['foods', 'food_nutrition', 'food_aliases']) expect(await tableExists(client, t), t).toBe(true);
    const [g] = await client<{ id: string; search_name: string }[]>`
      insert into foods (slug, name, source, source_ref, is_verified) values ('mig-dal', 'Dal (Tadka)!', 'estimated', 'test', false)
      returning id, search_name`;
    expect(g!.search_name).toBe('dal tadka');
    const row = (over: string) => client.unsafe(
      `insert into food_nutrition (food_id, position, basis, serving_label, serving_grams, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, fibre_low, fibre_high, confidence)
       values ('${g!.id}', ${over})`,
    );
    await row(`0, 'per_serving', '1 katori', 150, 120, 185, 6, 9, 16, 23, 3, 7, null, null, 'medium'`);
    await expect(row(`1, 'per_serving', 'x1', 150, 200, 100, 6, 9, 16, 23, 3, 7, null, null, 'medium'`)).rejects.toThrow(/kcal_range/);
    await expect(row(`2, 'per_serving', 'x2', 150, 100, 120, 6, 9, 16, 23, 3, 7, 2, null, 'medium'`)).rejects.toThrow(/fibre_range/);
    await expect(row(`3, 'per_serving', 'x3', 150, 100, 120, 6, 9, 16, 23, 3, 7, 3, 1, 'medium'`)).rejects.toThrow(/fibre_range/);
    await expect(row(`4, 'per_serving', 'x4', 150, -1, 120, 6, 9, 16, 23, 3, 7, null, null, 'medium'`)).rejects.toThrow(/nonnegative/);
    await expect(client`update foods set is_verified = true where id = ${g!.id}`).rejects.toThrow(/unverified_sources/);
    await expect(client`insert into foods (slug, name, source, client_food_id) values ('mig-u', 'X', 'user', gen_random_uuid())`).rejects.toThrow(/owner_matches_source/);
    await expect(client`insert into food_aliases (food_id, alias) values (${g!.id}, 'Dhal')`).rejects.toThrow(/normalised/);
    await client`insert into food_aliases (food_id, alias) values (${g!.id}, 'dhal')`;

    await client`insert into users (firebase_uid) values ('mig-food')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-food'`;
    await expect(client`insert into foods (slug, name, source, owner_user_id) values ('mig-c0', 'Bar', 'user', ${u!.id})`).rejects.toThrow(/client_id_custom_only/);
    await client`insert into foods (slug, name, source, owner_user_id, client_food_id) values ('mig-c1', 'Bar', 'user', ${u!.id}, '11111111-1111-4111-8111-111111111111')`;
    await expect(
      client`insert into foods (slug, name, source, owner_user_id, client_food_id) values ('mig-c2', 'Bar', 'user', ${u!.id}, '11111111-1111-4111-8111-111111111111')`,
    ).rejects.toThrow(/foods_owner_client_idx/);
    await client`delete from users where id = ${u!.id}`;
    expect((await client`select 1 from foods where slug = 'mig-c1'`).length).toBe(0);
    await client`delete from foods where id = ${g!.id}`;
    expect((await client`select 1 from food_nutrition where food_id = ${g!.id}`).length).toBe(0);
    expect((await client`select 1 from food_aliases where food_id = ${g!.id}`).length).toBe(0);
  });

  it('one active goal per user is a database fact', async () => {
    await client`insert into users (firebase_uid) values ('mig-goal')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-goal'`;
    await client`insert into user_goals (user_id, goal_type) values (${u!.id}, 'fat-loss')`;
    await expect(
      client`insert into user_goals (user_id, goal_type) values (${u!.id}, 'muscle-gain')`,
    ).rejects.toThrow(/one_active_goal/);
    // Closing the first makes room for a second.
    await client`update user_goals set ended_at = now() where user_id = ${u!.id}`;
    await client`insert into user_goals (user_id, goal_type) values (${u!.id}, 'muscle-gain')`;
    await client`delete from users where firebase_uid = 'mig-goal'`; // cascades
  });

  it('the goal enum rejects values the contract does not know', async () => {
    await client`insert into users (firebase_uid) values ('mig-enum')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-enum'`;
    await expect(
      client`insert into user_goals (user_id, goal_type) values (${u!.id}, 'bulk')`,
    ).rejects.toThrow(/invalid input value for enum goal_type/);
    await client`delete from users where firebase_uid = 'mig-enum'`;
  });

  it('deleting a user cascades through every Phase 2 table', async () => {
    await client`insert into users (firebase_uid) values ('mig-cascade')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-cascade'`;
    const id = u!.id;
    await client`insert into user_profiles (user_id) values (${id})`;
    await client`insert into user_goals (user_id, goal_type) values (${id}, 'general')`;
    await client`insert into diet_preferences (user_id, diet_type) values (${id}, 'vegetarian')`;
    await client`insert into user_allergies (user_id, allergen, severity) values (${id}, 'peanut', 'severe')`;
    await client`insert into consent_records (user_id, consent_type, granted, policy_version) values (${id}, 'privacy-policy', true, 'v')`;
    await client`insert into body_metrics (user_id, measured_on, weight_kg, source) values (${id}, '2026-09-21', 70, 'onboarding')`;

    await client`delete from users where id = ${id}`;

    for (const t of ['user_profiles', 'user_goals', 'diet_preferences', 'user_allergies', 'consent_records', 'body_metrics']) {
      const rows = await client.unsafe(`select count(*)::int as n from ${t} where user_id = '${id}'`);
      expect(rows[0]?.['n'], t).toBe(0);
    }
  });

  it('up is idempotent — running it again applies nothing', async () => {
    await migrateUp(connectionString);
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);
  });

  it('firebase_uid is unique at the database level, not just in code', async () => {
    await client`insert into users (firebase_uid) values ('uid-dup')`;
    await expect(client`insert into users (firebase_uid) values ('uid-dup')`).rejects.toThrow(
      /unique/i,
    );
    await client`delete from users where firebase_uid = 'uid-dup'`;
  });

  it('down removes 0009, 0008, 0007, 0006, 0005, then 0004 (rebuilding the enums), then Phase 4, 3, 2, one migration at a time', async () => {
    expect(await rollbackLastMigration(connectionString)).toBe('0009_food_library');
    for (const t of ['foods', 'food_nutrition', 'food_aliases']) expect(await tableExists(client, t), t).toBe(false);
    const foodEnums = await client<{ typname: string }[]>`
      select typname from pg_type where typname in ('food_source', 'nutrition_basis', 'nutrition_confidence')`;
    expect(foodEnums).toHaveLength(0);
    expect(await appliedCount(client)).toBe(9);

    expect(await rollbackLastMigration(connectionString)).toBe('0008_display_name');
    const ucols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'users'`;
    expect(ucols.map((c) => c.column_name)).not.toContain('display_name');
    expect(await appliedCount(client)).toBe(8);

    expect(await rollbackLastMigration(connectionString)).toBe('0007_progression_volume');
    for (const t of PHASE6_TABLES) expect(await tableExists(client, t), t).toBe(false);
    const pcols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'programs'`;
    expect(pcols.map((c) => c.column_name)).not.toContain('deload_started_at');
    expect(await appliedCount(client)).toBe(7);

    expect(await rollbackLastMigration(connectionString)).toBe('0006_workout_logging');
    for (const t of PHASE5_TABLES) expect(await tableExists(client, t), t).toBe(false);
    const types6 = await client<{ typname: string }[]>`select typname from pg_type where typtype = 'e'`;
    expect(types6.map((t) => t.typname)).not.toContain('set_type');
    expect(await appliedCount(client)).toBe(6);

    expect(await rollbackLastMigration(connectionString)).toBe('0005_exercise_muscle_position');
    const emCols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'exercise_muscles'`;
    expect(emCols.map((c) => c.column_name)).not.toContain('position');
    expect(await appliedCount(client)).toBe(5);

    expect(await rollbackLastMigration(connectionString)).toBe('0004_planned_sets_templates');
    expect(await tableExists(client, 'planned_sets')).toBe(false);
    expect(await enumLabels(client, 'program_source')).toEqual(['generated', 'custom']);
    const cols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'programs'`;
    expect(cols.map((c) => c.column_name)).not.toContain('template_slug');
    expect(await appliedCount(client)).toBe(4);

    expect(await rollbackLastMigration(connectionString)).toBe('0003_programs');
    for (const t of PHASE4_TABLES) expect(await tableExists(client, t), t).toBe(false);
    expect(await appliedCount(client)).toBe(3);

    expect(await rollbackLastMigration(connectionString)).toBe('0002_exercise_library');
    for (const t of PHASE3_TABLES) expect(await tableExists(client, t), t).toBe(false);
    const types3 = await client<{ typname: string }[]>`select typname from pg_type where typtype = 'e'`;
    expect(types3.map((t) => t.typname)).not.toContain('muscle_group');
    expect(types3.map((t) => t.typname)).toContain('body_part'); // 0001 still applied
    expect(await appliedCount(client)).toBe(2);

    expect(await rollbackLastMigration(connectionString)).toBe('0001_profile_goals_targets');
    for (const t of PHASE2_TABLES) expect(await tableExists(client, t), t).toBe(false);
    const types = await client<{ typname: string }[]>`select typname from pg_type where typtype = 'e'`;
    expect(types.map((t) => t.typname)).not.toContain('goal_type');
    expect(await tableExists(client, 'users')).toBe(true); // 0000 still applied
    expect(await appliedCount(client)).toBe(1);

    expect(await rollbackLastMigration(connectionString)).toBe('0000_users');
    expect(await tableExists(client, 'users')).toBe(false);
    expect(await appliedCount(client)).toBe(0);
  });

  it('down on an empty journal is a no-op, not an error', async () => {
    expect(await rollbackLastMigration(connectionString)).toBeNull();
  });

  it('up after down genuinely re-applies everything', async () => {
    await migrateUp(connectionString);
    expect(await tableExists(client, 'users')).toBe(true);
    for (const t of PHASE2_TABLES) expect(await tableExists(client, t), t).toBe(true);
    for (const t of PHASE3_TABLES) expect(await tableExists(client, t), t).toBe(true);
    for (const t of PHASE4_TABLES) expect(await tableExists(client, t), t).toBe(true);
    expect(await tableExists(client, 'planned_sets')).toBe(true);
    for (const t of PHASE5_TABLES) expect(await tableExists(client, t), t).toBe(true);
    for (const t of PHASE6_TABLES) expect(await tableExists(client, t), t).toBe(true);
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);
  });
});
