/**
 * Auth plugin: token verification and the default-deny rule.
 *
 * Spec §31 Phase 1 tests: "token verification (valid/expired/malformed)" and
 * "every protected route returns 401 unauthenticated". Both live here, on a
 * stub database, with scripted tokens — no Firebase involved.
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { FastifyInstance, RouteOptions } from 'fastify';

import { buildApp } from '../app.js';
import { FakeTokenVerifier } from '../test/fake-token-verifier.js';
import { buildStubApp, stubDatabase, testEnv } from '../test/build-test-app.js';
import { isProtectedRoute, requireAdmin } from './auth.js';

let app: FastifyInstance;
let verifier: FakeTokenVerifier;

beforeEach(async () => {
  ({ app, verifier } = await buildStubApp());
});

afterEach(async () => {
  await app.close();
});

/** A protected /v1 endpoint. /auth/session needs a table; this one does not. */
const PROBE = '/v1/auth/session';

describe('token verification', () => {
  it('valid: a good token reaches the handler and carries identity', async () => {
    verifier.accept('good', { uid: 'u1', email: 'a@b.c' });
    // DELETE /auth/session only needs identity + the verifier, no table.
    const r = await app.inject({
      method: 'DELETE',
      url: PROBE,
      headers: { authorization: 'Bearer good' },
    });
    expect(r.statusCode).toBe(204);
    expect(verifier.revoked).toEqual(['u1']);
  });

  it('expired: 401 with a message the client can act on', async () => {
    verifier.reject('old', 'expired');
    const r = await app.inject({ method: 'DELETE', url: PROBE, headers: { authorization: 'Bearer old' } });
    expect(r.statusCode).toBe(401);
    expect(r.json().error.code).toBe('UNAUTHENTICATED');
    expect(r.json().error.message).toMatch(/expired/i);
  });

  it('malformed: 401, and the message does not explain why', async () => {
    verifier.reject('junk', 'malformed');
    const r = await app.inject({ method: 'DELETE', url: PROBE, headers: { authorization: 'Bearer junk' } });
    expect(r.statusCode).toBe(401);
    expect(r.json().error.message).not.toMatch(/malformed|invalid|signature/i);
  });

  it('revoked: a signed-out user’s unexpired token is rejected', async () => {
    verifier.reject('after-signout', 'revoked');
    const r = await app.inject({
      method: 'DELETE',
      url: PROBE,
      headers: { authorization: 'Bearer after-signout' },
    });
    expect(r.statusCode).toBe(401);
  });

  it('unknown token: 401, never 500', async () => {
    const r = await app.inject({
      method: 'DELETE',
      url: PROBE,
      headers: { authorization: 'Bearer never-registered' },
    });
    expect(r.statusCode).toBe(401);
  });
});

describe('Authorization header parsing', () => {
  it.each([
    ['missing entirely', undefined],
    ['empty', ''],
    ['wrong scheme', 'Basic abc'],
    ['bearer with no token', 'Bearer'],
    ['bearer with two tokens', 'Bearer a b'],
    ['token without scheme', 'good'],
  ])('%s → 401', async (_label, header) => {
    verifier.accept('good', { uid: 'u1' });
    const r = await app.inject({
      method: 'DELETE',
      url: PROBE,
      headers: header === undefined ? {} : { authorization: header },
    });
    expect(r.statusCode).toBe(401);
    expect(r.json().error.code).toBe('UNAUTHENTICATED');
  });

  it('scheme is case-insensitive per RFC 7235', async () => {
    verifier.accept('good', { uid: 'u1' });
    const r = await app.inject({ method: 'DELETE', url: PROBE, headers: { authorization: 'bearer good' } });
    expect(r.statusCode).toBe(204);
  });
});

describe('default-deny under /v1', () => {
  it('every registered /v1 route without config.public returns 401 with no token', async () => {
    // Collect routes as they are registered, so a new endpoint added in a later
    // phase is swept automatically — nobody has to remember to list it here.
    const registered: RouteOptions[] = [];
    const swept = await buildApp(testEnv(), {
      database: stubDatabase(),
      tokenVerifier: new FakeTokenVerifier(),
      onRoute: (route) => {
        registered.push(route);
      },
    });
    await swept.ready();

    const protectedRoutes = registered.filter((r) => isProtectedRoute(r.url, r.config));
    expect(protectedRoutes.length).toBeGreaterThan(0);

    for (const route of protectedRoutes) {
      const methods = Array.isArray(route.method) ? route.method : [route.method];
      for (const method of methods) {
        if (method === 'HEAD' || method === 'OPTIONS') continue;
        const r = await swept.inject({
          method: method as 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
          url: route.url,
        });
        expect(r.statusCode, `${method} ${route.url}`).toBe(401);
        expect(r.json().error.code, `${method} ${route.url}`).toBe('UNAUTHENTICATED');
      }
    }
    await swept.close();
  });

  it('/health is outside /v1 and stays public', async () => {
    const r = await app.inject({ method: 'GET', url: '/health' });
    expect(r.statusCode).not.toBe(401);
  });

  it('isProtectedRoute: /v1 is protected unless explicitly public', () => {
    expect(isProtectedRoute('/v1/anything', undefined)).toBe(true);
    expect(isProtectedRoute('/v1/anything', {})).toBe(true);
    expect(isProtectedRoute('/v1/meta/config', { public: true })).toBe(false);
    expect(isProtectedRoute('/health', undefined)).toBe(false);
    expect(isProtectedRoute('/docs', undefined)).toBe(false);
  });
});

describe('requireAdmin', () => {
  it('403 for an authenticated non-admin, 401 for nobody', async () => {
    const asUser = { identity: { uid: 'u', email: null, emailVerified: true, claims: {} } };
    await expect(requireAdmin(asUser as never, {} as never)).rejects.toMatchObject({ code: 'FORBIDDEN' });

    const asAdmin = { identity: { uid: 'a', email: null, emailVerified: true, claims: { role: 'admin' } } };
    await expect(requireAdmin(asAdmin as never, {} as never)).resolves.toBeUndefined();

    const nobody = { identity: null };
    await expect(requireAdmin(nobody as never, {} as never)).rejects.toMatchObject({
      code: 'UNAUTHENTICATED',
    });
  });
});
