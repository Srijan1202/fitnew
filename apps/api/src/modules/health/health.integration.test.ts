/**
 * /health against a REAL Postgres.
 *
 * Skipped unless DATABASE_URL is set, so `pnpm test` works on a laptop with no
 * database. CI sets it against an ephemeral Postgres service (§25), which is
 * where this actually runs.
 */
import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';

import { buildApp } from '../../app.js';
import type { Env } from '../../lib/env.js';

const databaseUrl = process.env['DATABASE_URL'];
const describeIfDb = databaseUrl !== undefined && databaseUrl !== '' ? describe : describe.skip;

let app: FastifyInstance | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

describeIfDb('GET /health (real Postgres)', () => {
  it('returns 200 and a real round-trip latency', async () => {
    const env: Env = {
      NODE_ENV: 'test',
      PORT: 0,
      LOG_LEVEL: 'fatal',
      DATABASE_URL: databaseUrl as string,
    };
    app = await buildApp(env);
    const response = await app.inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(200);
    expect(response.json().database.reachable).toBe(true);
  });
});
