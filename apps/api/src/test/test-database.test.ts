import { describe, expect, it } from 'vitest';

import { resolveTestDatabaseUrl, UnsafeTestDatabaseError } from './test-database.js';

describe('test database resolution (never the developer database)', () => {
  it('derives <name>_test from DATABASE_URL', () => {
    expect(resolveTestDatabaseUrl({ DATABASE_URL: 'postgres://fitos:fitos@localhost:5432/fitos' })).toBe(
      'postgres://fitos:fitos@localhost:5432/fitos_test',
    );
  });

  it('leaves a DATABASE_URL that already ends in _test alone', () => {
    expect(resolveTestDatabaseUrl({ DATABASE_URL: 'postgres://u:p@h:5432/fitos_test' })).toBe('postgres://u:p@h:5432/fitos_test');
  });

  it('prefers an explicit TEST_DATABASE_URL', () => {
    expect(
      resolveTestDatabaseUrl({ DATABASE_URL: 'postgres://u:p@h:5432/fitos', TEST_DATABASE_URL: 'postgres://u:p@h:5432/other_test' }),
    ).toBe('postgres://u:p@h:5432/other_test');
  });

  it('refuses an explicit test database whose name does not end in _test', () => {
    expect(() => resolveTestDatabaseUrl({ TEST_DATABASE_URL: 'postgres://u:p@h:5432/fitos' })).toThrow(UnsafeTestDatabaseError);
  });

  it('is undefined with neither variable, so integration suites skip', () => {
    expect(resolveTestDatabaseUrl({})).toBeUndefined();
    expect(resolveTestDatabaseUrl({ DATABASE_URL: '' })).toBeUndefined();
  });
});
