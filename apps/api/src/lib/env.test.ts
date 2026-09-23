import { describe, expect, it } from 'vitest';
import { DEV_CONSENT_IP_SALT, loadEnv, parseTrustProxy } from './env.js';

describe('environment validation', () => {
  it('rejects a missing DATABASE_URL loudly at boot', () => {
    expect(() => loadEnv({ FIREBASE_PROJECT_ID: 'x' })).toThrow(/DATABASE_URL/);
  });

  it('rejects a missing FIREBASE_PROJECT_ID — token verification needs it', () => {
    expect(() => loadEnv({ DATABASE_URL: 'postgres://a:b@localhost:5432/c' })).toThrow(
      /FIREBASE_PROJECT_ID/,
    );
  });

  it('does not require a credentials file — Cloud Run uses ADC', () => {
    const env = loadEnv({
      DATABASE_URL: 'postgres://a:b@localhost:5432/c',
      FIREBASE_PROJECT_ID: 'fitos-test',
    });
    expect(env.GOOGLE_APPLICATION_CREDENTIALS).toBeUndefined();
  });

  it('applies documented defaults', () => {
    const env = loadEnv({
      DATABASE_URL: 'postgres://a:b@localhost:5432/c',
      FIREBASE_PROJECT_ID: 'fitos-test',
    });
    expect(env.PORT).toBe(8080);
    expect(env.NODE_ENV).toBe('development');
  });

  // Phase 6.7 — a hosted server refuses to boot on development fallbacks.
  describe('hosted environments (Phase 6.7)', () => {
    const base = { DATABASE_URL: 'postgres://a:b@localhost:5432/c', FIREBASE_PROJECT_ID: 'fitos-test' };
    const salt = 'a-real-salt-of-32-characters-xxxx';

    it('development keeps the Phase 6.6 defaults: dev salt, TRUST_PROXY unset', () => {
      const env = loadEnv(base);
      expect(env.CONSENT_IP_SALT).toBe(DEV_CONSENT_IP_SALT);
      expect(env.TRUST_PROXY).toBeUndefined();
    });

    it.each(['production', 'staging'])('%s refuses the development salt', (nodeEnv) => {
      expect(() => loadEnv({ ...base, NODE_ENV: nodeEnv, TRUST_PROXY: '1' })).toThrow(/CONSENT_IP_SALT/);
    });

    it('production refuses a short salt', () => {
      expect(() => loadEnv({ ...base, NODE_ENV: 'production', TRUST_PROXY: '1', CONSENT_IP_SALT: 'short-8+' })).toThrow(/CONSENT_IP_SALT/);
    });

    it('production requires TRUST_PROXY', () => {
      expect(() => loadEnv({ ...base, NODE_ENV: 'production', CONSENT_IP_SALT: salt })).toThrow(/TRUST_PROXY/);
    });

    it('production boots with a real salt and a hop count', () => {
      const env = loadEnv({ ...base, NODE_ENV: 'production', CONSENT_IP_SALT: salt, TRUST_PROXY: '1' });
      expect(env.NODE_ENV).toBe('production');
      expect(env.TRUST_PROXY).toBe('1');
    });

    it('rejects a malformed TRUST_PROXY in any environment', () => {
      expect(() => loadEnv({ ...base, TRUST_PROXY: 'the proxy' })).toThrow(/TRUST_PROXY/);
    });
  });

  describe('parseTrustProxy', () => {
    it.each([
      [undefined, true],
      ['true', true],
      ['false', false],
      ['1', 1],
      ['2', 2],
      ['127.0.0.1', ['127.0.0.1']],
      ['loopback, 10.0.0.0/8', ['loopback', '10.0.0.0/8']],
    ] as const)('%s → %j', (raw, expected) => {
      expect(parseTrustProxy(raw)).toEqual(expected);
    });
  });
});
