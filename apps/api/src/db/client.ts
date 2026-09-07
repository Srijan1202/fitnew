/**
 * Postgres connection.
 *
 * `postgres.js` over plain TCP, no proprietary driver: §28 requires the stack
 * stay portable, so moving from Neon to Cloud SQL is a connection-string change
 * and nothing else.
 *
 * The pool is deliberately small. Cloud Run gives each instance little
 * concurrency and Neon's free plan bills compute time, so a fat idle pool costs
 * money for nothing (§8.4).
 */
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

import * as schema from './schema/index.js';

export interface DatabaseHandle {
  readonly db: ReturnType<typeof drizzle<typeof schema>>;
  readonly client: postgres.Sql;
}

export function createDatabase(connectionString: string): DatabaseHandle {
  const client = postgres(connectionString, {
    max: 5,
    idle_timeout: 20,
    connect_timeout: 10,
  });
  return { db: drizzle(client, { schema }), client };
}

/**
 * Liveness ping for /health. Returns round-trip latency in ms, or throws.
 * `select 1` is deliberate: it proves the connection works without depending
 * on any table existing yet, so /health is meaningful before Phase 1.
 */
export async function pingDatabase(client: postgres.Sql): Promise<number> {
  const started = performance.now();
  await client`select 1`;
  return Math.round(performance.now() - started);
}
