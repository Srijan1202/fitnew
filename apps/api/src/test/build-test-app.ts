/**
 * Shared harness. Builds the real app with the two production seams swapped:
 * a stub or real database, and a scripted token verifier.
 */
import type { FastifyInstance } from 'fastify';
import type postgres from 'postgres';

import { buildApp } from '../app.js';
import { createDatabase, type DatabaseHandle } from '../db/client.js';
import type { Env } from '../lib/env.js';
import { FakeTokenVerifier } from './fake-token-verifier.js';

export function testEnv(overrides: Partial<Env> = {}): Env {
  return {
    NODE_ENV: 'test',
    PORT: 0,
    // TEST_LOG_LEVEL=error surfaces handler errors behind a 500 while debugging.
    LOG_LEVEL: (process.env['TEST_LOG_LEVEL'] as 'fatal' | 'error' | 'warn' | 'info' | 'debug' | 'trace' | undefined) ?? 'fatal',
    DATABASE_URL: 'postgres://unused:unused@localhost:5432/unused',
    FIREBASE_PROJECT_ID: 'fitos-test',
    CONSENT_IP_SALT: 'test-salt-not-secret',
    GEMINI_MODEL: 'gemini-2.5-flash',
    AI_TIMEOUT_MS: 5000,
    AI_MAX_OUTPUT_TOKENS: 512,
    ...overrides,
  };
}

/** A database stub that answers `select 1` (or refuses to). Nothing else. */
export function stubDatabase(behaviour: 'ok' | 'down' = 'ok'): DatabaseHandle {
  const client = (async () => {
    if (behaviour === 'down') throw new Error('connection refused');
    return [{ '?column?': 1 }];
  }) as unknown as postgres.Sql;
  (client as unknown as { end: () => Promise<void> }).end = async () => undefined;
  return { db: {} as DatabaseHandle['db'], client };
}

export interface TestApp {
  readonly app: FastifyInstance;
  readonly verifier: FakeTokenVerifier;
}

/** App on a stub database — for anything that does not touch a table. */
export async function buildStubApp(dbBehaviour: 'ok' | 'down' = 'ok'): Promise<TestApp> {
  const verifier = new FakeTokenVerifier();
  const app = await buildApp(testEnv(), {
    database: stubDatabase(dbBehaviour),
    tokenVerifier: verifier,
    resolveUserId: async () => null,
  });
  return { app, verifier };
}

/** App on the real DATABASE_URL — for route integration tests. */
export async function buildDbApp(connectionString: string): Promise<TestApp> {
  const verifier = new FakeTokenVerifier();
  const app = await buildApp(testEnv({ DATABASE_URL: connectionString }), {
    database: createDatabase(connectionString),
    tokenVerifier: verifier,
  });
  return { app, verifier };
}

/** The isolated test database (src/test/test-database.ts); undefined ⇒ integration suites skip. */
export const databaseUrl: string | undefined =
  process.env['TEST_DATABASE_URL'] !== undefined && process.env['TEST_DATABASE_URL'] !== ''
    ? process.env['TEST_DATABASE_URL']
    : undefined;
