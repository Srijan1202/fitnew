/**
 * Menus from the stored mirror (Phase 9, owner D2/D5).
 *
 * The server keeps every distinct payload each endpoint has returned
 * (`mess_menu_snapshots`) and builds a day's menu from them on read, with the
 * parser in this package — there are no derived day/meal/dish tables.
 *
 * Which snapshot answers a date:
 *   1. the NEWEST snapshot that publishes the date → `exact`. MessIT edits past
 *      days after publishing them (2026-09-24 capture), so the newest version
 *      of a day is the one shown;
 *   2. otherwise the cycle, projected forward from the latest snapshot alone;
 *   3. only if that finds nothing, the cycle over the UNION of all snapshots
 *      (each date from its newest snapshot). Latest-first, because retroactive
 *      edits can make older and newer copies of the same cycle disagree — the
 *      union is a fallback for a thin latest payload, never a replacement.
 * An inferred menu is always labelled as such (§14.4).
 */
import { buildDay, resolveMenuDate } from './providers/vit/provider.js';
import type { MenuResolution, MessDay, MessItResponse } from './types.js';

/** One stored payload. Callers pass snapshots NEWEST FIRST. */
export interface MenuSnapshot {
  readonly id: string;
  readonly payload: MessItResponse;
}

export interface SnapshotDay {
  readonly day: MessDay;
  /** The snapshot whose text the menu shows; null when unavailable. */
  readonly snapshotId: string | null;
}

function publishes(payload: MessItResponse, date: string): boolean {
  return payload.menu.some((d) => d.date === date);
}

/** Every date from its newest snapshot. Input newest first. */
export function mergeSnapshots(snapshots: readonly MenuSnapshot[]): MessItResponse {
  const first = snapshots[0];
  if (first === undefined) return { hostel: 0, mess: 0, menu: [] };
  const seen = new Set<string>();
  const menu: MessItResponse['menu'][number][] = [];
  for (const s of snapshots) {
    for (const day of s.payload.menu) {
      if (seen.has(day.date)) continue;
      seen.add(day.date);
      menu.push(day);
    }
  }
  return { hostel: first.payload.hostel, mess: first.payload.mess, menu };
}

/** The last date any snapshot publishes, or null. */
export function latestPublishedDate(snapshots: readonly MenuSnapshot[]): string | null {
  let latest: string | null = null;
  for (const s of snapshots) {
    for (const d of s.payload.menu) if (latest === null || d.date > latest) latest = d.date;
  }
  return latest;
}

function newestPublishing(snapshots: readonly MenuSnapshot[], date: string): MenuSnapshot | null {
  return snapshots.find((s) => publishes(s.payload, date)) ?? null;
}

function unavailable(date: string, snapshots: readonly MenuSnapshot[]): SnapshotDay {
  const resolution: MenuResolution = { kind: 'unavailable', date, latestAvailable: latestPublishedDate(snapshots) };
  return { day: { date, meals: [], resolution }, snapshotId: null };
}

/**
 * The menu for `date` from the stored snapshots (newest first). Never throws:
 * no snapshots, or no published or inferable menu, is `unavailable`.
 */
export function resolveDayFromSnapshots(
  snapshots: readonly MenuSnapshot[],
  date: string,
  servesNonVeg: boolean,
): SnapshotDay {
  const latest = snapshots[0];
  if (latest === undefined) return unavailable(date, snapshots);

  const exact = newestPublishing(snapshots, date);
  if (exact !== null) return { day: buildDay(exact.payload, date, servesNonVeg), snapshotId: exact.id };

  const fromLatest = resolveMenuDate(latest.payload, date);
  if (fromLatest.kind === 'cycle-inferred') {
    return { day: buildDay(latest.payload, date, servesNonVeg), snapshotId: latest.id };
  }

  if (snapshots.length > 1) {
    const merged = mergeSnapshots(snapshots);
    const fromAll = resolveMenuDate(merged, date);
    if (fromAll.kind === 'cycle-inferred') {
      const source = newestPublishing(snapshots, fromAll.sourceDate);
      return { day: buildDay(merged, date, servesNonVeg), snapshotId: source?.id ?? null };
    }
  }
  return unavailable(date, snapshots);
}
