/**
 * Phase 6.7 — "the database cannot be reached" versus "our bug".
 *
 * A connection that is refused, reset or timed out, a Postgres that is
 * shutting down or out of connection slots, a Neon compute that was suspended
 * under an idle connection: none of these is a defect in the request. They
 * answer 503 UPSTREAM_UNAVAILABLE (a temporary condition the client waits out)
 * instead of 500 INTERNAL (a failure the phone's sync queue counts towards
 * parking the entry).
 */

/** Node socket / DNS failures while reaching the database host. */
const NETWORK_CODES = new Set([
  'ECONNREFUSED',
  'ECONNRESET',
  'ETIMEDOUT',
  'EPIPE',
  'ENOTFOUND',
  'EAI_AGAIN',
  'EHOSTUNREACH',
  'ENETUNREACH',
]);

/** postgres.js's own codes for a connection it lost or could not open. */
const DRIVER_CODES = new Set(['CONNECTION_CLOSED', 'CONNECTION_ENDED', 'CONNECTION_DESTROYED', 'CONNECT_TIMEOUT']);

/**
 * SQLSTATEs that mean "not available right now": class 08 (connection
 * exception), 57P01 admin_shutdown, 57P02 crash_shutdown, 57P03
 * cannot_connect_now, 53300 too_many_connections.
 */
function unavailableSqlState(code: string): boolean {
  return /^08[0-9A-Z]{3}$/.test(code) || ['57P01', '57P02', '57P03', '53300'].includes(code);
}

export function isDatabaseUnavailable(error: unknown): boolean {
  let current: unknown = error;
  // Drivers and ORMs wrap; follow `cause` a few levels, never forever.
  for (let depth = 0; depth < 5 && current !== null && typeof current === 'object'; depth += 1) {
    const code = (current as { code?: unknown }).code;
    if (typeof code === 'string') {
      if (NETWORK_CODES.has(code) || DRIVER_CODES.has(code)) return true;
      const isPostgresError = (current as { name?: unknown }).name === 'PostgresError';
      if (isPostgresError && unavailableSqlState(code)) return true;
    }
    current = (current as { cause?: unknown }).cause;
  }
  return false;
}
