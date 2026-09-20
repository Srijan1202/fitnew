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

  it('starts from nothing', async () => {
    expect(await tableExists(client, 'users')).toBe(false);
    expect(await appliedCount(client)).toBe(0);
  });

  it('up creates users with the §9.1 conventions', async () => {
    await migrateUp(connectionString);
    expect(await tableExists(client, 'users')).toBe(true);
    expect(await appliedCount(client)).toBe(1);

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

  it('up is idempotent — running it again applies nothing', async () => {
    await migrateUp(connectionString);
    expect(await appliedCount(client)).toBe(1);
  });

  it('firebase_uid is unique at the database level, not just in code', async () => {
    await client`insert into users (firebase_uid) values ('uid-dup')`;
    await expect(client`insert into users (firebase_uid) values ('uid-dup')`).rejects.toThrow(
      /unique/i,
    );
    await client`delete from users where firebase_uid = 'uid-dup'`;
  });

  it('down removes the table AND the journal row', async () => {
    const tag = await rollbackLastMigration(connectionString);
    expect(tag).toBe('0000_users');
    expect(await tableExists(client, 'users')).toBe(false);
    expect(await appliedCount(client)).toBe(0);
  });

  it('down on an empty journal is a no-op, not an error', async () => {
    expect(await rollbackLastMigration(connectionString)).toBeNull();
  });

  it('up after down genuinely re-applies', async () => {
    await migrateUp(connectionString);
    expect(await tableExists(client, 'users')).toBe(true);
    expect(await appliedCount(client)).toBe(1);
  });
});
