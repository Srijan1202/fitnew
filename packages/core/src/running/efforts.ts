/**
 * Running (beta 4.2): best efforts — the fastest stretch of each standard
 * distance inside a run, not only whole runs (owner 2026-10-29).
 *
 *  - Distance and time are the run's own rules (summary.ts): the distance
 *    between the points of a segment, and moving time — a pause adds
 *    neither, so a best 5 km is never slower than the splits of the same
 *    stretch (owner: pauses do not count).
 *  - A stretch is exact: where it starts or ends between two points, the
 *    time there is interpolated. The fastest stretch of a given length
 *    always starts or ends on a point (between points the time it takes
 *    changes linearly), so both are tried, each with two pointers: one pass
 *    per distance, a few milliseconds for a marathon's points.
 *  - Faster than the world record is not a run (a GPS jump, a car): that
 *    distance is left out for that run. The run is otherwise unchanged.
 *
 * The phone runs the same rules (a Dart port) to say "New record" the
 * moment a run ends; the server's figures stand once it syncs.
 */
import { MILE_M } from './summary.js';
import { haversine, type Track } from './track.js';

/** Which rules made a run's efforts: a change re-works old runs. */
export const EFFORTS_VERSION = 1;

export interface EffortDistance {
  readonly key: EffortKey;
  readonly metres: number;
  readonly label: string;
  /** The world record, rounded down: anything faster is not a run. */
  readonly recordSeconds: number;
}

export const EFFORT_KEYS = ['400m', '1k', '1mile', '5k', '10k', 'half', 'marathon'] as const;
export type EffortKey = (typeof EFFORT_KEYS)[number];

export const EFFORT_DISTANCES: readonly EffortDistance[] = [
  { key: '400m', metres: 400, label: '400 m', recordSeconds: 43 },
  { key: '1k', metres: 1000, label: '1 km', recordSeconds: 131 },
  { key: '1mile', metres: MILE_M, label: '1 mile', recordSeconds: 223 },
  { key: '5k', metres: 5000, label: '5 km', recordSeconds: 755 },
  { key: '10k', metres: 10_000, label: '10 km', recordSeconds: 1571 },
  { key: 'half', metres: 21_097.5, label: 'Half marathon', recordSeconds: 3400 },
  { key: 'marathon', metres: 42_195, label: 'Marathon', recordSeconds: 7200 },
];

export interface BestEffort {
  readonly key: EffortKey;
  /** Moving seconds, to 0.1 s. */
  readonly seconds: number;
  /** Where the stretch starts, in metres from the start of the run. */
  readonly startM: number;
}

const round1 = (x: number) => Math.round(x * 10) / 10;

/** Metres and moving seconds from the start at every point. */
function profileOf(track: Track): { d: number[]; m: number[] } {
  const d: number[] = [];
  const m: number[] = [];
  let dist = 0;
  let moving = 0;
  for (const segment of track.segments) {
    segment.forEach((pt, i) => {
      if (i > 0) {
        const prev = segment[i - 1]!;
        dist += haversine(prev, pt);
        moving += pt.t - prev.t;
      }
      d.push(dist);
      m.push(moving);
    });
  }
  return { d, m };
}

/**
 * Moving seconds at [target] metres, between points j-1 and j, where
 * d[j-1] < target <= d[j].
 */
function timeAt(d: readonly number[], m: readonly number[], j: number, target: number): number {
  const f = (target - d[j - 1]!) / (d[j]! - d[j - 1]!);
  return m[j - 1]! + f * (m[j]! - m[j - 1]!);
}

/** The fastest stretch of [metres] in the profile, or null when the run is shorter. */
export function fastest(d: readonly number[], m: readonly number[], metres: number): { seconds: number; startM: number } | null {
  const n = d.length;
  if (n < 2 || d[n - 1]! < metres) return null;
  let best = Infinity;
  let bestStart = 0;

  // Starting on a point: the end is interpolated.
  let j = 1;
  for (let i = 0; i < n; i++) {
    const target = d[i]! + metres;
    if (target > d[n - 1]!) break;
    while (d[j]! < target) j++;
    const end = d[j] === target ? m[j]! : timeAt(d, m, j, target);
    if (end - m[i]! < best) {
      best = end - m[i]!;
      bestStart = d[i]!;
    }
  }

  // Ending on a point: the start is interpolated.
  let k = 1;
  for (let e = 0; e < n; e++) {
    const target = d[e]! - metres;
    if (target < 0) continue;
    while (d[k]! < target) k++;
    const start = d[k] === target ? m[k]! : timeAt(d, m, k, target);
    if (m[e]! - start < best) {
      best = m[e]! - start;
      bestStart = target;
    }
  }
  return { seconds: best, startM: bestStart };
}

/** Every standard distance the run covers, at its fastest. */
export function bestEfforts(track: Track): BestEffort[] {
  const { d, m } = profileOf(track);
  const out: BestEffort[] = [];
  for (const dist of EFFORT_DISTANCES) {
    const f = fastest(d, m, dist.metres);
    if (f === null || f.seconds < dist.recordSeconds) continue;
    out.push({ key: dist.key, seconds: round1(f.seconds), startM: round1(f.startM) });
  }
  return out;
}

/* ---------------------------------------------------------------- badges -- */

/**
 * Beta 4.2 (owner): the distance firsts. One run must cover the distance by
 * its own figure; a treadmill run counts. [slackM]: a run shown as "5.00 km"
 * (4.995 km and up, to two decimals) reads as 5 km, so it earns the badge.
 */
export const BADGE_SLACK_M = 5;

export const DISTANCE_BADGES = [
  { id: 'first-run', metres: 0, name: 'First run', reward: null },
  { id: 'first-5k', metres: 5000, name: 'First 5K', reward: null },
  { id: 'first-10k', metres: 10_000, name: 'First 10K', reward: 'Finisher app icon' },
  { id: 'first-half', metres: 21_097.5, name: 'First half marathon', reward: 'Road theme' },
  { id: 'first-marathon', metres: 42_195, name: 'First marathon', reward: 'gold 42 app icon' },
] as const;
export type DistanceBadgeId = (typeof DISTANCE_BADGES)[number]['id'];

/** The badges one run of [distanceM] earns (a run of any length is a first run). */
export function badgesFor(distanceM: number): DistanceBadgeId[] {
  return DISTANCE_BADGES.filter((b) => b.metres === 0 || distanceM >= b.metres - BADGE_SLACK_M).map((b) => b.id);
}
