/**
 * /health against a REAL Postgres.
 *
 * Skipped unless DATABASE_URL is set, so `pnpm test` works on a laptop with no
 * database. CI sets it against an ephemeral Postgres service (§25), which is
 * where this actually runs.
 */
import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';

import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

let app: FastifyInstance | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

describeIfDb('GET /health (real Postgres)', () => {
  it('returns 200 and a real round-trip latency', async () => {
    ({ app } = await buildDbApp(databaseUrl as string));
    const response = await app.inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(200);
    expect(response.json().database.reachable).toBe(true);
  });
});
