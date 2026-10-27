/**
 * Running (beta 4.1, ADR-039): the laps of a structured run — each step of a
 * workout, from where it began to where it ended on the run's own clock —
 * measured on the track with the same rules as a run's summary.
 *
 * The phone records only the boundaries (seconds since the start, the same
 * clock as the track's points). Distance between two times is interpolated
 * inside a segment; a pause adds neither distance nor time.
 */
import { haversine, type Track } from './track.js';

export interface LapMark {
  /** The workout step this lap is (0-based). */
  readonly step: number;
  readonly startT: number;
  readonly endT: number;
}

export interface Lap {
  readonly step: number;
  readonly distanceM: number;
  /** Moving seconds inside the lap. */
  readonly seconds: number;
  /** Seconds per km; null under 10 m. */
  readonly pace: number | null;
}

/** A run holds at most this many laps. */
export const MAX_LAPS = 120;

const round1 = (x: number) => Math.round(x * 10) / 10;

interface Stretch {
  readonly t0: number;
  readonly t1: number;
  readonly d: number;
}

/** Each step between two points of a segment: its times and distance. */
function stretches(track: Track): Stretch[] {
  const out: Stretch[] = [];
  for (const s of track.segments) {
    for (let i = 1; i < s.length; i++) out.push({ t0: s[i - 1]!.t, t1: s[i]!.t, d: haversine(s[i - 1]!, s[i]!) });
  }
  return out;
}

/** Distance and moving time between two clock times (the overlap with each stretch, pro rata). */
function between(all: readonly Stretch[], from: number, to: number): { d: number; m: number } {
  let d = 0;
  let m = 0;
  for (const s of all) {
    const lo = Math.max(from, s.t0);
    const hi = Math.min(to, s.t1);
    if (hi <= lo) continue;
    const f = (hi - lo) / (s.t1 - s.t0);
    d += f * s.d;
    m += hi - lo;
  }
  return { d, m };
}

export function lapsOf(track: Track, marks: readonly LapMark[]): Lap[] {
  const all = stretches(track);
  return marks.map((mk) => {
    const { d, m } = between(all, mk.startT, mk.endT);
    const distanceM = round1(d);
    return { step: mk.step, distanceM, seconds: round1(m), pace: distanceM < 10 ? null : round1(m / (d / 1000)) };
  });
}

export class LapError extends Error {
  override readonly name = 'LapError';
}

/** Marks in order, each ending after it starts, none overlapping the next, at most [MAX_LAPS]. */
export function checkMarks(marks: readonly LapMark[], stepCount: number): void {
  if (marks.length > MAX_LAPS) throw new LapError(`A run holds at most ${MAX_LAPS} laps.`);
  marks.forEach((m, i) => {
    if (!Number.isInteger(m.step) || m.step < 0 || m.step >= stepCount) throw new LapError('A lap names a step the workout does not have.');
    if (!(m.endT >= m.startT) || m.startT < 0) throw new LapError('A lap ends before it starts.');
    if (i > 0 && m.startT < marks[i - 1]!.endT) throw new LapError('Laps overlap.');
  });
}
