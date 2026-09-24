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
  const TOTAL_MIGRATIONS = 14;

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

  it('0010: food logging — snapshot ranges and both-or-neither fibre, per-user client ids, soft delete, no target copies, cascades (Phase 8)', async () => {
    for (const t of ['food_logs', 'food_log_items', 'daily_nutrition', 'saved_meals']) expect(await tableExists(client, t), t).toBe(true);
    await client`insert into users (firebase_uid) values ('mig-log-a'), ('mig-log-b')`;
    const [a] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-log-a'`;
    const [b] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-log-b'`;
    const cid = '22222222-2222-4222-8222-222222222222';
    const [log] = await client<{ id: string }[]>`
      insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method)
      values (${a!.id}, ${cid}, now(), '2026-09-24', 'lunch', 'search') returning id`;
    // Unique per user (owner J12): the same client id is fine for another user, not twice for one.
    await client`insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method) values (${b!.id}, ${cid}, now(), '2026-09-24', 'lunch', 'search')`;
    await expect(
      client`insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method) values (${a!.id}, ${cid}, now(), '2026-09-24', 'lunch', 'search')`,
    ).rejects.toThrow(/food_logs_user_client_id/);
    await expect(
      client`insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method) values (${a!.id}, gen_random_uuid(), now(), '24-09-2026', 'lunch', 'search')`,
    ).rejects.toThrow(/local_date_format/);
    await expect(
      client`insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method) values (${a!.id}, gen_random_uuid(), now(), '2026-09-24', 'brunch', 'search')`,
    ).rejects.toThrow(/invalid input value for enum/);
    const item = (over: string) => client.unsafe(
      `insert into food_log_items (food_log_id, position, food_name, food_source, basis, serving_label, servings, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, fibre_low, fibre_high, confidence)
       values ('${log!.id}', ${over})`,
    );
    await item(`0, 'Dal', 'estimated', 'per_serving', '1 katori', 1.5, 180, 278, 9, 13.5, 24, 34.5, 4.5, 11.3, null, null, 'medium'`);
    await item(`1, 'Quick add', 'user', null, null, 1, 250, 250, 12, 12, 30, 30, 9, 9, 2, 2, 'medium'`);
    await expect(item(`2, 'X', 'user', null, null, 1, 300, 250, 1, 1, 1, 1, 1, 1, null, null, 'medium'`)).rejects.toThrow(/kcal_range/);
    await expect(item(`3, 'X', 'user', null, null, 1, 250, 250, 1, 1, 1, 1, 1, 1, 2, null, 'medium'`)).rejects.toThrow(/fibre_range/);
    await expect(item(`4, 'X', 'user', null, null, 0, 250, 250, 1, 1, 1, 1, 1, 1, null, null, 'medium'`)).rejects.toThrow(/servings_positive/);
    await expect(item(`5, 'X', 'user', 'per_serving', null, 1, 250, 250, 1, 1, 1, 1, 1, 1, null, null, 'medium'`)).rejects.toThrow(/row_both_or_neither/);
    await expect(item(`6, ' ', 'user', null, null, 1, 250, 250, 1, 1, 1, 1, 1, 1, null, null, 'medium'`)).rejects.toThrow(/name_nonempty/);
    await expect(item(`1, 'Dup', 'user', null, null, 1, 1, 1, 1, 1, 1, 1, 1, 1, null, null, 'medium'`)).rejects.toThrow(/food_log_items_log_position/);
    // A saved meal: named, non-empty; only a saved-meal log may point at one.
    await expect(client`insert into saved_meals (user_id, client_meal_id, name, items) values (${a!.id}, gen_random_uuid(), 'M', '[]'::jsonb)`).rejects.toThrow(/items_nonempty/);
    const [meal] = await client<{ id: string }[]>`insert into saved_meals (user_id, client_meal_id, name, items) values (${a!.id}, gen_random_uuid(), 'M', '[{"kind":"quick-add"}]'::jsonb) returning id`;
    await expect(client`update food_logs set saved_meal_id = ${meal!.id} where id = ${log!.id}`).rejects.toThrow(/saved_meal_method/);
    // daily_nutrition: counts sane; no target columns (owner J2).
    await expect(client`insert into daily_nutrition (user_id, local_date, fibre_unknown_items, item_count) values (${a!.id}, '2026-09-24', 2, 1)`).rejects.toThrow(/daily_nutrition_counts/);
    const cols = await client<{ column_name: string }[]>`select column_name from information_schema.columns where table_name = 'daily_nutrition'`;
    expect(cols.map((c) => c.column_name).filter((c) => c.includes('target'))).toEqual([]);
    // Soft delete keeps the row and its items.
    await client`update food_logs set deleted_at = now() where id = ${log!.id}`;
    expect((await client`select 1 from food_log_items where food_log_id = ${log!.id}`).length).toBe(2);
    // Cascades: the user takes logs, items, days and meals with them.
    await client`insert into daily_nutrition (user_id, local_date) values (${a!.id}, '2026-09-24')`;
    await client`delete from users where id in (${a!.id}, ${b!.id})`;
    for (const t of ['food_logs', 'saved_meals', 'daily_nutrition']) {
      expect((await client.unsafe(`select 1 from ${t} where user_id in ('${a!.id}', '${b!.id}')`)).length, t).toBe(0);
    }
    expect((await client`select 1 from food_log_items where food_log_id = ${log!.id}`).length).toBe(0);
  });

  it('0011: VIT mess: providers, messes, deduped snapshots, the medium cap, pending corrections, mess logs (Phase 9)', async () => {
    for (const t of ['mess_providers', 'messes', 'mess_menu_snapshots', 'mess_dish_nutrition', 'mess_dish_corrections']) {
      expect(await tableExists(client, t), t).toBe(true);
    }
    // Owner D2: no derived day/meal/dish tables.
    for (const t of ['mess_days', 'mess_meals', 'mess_dishes']) expect(await tableExists(client, t), t).toBe(false);
    expect(await enumLabels(client, 'food_entry_method')).toEqual(['search', 'quick-add', 'saved-meal', 'mess']);

    const [prov] = await client<{ id: string }[]>`insert into mess_providers (slug, display_name) values ('mig-prov', 'Mig') returning id`;
    const [mess] = await client<{ id: string }[]>`
      insert into messes (provider_id, code, hostel_id, hostel_label, mess_id, mess_label, serves_non_veg, source_url)
      values (${prov!.id}, 'mig-veg', 'mig', 'Mig', 'veg', 'Veg', false, 'https://example.invalid/hostel-9-mess-9.json') returning id`;
    await expect(
      client`insert into messes (provider_id, code, hostel_id, hostel_label, mess_id, mess_label, serves_non_veg, source_url)
             values (${prov!.id}, 'Mig Veg', 'mig', 'M', 'other', 'O', false, 'x')`,
    ).rejects.toThrow(/messes_code_format/);
    await expect(client`update messes set last_error = 'teapot' where id = ${mess!.id}`).rejects.toThrow(/messes_last_error/);

    // Snapshots: one row per (mess, payload hash) (owner D3).
    const hash = 'a'.repeat(64);
    await client`insert into mess_menu_snapshots (mess_id, raw_payload, payload_hash, dates) values (${mess!.id}, '{}'::jsonb, ${hash}, array['2026-09-24'])`;
    await expect(
      client`insert into mess_menu_snapshots (mess_id, raw_payload, payload_hash, dates) values (${mess!.id}, '{}'::jsonb, ${hash}, array['2026-09-24'])`,
    ).rejects.toThrow(/mess_menu_snapshots_mess_hash/);
    await expect(
      client`insert into mess_menu_snapshots (mess_id, raw_payload, payload_hash, dates) values (${mess!.id}, '{}'::jsonb, 'nothex', array['2026-09-24'])`,
    ).rejects.toThrow(/hash_format/);

    // The medium cap is structural (owner): the database refuses high confidence and non-estimates.
    const dish = (slug: string, confidence: string, source = 'estimated') => client.unsafe(
      `insert into mess_dish_nutrition (dish_slug, name, serving_label, serving_grams, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, confidence, source)
       values ('${slug}', 'Dal', '1 katori', 150, 120, 185, 6, 9, 16, 23, 3, 7, '${confidence}', '${source}')`,
    );
    await dish('mig-dal', 'medium');
    await expect(dish('mig-rice', 'high')).rejects.toThrow(/confidence_cap/);
    await expect(dish('mig-rice', 'low', 'usda')).rejects.toThrow(/mess_dish_nutrition_source/);
    await expect(dish('Mig Rice', 'low')).rejects.toThrow(/slug_format/);

    // Corrections: pending by default, retry-safe per user, a value that fits the field.
    await client`insert into users (firebase_uid) values ('mig-mess-a')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-mess-a'`;
    const ccid = '33333333-3333-4333-8333-333333333333';
    await client`insert into mess_dish_corrections (dish_slug, user_id, client_correction_id, field, value_low, value_high) values ('mig-dal', ${u!.id}, ${ccid}, 'kcal', 150, 200)`;
    const [c] = await client<{ status: string }[]>`select status from mess_dish_corrections where client_correction_id = ${ccid}`;
    expect(c!.status).toBe('pending');
    await expect(
      client`insert into mess_dish_corrections (dish_slug, user_id, client_correction_id, field, value_low, value_high) values ('mig-dal', ${u!.id}, ${ccid}, 'kcal', 150, 200)`,
    ).rejects.toThrow(/user_client_id/);
    await expect(
      client`insert into mess_dish_corrections (dish_slug, user_id, client_correction_id, field, value_low, value_high) values ('mig-dal', ${u!.id}, gen_random_uuid(), 'kcal', 200, 150)`,
    ).rejects.toThrow(/mess_dish_corrections_value/);
    await expect(
      client`insert into mess_dish_corrections (dish_slug, user_id, client_correction_id, field, diet_value) values ('mig-dal', ${u!.id}, gen_random_uuid(), 'diet', 'unknown')`,
    ).rejects.toThrow(/mess_dish_corrections_value/);

    // A mess log: only entry_method 'mess' names a mess; an item is a food OR a mess dish.
    const [log] = await client<{ id: string }[]>`
      insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method, mess_id)
      values (${u!.id}, gen_random_uuid(), now(), '2026-09-24', 'lunch', 'mess', ${mess!.id}) returning id`;
    await expect(
      client`insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method, mess_id)
             values (${u!.id}, gen_random_uuid(), now(), '2026-09-24', 'lunch', 'search', ${mess!.id})`,
    ).rejects.toThrow(/food_logs_mess_method/);
    const [food] = await client<{ id: string }[]>`select id from foods limit 1`;
    const item = (over: string) => client.unsafe(
      `insert into food_log_items (food_log_id, position, food_id, mess_dish_slug, food_name, food_source, basis, serving_label, servings, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, confidence)
       values ('${log!.id}', ${over}, 'Dal', 'estimated', 'per_serving', '1 katori', 1, 120, 185, 6, 9, 16, 23, 3, 7, 'medium')`,
    );
    await item(`0, null, 'mig-dal'`);
    if (food !== undefined) await expect(item(`1, '${food.id}', 'mig-dal'`)).rejects.toThrow(/food_log_items_mess_or_food/);
    // A logged dish keeps its snapshot when the mess, its menus and estimates go.
    await client`delete from messes where id = ${mess!.id}`;
    const [after] = await client<{ mess_id: string | null }[]>`select mess_id from food_logs where id = ${log!.id}`;
    expect(after!.mess_id).toBeNull();
    expect((await client`select 1 from mess_menu_snapshots where payload_hash = ${hash}`).length).toBe(0);
    await client`delete from mess_dish_nutrition where dish_slug = 'mig-dal'`;
    const [kept] = await client<{ mess_dish_slug: string; kcal_high: string }[]>`select mess_dish_slug, kcal_high from food_log_items where food_log_id = ${log!.id}`;
    expect(kept).toEqual({ mess_dish_slug: 'mig-dal', kcal_high: '185.00' });
    await client`delete from users where id = ${u!.id}`;
    await client`delete from mess_providers where id = ${prov!.id}`;
  });

  it('0013: TODAY recommendations and events — identity, checks, event rules, cascades; down drops them (Phase 11, ADR-017)', async () => {
    expect(await rollbackLastMigration(connectionString)).toBe('0013_today');
    expect(await tableExists(client, 'recommendations')).toBe(false);
    expect(await tableExists(client, 'recommendation_events')).toBe(false);
    for (const t of ['today_action_kind', 'action_basis', 'action_target', 'recommendation_event']) expect(await enumLabels(client, t), t).toEqual([]);
    await migrateUp(connectionString);
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);

    expect(await enumLabels(client, 'today_action_kind')).toEqual([
      'deload', 'injured-limitation', 'start-workout', 'eat-protein', 'eat-meal', 'progress-load', 'muscle-neglected', 'rest-day', 'celebrate-pr', 'log-weight',
    ]);
    expect(await enumLabels(client, 'action_basis')).toEqual(['logged', 'calculated', 'estimated']);
    expect(await enumLabels(client, 'action_target')).toEqual(['train', 'eat', 'progress', 'today']);
    expect(await enumLabels(client, 'recommendation_event')).toEqual(['shown', 'opened', 'accepted', 'dismissed', 'completed']);
    const cols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'recommendations' order by ordinal_position`;
    expect(cols.map((c) => c.column_name)).toEqual([
      'id', 'user_id', 'generated_for', 'kind', 'subject_key', 'rank', 'priority', 'basis', 'target', 'payload',
      'engine_version', 'input_digest', 'headline', 'detail', 'content_hash', 'created_at',
    ]);
    const evCols = await client<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'recommendation_events' order by ordinal_position`;
    expect(evCols.map((c) => c.column_name)).toEqual(['id', 'recommendation_id', 'user_id', 'event', 'client_event_id', 'occurred_at', 'received_at']);
    // Actions are day-level decisions: no foreign keys to logs, menus or workouts.
    const fks = await client<{ table_name: string; foreign_table: string }[]>`
      select tc.table_name, ccu.table_name as foreign_table
      from information_schema.table_constraints tc
      join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name
      where tc.constraint_type = 'FOREIGN KEY' and tc.table_name in ('recommendations', 'recommendation_events')
      order by tc.table_name, ccu.table_name`;
    expect(fks.map((f) => `${f.table_name}->${f.foreign_table}`)).toEqual([
      'recommendation_events->recommendations', 'recommendation_events->users', 'recommendations->users',
    ]);

    await client`insert into users (firebase_uid) values ('mig-today')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-today'`;
    const H = 'a'.repeat(64);
    const rec = (over: Record<string, string | number> = {}) => {
      const v = { kind: 'eat-meal', subject: 'lunch', rank: 1, priority: 75, hash: H, digest: H, headline: 'h', ...over };
      return client.unsafe<{ id: string }[]>(
        `insert into recommendations (user_id, generated_for, kind, subject_key, rank, priority, basis, target, payload, engine_version, input_digest, headline, detail, content_hash)
         values ('${u!.id}', '2026-09-24', '${v.kind}', '${v.subject}', ${v.rank}, ${v.priority}, 'calculated', 'eat', '{}'::jsonb, 'today-1', '${v.digest}', '${v.headline}', 'd', '${v.hash}') returning id`,
      );
    };
    const [r1] = await rec();
    // The D4 identity: the same (user, day, kind, subject, content hash) twice is refused …
    await expect(rec()).rejects.toThrow(/recommendations_identity/);
    // … changed content is a new row beside it; the old row is kept.
    await rec({ hash: 'b'.repeat(64), rank: 2 });
    await expect(rec({ hash: 'c'.repeat(64), rank: 5 })).rejects.toThrow(/recommendations_rank/);
    await expect(rec({ hash: 'c'.repeat(64), priority: 101 })).rejects.toThrow(/recommendations_priority/);
    await expect(rec({ hash: 'NOT-HEX' })).rejects.toThrow(/recommendations_content_hash/);
    await expect(rec({ hash: 'c'.repeat(64), digest: 'x' })).rejects.toThrow(/recommendations_input_digest/);
    await expect(rec({ hash: 'c'.repeat(64), headline: '' })).rejects.toThrow(/recommendations_text/);
    await expect(rec({ hash: 'c'.repeat(64), kind: 'hydrate' })).rejects.toThrow(/invalid input value for enum today_action_kind/);

    const ev = (event: string, clientId: string) =>
      client.unsafe(
        `insert into recommendation_events (recommendation_id, user_id, event, client_event_id, occurred_at) values ('${r1!.id}', '${u!.id}', '${event}', '${clientId}', now())`,
      );
    await ev('shown', '11111111-1111-4111-8111-111111111111');
    // One client id per user; each event once per recommendation.
    await expect(ev('opened', '11111111-1111-4111-8111-111111111111')).rejects.toThrow(/recommendation_events_client_id/);
    await expect(ev('shown', '22222222-2222-4222-8222-222222222222')).rejects.toThrow(/recommendation_events_once/);
    await expect(ev('liked', '33333333-3333-4333-8333-333333333333')).rejects.toThrow(/invalid input value for enum recommendation_event/);
    const [stored] = await client<{ received_at: Date }[]>`select received_at from recommendation_events where recommendation_id = ${r1!.id}`;
    expect(stored!.received_at).toBeInstanceOf(Date);

    // Deleting a recommendation takes its events; deleting the user takes everything.
    await client`delete from recommendations where id = ${r1!.id}`;
    expect((await client`select 1 from recommendation_events where recommendation_id = ${r1!.id}`).length).toBe(0);
    await client`delete from users where id = ${u!.id}`;
    expect((await client`select 1 from recommendations where user_id = ${u!.id}`).length).toBe(0);

    // Down with data present drops both tables and the four types.
    await client`insert into users (firebase_uid) values ('mig-today-down')`;
    const [d] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-today-down'`;
    await client.unsafe(
      `insert into recommendations (user_id, generated_for, kind, subject_key, rank, priority, basis, target, payload, engine_version, input_digest, headline, detail, content_hash)
       values ('${d!.id}', '2026-09-24', 'log-weight', '', 1, 45, 'calculated', 'progress', '{}'::jsonb, 'today-1', '${H}', 'h', 'd', '${H}')`,
    );
    expect(await rollbackLastMigration(connectionString)).toBe('0013_today');
    expect(await tableExists(client, 'recommendations')).toBe(false);
    expect(await enumLabels(client, 'recommendation_event')).toEqual([]);
    await migrateUp(connectionString);
    await client`delete from users where id = ${d!.id}`;
  });

  it('0012: four Phase 9 estimates corrected with provenance, only where still wrong; down restores them (Phase 10 Amendment B)', async () => {
    expect(await rollbackLastMigration(connectionString)).toBe('0013_today');
    expect(await rollbackLastMigration(connectionString)).toBe('0012_mess_estimate_corrections');
    expect(await tableExists(client, 'mess_dish_nutrition_revisions')).toBe(false);
    const row = (slug: string, name: string, label: string, grams: number, v: readonly number[]) => client.unsafe(
      `insert into mess_dish_nutrition (dish_slug, name, serving_label, serving_grams, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, confidence)
       values ('${slug}', '${name}', '${label}', ${grams}, ${v.join(', ')}, 'medium')`,
    );
    // The exact wrong Phase 9 rows …
    await row('curd-rice', 'Curd Rice', '1 cup', 120, [65, 105, 4, 7, 5, 8, 3, 5.5]);
    await row('rice-papad', 'Rice Papad', '1 katori', 150, [175, 215, 3.2, 4.5, 38, 48, 0.3, 1.2]);
    await row('chole-bhatura', 'Chole Bhatura', '1 katori', 150, [150, 230, 7, 11, 20, 28, 4, 9]);
    // … and one already changed by someone else: left alone. (Absent rows: nothing to do.)
    await row('dahi-vada', 'Dahi Vada', '1 cup', 120, [70, 105, 4, 7, 5, 8, 3, 5.5]);

    await migrateUp(connectionString);
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);
    type Est = { serving_label: string; serving_grams: string; kcal_low: string; kcal_high: string; protein_low: string; fat_high: string; confidence: string };
    const est = async (slug: string) =>
      (await client<Est[]>`select serving_label, serving_grams, kcal_low, kcal_high, protein_low, fat_high, confidence from mess_dish_nutrition where dish_slug = ${slug}`)[0];
    expect(await est('curd-rice')).toEqual({ serving_label: '1 katori', serving_grams: '180.00', kcal_low: '180.00', kcal_high: '260.00', protein_low: '5.00', fat_high: '8.00', confidence: 'medium' });
    expect(await est('rice-papad')).toEqual({ serving_label: '1 small portion', serving_grams: '25.00', kcal_low: '95.00', kcal_high: '155.00', protein_low: '1.00', fat_high: '10.00', confidence: 'low' });
    expect(await est('chole-bhatura')).toEqual({ serving_label: '1 plate (2 bhatura + chole)', serving_grams: '330.00', kcal_low: '590.00', kcal_high: '870.00', protein_low: '17.00', fat_high: '41.00', confidence: 'low' });
    expect((await est('dahi-vada'))!.kcal_low).toBe('70.00');

    const revs = await client<{ dish_slug: string; reason: string; previous: Record<string, unknown>; current: Record<string, unknown> }[]>`
      select dish_slug, reason, previous, current from mess_dish_nutrition_revisions order by dish_slug`;
    expect(revs.map((r) => r.dish_slug)).toEqual(['chole-bhatura', 'curd-rice', 'rice-papad']);
    for (const r of revs) expect(r.reason).toBe('phase-10-estimate-correction');
    const curd = revs.find((r) => r.dish_slug === 'curd-rice')!;
    expect(Number(curd.previous['kcalLow'])).toBe(65);
    expect(curd.previous['servingLabel']).toBe('1 cup');
    expect(Number(curd.current['kcalLow'])).toBe(180);
    await expect(client`insert into mess_dish_nutrition_revisions (dish_slug, reason, previous, current) values ('curd-rice', ' ', '{}', '{}')`).rejects.toThrow(/revisions_reason/);

    // Down puts the recorded previous values back and drops the provenance table.
    expect(await rollbackLastMigration(connectionString)).toBe('0013_today');
    expect(await rollbackLastMigration(connectionString)).toBe('0012_mess_estimate_corrections');
    expect(await tableExists(client, 'mess_dish_nutrition_revisions')).toBe(false);
    expect(await est('curd-rice')).toEqual({ serving_label: '1 cup', serving_grams: '120.00', kcal_low: '65.00', kcal_high: '105.00', protein_low: '4.00', fat_high: '5.50', confidence: 'medium' });
    expect((await est('dahi-vada'))!.kcal_low).toBe('70.00');

    await migrateUp(connectionString);
    await client`delete from mess_dish_nutrition where dish_slug in ('curd-rice', 'rice-papad', 'chole-bhatura', 'dahi-vada')`;
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

  it('down removes 0013 (TODAY), 0012 (restoring the corrected estimates), 0011 (rebuilding food_entry_method; mess logs and meals go, the day cache is rebuilt), 0010, 0009, 0008, 0007, 0006, 0005, then 0004 (rebuilding the enums), then Phase 4, 3, 2, one migration at a time', async () => {
    // Data that only 0011 can hold, next to data 0010 keeps.
    await client`insert into users (firebase_uid) values ('mig-down')`;
    const [u] = await client<{ id: string }[]>`select id from users where firebase_uid = 'mig-down'`;
    const logRow = async (method: string) => {
      const [l] = await client.unsafe<{ id: string }[]>(
        `insert into food_logs (user_id, client_log_id, logged_at, local_date, meal_slot, entry_method) values ('${u!.id}', gen_random_uuid(), now(), '2026-09-20', 'lunch', '${method}') returning id`,
      );
      await client.unsafe(
        `insert into food_log_items (food_log_id, position, mess_dish_slug, food_name, food_source, basis, serving_label, servings, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, confidence)
         values ('${l!.id}', 0, ${method === 'quick-add' ? 'null' : "'dal'"}, 'Dal', 'estimated', 'per_serving', '1 katori', 1, 100, 150, 5, 8, 10, 20, 2, 6, 'medium')`,
      );
    };
    await logRow('mess');
    await logRow('quick-add');
    await client`insert into daily_nutrition (user_id, local_date, kcal_low, kcal_high, item_count) values (${u!.id}, '2026-09-20', 200, 300, 2)`;
    await client`insert into saved_meals (user_id, client_meal_id, name, items) values (${u!.id}, gen_random_uuid(), 'Mess lunch', '[{"kind":"mess","dishSlug":"dal","name":"Dal","servings":1}]'::jsonb)`;
    await client`insert into saved_meals (user_id, client_meal_id, name, items) values (${u!.id}, gen_random_uuid(), 'Plain', '[{"kind":"quick-add","name":"X","kcal":1,"proteinG":0,"carbG":0,"fatG":0,"fibreG":null}]'::jsonb)`;

    expect(await rollbackLastMigration(connectionString)).toBe('0013_today');
    expect(await tableExists(client, 'recommendations')).toBe(false);
    expect(await rollbackLastMigration(connectionString)).toBe('0012_mess_estimate_corrections');
    expect(await tableExists(client, 'mess_dish_nutrition_revisions')).toBe(false);
    expect(await rollbackLastMigration(connectionString)).toBe('0011_mess');
    for (const t of ['mess_providers', 'messes', 'mess_menu_snapshots', 'mess_dish_nutrition', 'mess_dish_corrections']) {
      expect(await tableExists(client, t), t).toBe(false);
    }
    expect(await enumLabels(client, 'food_entry_method')).toEqual(['search', 'quick-add', 'saved-meal']);
    const methods = await client<{ entry_method: string }[]>`select entry_method from food_logs where user_id = ${u!.id}`;
    expect(methods.map((m) => m.entry_method)).toEqual(['quick-add']);
    const [day] = await client<{ kcal_low: string; item_count: number }[]>`select kcal_low, item_count from daily_nutrition where user_id = ${u!.id}`;
    expect(day).toEqual({ kcal_low: '100.00', item_count: 1 });
    const meals = await client<{ name: string }[]>`select name from saved_meals where user_id = ${u!.id}`;
    expect(meals.map((m) => m.name)).toEqual(['Plain']);
    await expect(client`update food_logs set saved_meal_id = gen_random_uuid() where user_id = ${u!.id}`).rejects.toThrow(/saved_meal_method|foreign key/);
    await client`delete from users where id = ${u!.id}`;
    expect(await appliedCount(client)).toBe(11);

    expect(await rollbackLastMigration(connectionString)).toBe('0010_nutrition_logging');
    for (const t of ['food_logs', 'food_log_items', 'daily_nutrition', 'saved_meals']) expect(await tableExists(client, t), t).toBe(false);
    const logEnums = await client<{ typname: string }[]>`select typname from pg_type where typname in ('meal_slot', 'food_entry_method')`;
    expect(logEnums).toHaveLength(0);
    expect(await tableExists(client, 'foods')).toBe(true);
    expect(await appliedCount(client)).toBe(10);

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
