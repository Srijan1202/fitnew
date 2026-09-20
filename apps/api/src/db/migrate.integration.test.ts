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
  const TOTAL_MIGRATIONS = 2;

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

  it('down removes the Phase 2 tables and types, one migration at a time', async () => {
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
    expect(await appliedCount(client)).toBe(TOTAL_MIGRATIONS);
  });
});
