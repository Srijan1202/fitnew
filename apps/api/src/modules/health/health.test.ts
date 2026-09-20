/**
 * /health behaviour.
 *
 * The 200 path is exercised against a stub connection so it runs in CI without
 * a live Postgres. `health.integration.test.ts` covers the same route against a
 * real database when DATABASE_URL is set.
 */
import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';

import { buildStubApp } from '../../test/build-test-app.js';

let app: FastifyInstance | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

describe('GET /health', () => {
  it('returns 200 with database latency when the database answers', async () => {
    ({ app } = await buildStubApp('ok'));
    const response = await app.inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(body.status).toBe('ok');
    expect(body.database.reachable).toBe(true);
    expect(body.database.latencyMs).toBeGreaterThanOrEqual(0);
    expect(body.uptimeSeconds).toBeGreaterThanOrEqual(0);
  });

  it('returns 503, not a cheerful 200, when the database is unreachable', async () => {
    ({ app } = await buildStubApp('down'));
    const response = await app.inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(503);
    expect(response.json().error.code).toBe('UPSTREAM_UNAVAILABLE');
  });
});

describe('error envelope', () => {
  it('returns the §10 envelope shape for an unknown route', async () => {
    ({ app } = await buildStubApp('ok'));
    const response = await app.inject({ method: 'GET', url: '/does-not-exist' });

    expect(response.statusCode).toBe(404);
    const body = response.json();
    expect(body.error.code).toBe('NOT_FOUND');
    expect(typeof body.error.message).toBe('string');
    expect(typeof body.error.requestId).toBe('string');
  });
});
