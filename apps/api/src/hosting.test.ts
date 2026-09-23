/**
 * Phase 6.7 Gate 6.7-1 — what changes when the API is hosted on Cloud Run,
 * and what must stay exactly as Phase 6.6 left it on the LAN.
 *
 *   /livez      process-only liveness (the startup probe), up with the DB down
 *   /docs       not published from a hosted server
 *   TRUST_PROXY a spoofed first X-Forwarded-For entry is not the client
 *   503         an unreachable database is "temporarily unavailable", not 500
 */
import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';

import { buildApp } from './app.js';
import { createDatabase } from './db/client.js';
import { isDatabaseUnavailable } from './db/errors.js';
import type { Env } from './lib/env.js';
import { stubDatabase, testEnv } from './test/build-test-app.js';
import { FakeTokenVerifier } from './test/fake-token-verifier.js';

let app: FastifyInstance | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

const hosted: Partial<Env> = {
  NODE_ENV: 'production',
  CONSENT_IP_SALT: 'a-real-salt-of-32-characters-xxxx',
  TRUST_PROXY: '1',
};

async function build(overrides: Partial<Env> = {}, db: 'ok' | 'down' = 'ok'): Promise<FastifyInstance> {
  return buildApp(testEnv(overrides), {
    database: stubDatabase(db),
    tokenVerifier: new FakeTokenVerifier(),
    resolveUserId: async () => null,
  });
}

/** A public probe route that reports what Fastify decided the client IP is. */
function withIpProbe(target: FastifyInstance): FastifyInstance {
  target.get('/__ip', { config: { rateLimit: false } }, async (request) => ({ ip: request.ip }));
  return target;
}

describe('GET /livez', () => {
  it('answers 200 from the process alone — even with the database down', async () => {
    app = await build({}, 'down');
    const r = await app.inject({ method: 'GET', url: '/livez' });
    expect(r.statusCode).toBe(200);
    expect(r.json()).toEqual({ status: 'ok', uptimeSeconds: expect.any(Number) });
    // /health still tells the truth about the database.
    expect((await app.inject({ method: 'GET', url: '/health' })).statusCode).toBe(503);
  });

  it('is public (no token) like /health', async () => {
    app = await build(hosted);
    expect((await app.inject({ method: 'GET', url: '/livez' })).statusCode).toBe(200);
  });
});

describe('/docs', () => {
  it.each(['/docs', '/docs/json'])('%s is 404 when NODE_ENV=production', async (url) => {
    app = await build(hosted);
    expect((await app.inject({ method: 'GET', url })).statusCode).toBe(404);
  });

  it('is 404 when NODE_ENV=staging', async () => {
    app = await build({ ...hosted, NODE_ENV: 'staging' });
    expect((await app.inject({ method: 'GET', url: '/docs/json' })).statusCode).toBe(404);
  });

  it('is still served off the internet (development / test), as in Phase 6.6', async () => {
    app = await build({ NODE_ENV: 'development' });
    const r = await app.inject({ method: 'GET', url: '/docs/json' });
    expect(r.statusCode).toBe(200);
    expect(r.json().paths['/livez']).toBeDefined();
  });
});

describe('TRUST_PROXY', () => {
  const spoofed = { 'x-forwarded-for': '6.6.6.6, 203.0.113.7' };

  it('a hop count believes only the entry the trusted proxy appended', async () => {
    app = withIpProbe(await build({ TRUST_PROXY: '1' }));
    const r = await app.inject({ method: 'GET', url: '/__ip', headers: spoofed });
    expect(r.json().ip).toBe('203.0.113.7');
  });

  it('unset keeps Phase 6.6: the whole chain is trusted (LAN compose, no proxy in front)', async () => {
    app = withIpProbe(await build());
    const r = await app.inject({ method: 'GET', url: '/__ip', headers: spoofed });
    expect(r.json().ip).toBe('6.6.6.6');
  });

  it('false ignores the header entirely', async () => {
    app = withIpProbe(await build({ TRUST_PROXY: 'false' }));
    const r = await app.inject({ method: 'GET', url: '/__ip', headers: spoofed });
    expect(r.json().ip).toBe('127.0.0.1');
  });

  it('with a hop count, rotating the spoofed entry does not escape the rate limit', async () => {
    app = await build({ TRUST_PROXY: '1' });
    let last = 0;
    for (let i = 0; i < 121; i += 1) {
      const r = await app.inject({
        method: 'GET',
        url: '/livez',
        headers: { 'x-forwarded-for': `10.9.${Math.floor(i / 250)}.${i % 250}, 203.0.113.9` },
      });
      last = r.statusCode;
    }
    expect(last).toBe(429);
  });
});

describe('database unavailable → 503 UPSTREAM_UNAVAILABLE', () => {
  it('a protected route whose user lookup cannot reach Postgres answers 503, not 500', async () => {
    const verifier = new FakeTokenVerifier();
    verifier.accept('tok', { uid: 'u-1', email: 'u1@vit.ac.in' });
    // Port 1: the connection is refused at once.
    const database = createDatabase('postgres://nobody:nothing@127.0.0.1:1/none');
    app = await buildApp(testEnv(), { database, tokenVerifier: verifier });
    const r = await app.inject({
      method: 'GET',
      url: '/v1/user/profile',
      headers: { authorization: 'Bearer tok' },
    });
    expect(r.statusCode, r.body).toBe(503);
    expect(r.json().error).toMatchObject({ code: 'UPSTREAM_UNAVAILABLE', requestId: expect.any(String) });
    expect(r.body).not.toMatch(/ECONNREFUSED|127\.0\.0\.1|postgres:\/\//);
  });

  it('any other unexpected error is still a 500 INTERNAL', async () => {
    app = await build();
    app.get('/__boom', async () => {
      throw new Error('a real bug');
    });
    const r = await app.inject({ method: 'GET', url: '/__boom' });
    expect(r.statusCode).toBe(500);
    expect(r.json().error.code).toBe('INTERNAL');
  });

  const withCode = (code: string, name = 'Error'): Error => Object.assign(new Error('x'), { code, name });

  it.each([
    ['ECONNREFUSED', withCode('ECONNREFUSED')],
    ['ECONNRESET', withCode('ECONNRESET')],
    ['ETIMEDOUT', withCode('ETIMEDOUT')],
    ['ENOTFOUND', withCode('ENOTFOUND')],
    ['CONNECTION_CLOSED (postgres.js)', withCode('CONNECTION_CLOSED')],
    ['CONNECT_TIMEOUT (postgres.js)', withCode('CONNECT_TIMEOUT')],
    ['57P01 admin_shutdown', withCode('57P01', 'PostgresError')],
    ['57P03 cannot_connect_now', withCode('57P03', 'PostgresError')],
    ['53300 too_many_connections', withCode('53300', 'PostgresError')],
    ['08006 connection_failure', withCode('08006', 'PostgresError')],
    ['wrapped in a cause', Object.assign(new Error('query failed'), { cause: withCode('ECONNRESET') })],
  ])('unavailable: %s', (_label, error) => {
    expect(isDatabaseUnavailable(error)).toBe(true);
  });

  it.each([
    ['a plain Error', new Error('bug')],
    ['23505 unique_violation', withCode('23505', 'PostgresError')],
    ['42P01 undefined_table', withCode('42P01', 'PostgresError')],
    ['a SQLSTATE-looking code on a non-Postgres error', withCode('08006')],
    ['null', null],
    ['a string', 'ECONNREFUSED'],
  ])('not unavailable: %s', (_label, error) => {
    expect(isDatabaseUnavailable(error)).toBe(false);
  });
});
