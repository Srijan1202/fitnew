/**
 * Which database the integration tests may touch.
 *
 * The migration suite rolls EVERY migration back in its `beforeAll` — it
 * drops `users`. Run against the developer's `DATABASE_URL` it wiped the
 * local account, profile and programmes on every `pnpm test`; the next
 * sign-in then re-created the user at onboarding stage "goal", which the
 * owner saw as "the app asks for my profile again". Tests therefore never
 * use `DATABASE_URL` directly:
 *
 *   TEST_DATABASE_URL   explicit; its database name must end in `_test`
 *   DATABASE_URL        derived: same server, database `<name>_test`
 *   neither             integration suites skip
 *
 * The derived database is created (with the extensions docker/init grants)
 * by the vitest global setup, so `pnpm test` works on a fresh checkout.
 */
import postgres from 'postgres';

export class UnsafeTestDatabaseError extends Error {}

function databaseName(url: URL): string {
  return decodeURIComponent(url.pathname.replace(/^\//, ''));
}

/** `.env` is what `pnpm dev` reads; tests read it the same way so the derivation matches. */
export function loadDotEnv(path = '.env'): void {
  if (process.env['DATABASE_URL'] !== undefined || process.env['TEST_DATABASE_URL'] !== undefined) return;
  try {
    process.loadEnvFile(path);
  } catch {
    /* no .env: CI sets the variables itself */
  }
}

export function resolveTestDatabaseUrl(env: NodeJS.ProcessEnv = process.env): string | undefined {
  const explicit = env['TEST_DATABASE_URL'];
  if (explicit !== undefined && explicit !== '') {
    const name = databaseName(new URL(explicit));
    if (!name.endsWith('_test')) {
      throw new UnsafeTestDatabaseError(
        `TEST_DATABASE_URL points at "${name}"; the test database name must end in "_test" (the migration suite drops every table).`,
      );
    }
    return explicit;
  }
  const base = env['DATABASE_URL'];
  if (base === undefined || base === '') return undefined;
  const url = new URL(base);
  const name = databaseName(url);
  url.pathname = `/${name.endsWith('_test') ? name : `${name}_test`}`;
  return url.toString();
}

/** Create the test database on the same server if it does not exist yet. Idempotent. */
export async function ensureTestDatabase(testUrl: string): Promise<void> {
  const target = new URL(testUrl);
  const name = databaseName(target);
  const admin = new URL(testUrl);
  admin.pathname = '/postgres';
  const sql = postgres(admin.toString(), { max: 1, onnotice: () => undefined });
  try {
    const rows = await sql<{ exists: boolean }[]>`select exists (select 1 from pg_database where datname = ${name}) as exists`;
    if (!(rows[0]?.exists ?? false)) {
      await sql.unsafe(`create database "${name.replace(/"/g, '""')}"`);
    }
  } finally {
    await sql.end({ timeout: 5 });
  }
  const db = postgres(testUrl, { max: 1, onnotice: () => undefined });
  try {
    // Mirrors docker/init/01-extensions.sql and the ci-api "Create extensions" step.
    await db`create extension if not exists pgcrypto`;
    await db`create extension if not exists pg_trgm`;
  } finally {
    await db.end({ timeout: 5 });
  }
}
