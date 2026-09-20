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

const url = process.env['DATABASE_URL'];
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
  const TOTAL_MIGRATIONS = 4;

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

  it('down removes the Phase 4, 3, then 2 tables and types, one migration at a time', async () => {
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
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);
  });
});
