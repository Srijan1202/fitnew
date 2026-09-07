import { describe, expect, it } from 'vitest';
import { loadEnv } from './env.js';

describe('environment validation', () => {
  it('rejects a missing DATABASE_URL loudly at boot', () => {
    expect(() => loadEnv({})).toThrow(/DATABASE_URL/);
  });

  it('applies documented defaults', () => {
    const env = loadEnv({ DATABASE_URL: 'postgres://a:b@localhost:5432/c' });
    expect(env.PORT).toBe(8080);
    expect(env.NODE_ENV).toBe('development');
  });
});
