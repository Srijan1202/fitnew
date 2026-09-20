/**
 * Migration runner.
 *
 * Up is drizzle's own migrator, which records each applied file in
 * `drizzle.__drizzle_migrations`. Down is ours: drizzle-kit is forward-only
 * (§25), but the contract requires every migration verified in both
 * directions, so each up ships with a hand-written `down/<name>.down.sql` and
 * `rollbackLastMigration` applies it inside one transaction together with
 * removing the journal row — so the next `migrateUp` genuinely re-applies it.
 *
 * In production this runs as a Cloud Run job BEFORE the new revision receives
 * traffic (§25). It is deliberately not wired into server startup: a server
 * that migrates on boot will race itself the moment there are two instances.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';

import { createDatabase } from './client.js';

/** database/migrations at the repo root (§29), resolved from this file. */
export const MIGRATIONS_DIR = fileURLToPath(
  new URL('../../../../database/migrations/', import.meta.url),
);

interface JournalEntry {
  readonly idx: number;
  readonly tag: string;
}

function readJournal(): readonly JournalEntry[] {
  const raw = readFileSync(`${MIGRATIONS_DIR}meta/_journal.json`, 'utf8');
  const parsed = JSON.parse(raw) as { entries: JournalEntry[] };
  return parsed.entries;
}

export async function migrateUp(connectionString: string): Promise<void> {
  const { db, client } = createDatabase(connectionString);
  try {
    await migrate(db, { migrationsFolder: MIGRATIONS_DIR });
  } finally {
    await client.end({ timeout: 5 });
  }
}

/**
 * Reverts the most recently applied migration and forgets it from the journal,
 * atomically. Returns the tag that was rolled back, or null if nothing was
 * applied.
 */
export async function rollbackLastMigration(connectionString: string): Promise<string | null> {
  const client = postgres(connectionString, { max: 1 });
  try {
    const journal = readJournal();

    // drizzle keeps one row per applied file, in order. The migration to
    // revert is the last APPLIED one — journal[appliedCount - 1] — not the
    // last one listed: a freshly generated, not-yet-applied migration must
    // not block rolling back the one before it.
    const applied = await client<{ count: string }[]>`
      select count(*)::text as count from drizzle.__drizzle_migrations
    `.catch(() => [{ count: '0' }]);
    const appliedCount = Number(applied[0]?.count ?? 0);
    if (appliedCount === 0) return null;
    if (appliedCount > journal.length) {
      throw new Error(
        `${appliedCount} migrations are applied but the journal lists only ${journal.length}; the checkout is behind the database.`,
      );
    }
    const last = journal[appliedCount - 1];
    if (last === undefined) return null;

    const downSql = readFileSync(`${MIGRATIONS_DIR}down/${last.tag}.down.sql`, 'utf8');

    await client.begin(async (tx) => {
      await tx.unsafe(downSql);
      await tx`
        delete from drizzle.__drizzle_migrations
        where id = (select max(id) from drizzle.__drizzle_migrations)
      `;
    });

    return last.tag;
  } finally {
    await client.end({ timeout: 5 });
  }
}

/* ------------------------------------------------------------------ CLI -- */

const isDirectRun =
  process.argv[1] !== undefined && import.meta.url === new URL(`file://${process.argv[1]}`).href;

if (isDirectRun) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined || url === '') {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  const command = process.argv[2] ?? 'up';
  const run = async (): Promise<void> => {
    if (command === 'up') {
      await migrateUp(url);
      console.log('migrations applied');
    } else if (command === 'down') {
      const tag = await rollbackLastMigration(url);
      console.log(tag === null ? 'nothing to roll back' : `rolled back ${tag}`);
    } else {
      throw new Error(`unknown command "${command}" — use "up" or "down"`);
    }
  };
  run().catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
