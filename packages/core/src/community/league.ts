/**
 * Beta 6.6 (L1, owner 2026-11-25): the club league. Clubs of 3 or more enter;
 * seasons are 4 weeks, Monday to Sunday, back to back; each Saturday (UTC)
 * every entered club without a match is paired for the coming week with a
 * club of a similar average per member, never a rematch in the season when
 * avoidable and never across a block. A win is 3 points, a draw 1, and a bye
 * counts as a draw. One table (no divisions yet). Pure: the API stores.
 */
import { addDays } from '../nutrition/log.js';
import { isoWeekday } from '../progress/streak.js';
import type { ChallengeMetric } from './challenge.js';
import type { MatchResult } from './match.js';

/** Owner Q1: league matches count active days per member, fair to gym-goers and runners. */
export const LEAGUE_METRIC: ChallengeMetric = 'active-days';
/** Owner Q2. */
export const LEAGUE_MIN_MEMBERS = 3;
/** Owner Q3. */
export const LEAGUE_SEASON_WEEKS = 4;
/** The club page shows the top 5 and the club's own row. */
export const LEAGUE_TABLE_SHOWN = 5;

export const POINTS: Record<MatchResult | 'bye', number> = { won: 3, drew: 1, lost: 0, bye: 1 };

/** A season's last day (a Sunday). */
export const seasonEnd = (from: string): string => addDays(from, 7 * LEAGUE_SEASON_WEEKS - 1);

/** Whether `weekFrom` falls inside the season that starts on `from`. */
export const inSeason = (from: string, weekFrom: string): boolean => weekFrom >= from && weekFrom <= seasonEnd(from);

/** The season after the one starting on `from`. */
export const nextSeasonFrom = (from: string): string => addDays(from, 7 * LEAGUE_SEASON_WEEKS);

/** Pairing happens on Saturdays, in UTC. */
export const isPairingDay = (utcToday: string): boolean => isoWeekday(utcToday) === 6;

/** Which week of its season a week is: 1 to 4. */
export const seasonWeek = (from: string, weekFrom: string): number => Math.round((Date.parse(weekFrom) - Date.parse(from)) / (7 * 86_400_000)) + 1;

export interface LeagueClub {
  readonly id: string;
  /** The club's average per member over its last 4 weeks, for pairing like with like. */
  readonly avg: number;
  /** Byes so far this season. */
  readonly byes: number;
}

export interface Pairing {
  readonly pairs: readonly (readonly [string, string])[];
  /** Clubs that sit the week out with a bye (one for an odd count, or any that could not be paired). */
  readonly byes: readonly string[];
}

const pairKey = (a: string, b: string): string => (a < b ? `${a}|${b}` : `${b}|${a}`);

/**
 * Pairs the clubs for a week. With an odd number, the club with the fewest
 * byes (then the lowest id) has the bye. The rest go by average, highest
 * first: each takes the nearest club below it that it has not met this
 * season and is not blocked from; failing that, the nearest it is not blocked
 * from; failing that, it has a bye.
 */
export function pairClubs(clubs: readonly LeagueClub[], met: ReadonlySet<string>, blocked: (a: string, b: string) => boolean): Pairing {
  const byes: string[] = [];
  let pool = [...clubs];
  if (pool.length % 2 === 1) {
    const bye = [...pool].sort((a, b) => a.byes - b.byes || a.id.localeCompare(b.id))[0]!;
    byes.push(bye.id);
    pool = pool.filter((c) => c.id !== bye.id);
  }
  pool.sort((a, b) => b.avg - a.avg || a.id.localeCompare(b.id));
  const taken = new Set<string>();
  const pairs: [string, string][] = [];
  for (const c of pool) {
    if (taken.has(c.id)) continue;
    const rest = pool.filter((o) => o.id !== c.id && !taken.has(o.id) && !blocked(c.id, o.id));
    const pick = rest.find((o) => !met.has(pairKey(c.id, o.id))) ?? rest[0];
    taken.add(c.id);
    if (pick === undefined) {
      byes.push(c.id);
      continue;
    }
    taken.add(pick.id);
    pairs.push([c.id, pick.id]);
  }
  return { pairs, byes };
}

/** The set of pairs already played this season, for [pairClubs]. */
export const metSet = (pairs: readonly (readonly [string, string])[]): Set<string> => new Set(pairs.map(([a, b]) => pairKey(a, b)));

export interface TableRow {
  readonly clubId: string;
  readonly name: string;
  readonly played: number;
  readonly won: number;
  readonly drawn: number;
  readonly lost: number;
  readonly points: number;
  /** The sum of the club's per-member scores this season (the tie-break, as an average per match). */
  readonly scoreSum: number;
}

const avgOf = (r: TableRow): number => (r.played === 0 ? 0 : r.scoreSum / r.played);

/**
 * The table: points, then the average per member per match, then the fewer
 * matches, then the name. Clubs level on all three share a place.
 */
export function leagueOrder<T extends TableRow>(rows: readonly T[]): (T & { place: number })[] {
  const sorted = [...rows].sort((a, b) => b.points - a.points || avgOf(b) - avgOf(a) || a.played - b.played || a.name.localeCompare(b.name));
  const out: (T & { place: number })[] = [];
  sorted.forEach((r, i) => {
    const prev = out[i - 1];
    const level = prev !== undefined && prev.points === r.points && avgOf(prev) === avgOf(r) && prev.played === r.played;
    out.push({ ...r, place: level ? prev.place : i + 1 });
  });
  return out;
}

/** "1st", "2nd", "3rd", "11th", "22nd". */
export function ordinal(n: number): string {
  const teen = n % 100 >= 11 && n % 100 <= 13;
  const end = teen ? 'th' : ({ 1: 'st', 2: 'nd', 3: 'rd' } as Record<number, string>)[n % 10] ?? 'th';
  return `${n}${end}`;
}

/** Owner Q4: the one push at season end, to each member of an entered club. */
export const seasonEndLine = (club: string, place: number, clubs: number): { title: string; body: string } => ({
  title: `${club} finished ${ordinal(place)} in the league`,
  body: `Out of ${clubs} clubs this season. A new season starts on Monday.`,
});
