/**
 * Audit 2026-10-20: drizzle-orm 0.44+ wraps driver errors (`DrizzleQueryError`
 * with the PostgresError as `cause`). A unique violation must still be found
 * — otherwise a 409 (second active session, a set position taken) turns 500.
 */
import { describe, expect, it } from 'vitest';

import { isDatabaseUnavailable, uniqueViolationOf } from './errors.js';

const pg = (code: string, extra: Record<string, unknown> = {}) => Object.assign(new Error('pg'), { name: 'PostgresError', code, ...extra });

describe('uniqueViolationOf', () => {
  it('finds 23505 at the top or under one or more wrappers, with its constraint', () => {
    const bare = pg('23505', { constraint_name: 'one_active_session' });
    expect(uniqueViolationOf(bare)).toEqual({ constraint: 'one_active_session' });
    const wrapped = Object.assign(new Error('Failed query: insert ...'), { cause: bare });
    expect(uniqueViolationOf(wrapped)).toEqual({ constraint: 'one_active_session' });
    expect(uniqueViolationOf({ cause: { cause: pg('23505', { constraint: 'x' }) } })).toEqual({ constraint: 'x' });
  });

  it('anything else is not a unique violation', () => {
    expect(uniqueViolationOf(pg('23503'))).toBeNull();
    expect(uniqueViolationOf(new Error('boom'))).toBeNull();
    expect(uniqueViolationOf(null)).toBeNull();
    expect(uniqueViolationOf('23505')).toBeNull();
  });

  it('isDatabaseUnavailable still follows the same chain', () => {
    expect(isDatabaseUnavailable({ cause: pg('57P01') })).toBe(true);
    expect(isDatabaseUnavailable({ cause: pg('23505') })).toBe(false);
  });
});
