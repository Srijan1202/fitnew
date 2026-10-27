/**
 * Running (beta 4.0, ADR-038): what a run adds up to, computed from its
 * stored track — the server's record. The phone computes the same numbers
 * with the same rules while you run and for an offline summary; the shared
 * fixtures in test/fixtures/running hold both to these figures.
 *
 *  - Distance: the great-circle distance between consecutive points of a
 *    segment. The gap across a pause adds nothing.
 *  - Time: the run's active seconds as the phone's timer counted them (the
 *    clock you saw while running, pauses excluded). Pace is that time over
 *    the distance. Splits and the chart use the track's own times.
 *  - Elevation gain: climbs of at least [CLIMB_THRESHOLD_M] above the lowest
 *    point since the last counted climb, so GPS noise on the flat adds
 *    nothing.
 *  - Calories: the ACSM metabolic equations (gross, level ground) at each
 *    step's speed, times body weight: walking below [WALK_BELOW_M_PER_MIN],
 *    running above. Without a weight there is no figure.
 */
import { haversine, type Track } from './track.js';

/** Metres per mile. */
export const MILE_M = 1609.344;
/** Below this the distance is too short for a pace. */
export const MIN_PACE_DISTANCE_M = 10;
/** Elevation hysteresis, metres. */
export const CLIMB_THRESHOLD_M = 5;
/** ACSM: the walking equation below 6 km/h, the running one above. */
export const WALK_BELOW_M_PER_MIN = 100;
/** Speeds above 24 km/h are taken as 24 km/h for calories (a GPS spike). */
export const MAX_CALORIE_SPEED_M_PER_MIN = 400;
/** The chart: one bucket per 50 m, at most 100. */
export const SERIES_BUCKET_M = 50;
export const SERIES_MAX_BUCKETS = 100;
/** The history list's route outline: at most this many points. */
export const OUTLINE_MAX_POINTS = 64;
/** The last split counts only from this distance. */
export const MIN_LAST_SPLIT_M = 10;

/** One split. `pace` is seconds per unit (per km or per mile). */
export interface Split {
  readonly index: number;
  readonly distanceM: number;
  readonly seconds: number;
  readonly pace: number;
  /** Metres up (+) or down (−) over the split; null without elevation. */
  readonly elevationChangeM: number | null;
}

/** One chart bucket: where it ends, its pace and the elevation there. */
export interface SeriesPoint {
  readonly distanceM: number;
  /** Seconds per km over the bucket. */
  readonly pace: number;
  readonly ele: number | null;
}

export interface RunSummary {
  readonly distanceM: number;
  readonly durationSeconds: number;
  /** Seconds per km; null under [MIN_PACE_DISTANCE_M]. */
  readonly avgPaceSecPerKm: number | null;
  readonly elevationGainM: number | null;
  readonly calories: number | null;
  readonly splitsKm: readonly Split[];
  readonly splitsMi: readonly Split[];
  readonly series: readonly SeriesPoint[];
  /** [lat, lon] pairs, 5 decimals, for the history list. */
  readonly outline: readonly (readonly [number, number])[];
}

/** The track flattened with running totals: what every rule below reads. */
interface Profile {
  /** Metres from the start at each point (the pause gaps add nothing). */
  readonly d: number[];
  /** Moving seconds from the start at each point. */
  readonly m: number[];
  readonly ele: (number | null)[];
  readonly lat: number[];
  readonly lon: number[];
}

function profileOf(track: Track): Profile {
  const p: Profile = { d: [], m: [], ele: [], lat: [], lon: [] };
  let d = 0;
  let m = 0;
  for (const segment of track.segments) {
    segment.forEach((pt, i) => {
      if (i > 0) {
        const prev = segment[i - 1]!;
        d += haversine(prev, pt);
        m += pt.t - prev.t;
      }
      p.d.push(d);
      p.m.push(m);
      p.ele.push(pt.ele);
      p.lat.push(pt.lat);
      p.lon.push(pt.lon);
    });
  }
  return p;
}

/** The moving time and elevation where the run reached `x` metres (linear between points). */
function at(p: Profile, x: number): { m: number; ele: number | null } {
  // The first point at or past x; the profile always reaches x here.
  let j = 0;
  while (p.d[j]! < x) j++;
  if (j === 0 || p.d[j] === p.d[j - 1]) return { m: p.m[j]!, ele: p.ele[j]! };
  const i = j - 1;
  const f = (x - p.d[i]!) / (p.d[j]! - p.d[i]!);
  const ei = p.ele[i]!;
  const ej = p.ele[j]!;
  return { m: p.m[i]! + f * (p.m[j]! - p.m[i]!), ele: ei === null || ej === null ? null : ei + f * (ej - ei) };
}

const round1 = (x: number) => Math.round(x * 10) / 10;

function splitsOf(p: Profile, unit: number): Split[] {
  const total = p.d[p.d.length - 1] ?? 0;
  const out: Split[] = [];
  let from = at(p, 0);
  let start = 0;
  for (let k = 1; start < total; k++) {
    const end = Math.min(k * unit, total);
    const dist = end - start;
    if (end === total && end < k * unit && dist < MIN_LAST_SPLIT_M) break;
    const to = at(p, end);
    const seconds = to.m - from.m;
    out.push({
      index: k,
      distanceM: round1(dist),
      seconds: round1(seconds),
      pace: round1(seconds / (dist / unit)),
      elevationChangeM: from.ele === null || to.ele === null ? null : round1(to.ele - from.ele),
    });
    from = to;
    start = end;
  }
  return out;
}

function seriesOf(p: Profile): SeriesPoint[] {
  const total = p.d[p.d.length - 1] ?? 0;
  const n = Math.min(SERIES_MAX_BUCKETS, Math.floor(total / SERIES_BUCKET_M));
  if (n < 1) return [];
  const w = total / n;
  const out: SeriesPoint[] = [];
  let from = at(p, 0);
  for (let k = 1; k <= n; k++) {
    const to = at(p, k === n ? total : k * w);
    out.push({ distanceM: round1(k === n ? total : k * w), pace: round1((to.m - from.m) / (w / 1000)), ele: to.ele === null ? null : round1(to.ele) });
    from = to;
  }
  return out;
}

/** Elevation gain with [CLIMB_THRESHOLD_M] hysteresis; null when no point has elevation. */
export function elevationGain(track: Track): number | null {
  const all = track.segments.flat().map((p) => p.ele).filter((e): e is number => e !== null);
  if (all.length === 0) return null;
  let gain = 0;
  let base = all[0]!;
  for (const e of all) {
    if (e < base) base = e;
    else if (e - base >= CLIMB_THRESHOLD_M) {
      gain += e - base;
      base = e;
    }
  }
  return round1(gain);
}

/** ACSM gross VO2 (ml/kg/min) at a speed in metres a minute, level ground. */
export function vo2At(metresPerMinute: number): number {
  const s = Math.min(metresPerMinute, MAX_CALORIE_SPEED_M_PER_MIN);
  return s < WALK_BELOW_M_PER_MIN ? 0.1 * s + 3.5 : 0.2 * s + 3.5;
}

/** kcal for `seconds` at a speed: VO2 × kg ÷ 1000 L/min × 5 kcal/L. */
export function kcalAt(metresPerMinute: number, seconds: number, weightKg: number): number {
  return ((vo2At(metresPerMinute) * weightKg) / 1000) * 5 * (seconds / 60);
}

function caloriesOf(track: Track, weightKg: number): number {
  let kcal = 0;
  for (const segment of track.segments) {
    for (let i = 1; i < segment.length; i++) {
      const a = segment[i - 1]!;
      const b = segment[i]!;
      const dt = b.t - a.t;
      kcal += kcalAt((haversine(a, b) / dt) * 60, dt, weightKg);
    }
  }
  return kcal;
}

function outlineOf(p: Profile): [number, number][] {
  const n = p.lat.length;
  if (n === 0) return [];
  const take = Math.min(n, OUTLINE_MAX_POINTS);
  const out: [number, number][] = [];
  for (let k = 0; k < take; k++) {
    const i = take === 1 ? 0 : Math.round((k * (n - 1)) / (take - 1));
    out.push([Math.round(p.lat[i]! * 1e5) / 1e5, Math.round(p.lon[i]! * 1e5) / 1e5]);
  }
  return out;
}

const paceOf = (durationSeconds: number, distanceM: number) =>
  distanceM < MIN_PACE_DISTANCE_M ? null : round1(durationSeconds / (distanceM / 1000));

/** An outdoor run: everything from its track; time from the phone's timer. */
export function summarizeTrack(track: Track, durationSeconds: number, weightKg: number | null): RunSummary {
  const p = profileOf(track);
  const distanceM = round1(p.d[p.d.length - 1] ?? 0);
  return {
    distanceM,
    durationSeconds,
    avgPaceSecPerKm: paceOf(durationSeconds, distanceM),
    elevationGainM: elevationGain(track),
    calories: weightKg === null ? null : Math.round(caloriesOf(track, weightKg)),
    splitsKm: splitsOf(p, 1000),
    splitsMi: splitsOf(p, MILE_M),
    series: seriesOf(p),
    outline: outlineOf(p),
  };
}

/** A treadmill run: the distance typed at the end, an even pace. */
export function summarizeTreadmill(distanceM: number, durationSeconds: number, weightKg: number | null): RunSummary {
  const speed = durationSeconds > 0 ? (distanceM / durationSeconds) * 60 : 0;
  return {
    distanceM: round1(distanceM),
    durationSeconds,
    avgPaceSecPerKm: paceOf(durationSeconds, distanceM),
    elevationGainM: null,
    calories: weightKg === null ? null : Math.round(kcalAt(speed, durationSeconds, weightKg)),
    splitsKm: [],
    splitsMi: [],
    series: [],
    outline: [],
  };
}
