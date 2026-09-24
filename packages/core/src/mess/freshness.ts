/**
 * How fresh the server's copy of a mess menu is (Phase 9, owner D19).
 *
 * Two separate questions, shown separately:
 *   - is OUR COPY fresh? — when the mirror last fetched the endpoint
 *     successfully. No success within 24 h is `stale`;
 *   - does THE MESS publish this date? — the menu's resolution (exact /
 *     cycle-inferred / unavailable), decided in `snapshots.ts`.
 * MessIT has no timestamp or version of its own, so the first is all we know.
 */
export const MIRROR_STALE_AFTER_HOURS = 24;

export function isMirrorStale(lastSuccessAt: Date | null, now: Date): boolean {
  if (lastSuccessAt === null) return true;
  return now.getTime() - lastSuccessAt.getTime() > MIRROR_STALE_AFTER_HOURS * 3_600_000;
}
