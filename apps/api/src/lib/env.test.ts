import { describe, expect, it } from 'vitest';
import { loadEnv } from './env.js';

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
});
