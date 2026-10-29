/**
 * Beta 4.2 (owner 2026-10-29): best efforts and the distance badges — every
 * rule and branch (§26.1).
 */
import { describe, expect, it } from 'vitest';

import {
  BADGE_SLACK_M,
  DISTANCE_BADGES,
  EFFORT_DISTANCES,
  EFFORT_KEYS,
  EFFORTS_VERSION,
  badgesFor,
  bestEfforts,
  fastest,
} from '../src/running/efforts.js';
import { MILE_M } from '../src/running/summary.js';
import { type Track, type TrackPoint } from '../src/running/track.js';

/** Metres per degree of latitude (the haversine's own radius). */
const M_PER_DEG = (Math.PI / 180) * 6_371_008.8;

/**
 * A straight run north: [paces] seconds per km for each successive km
 * stretch of [stepM] metres, from [t0] and [m0] metres. The last pace
 * holds to [totalM].
 */
function run(totalM: number, stepM: number, pace: (atM: number) => number, t0 = 0, m0 = 0): TrackPoint[] {
  const pts: TrackPoint[] = [];
  let t = t0;
  for (let m = 0; m <= totalM + 1e-9; m += stepM) {
    if (m > 0) t += (stepM / 1000) * pace(m0 + m - stepM / 2);
    pts.push({ t, lat: (m0 + m) / M_PER_DEG, lon: 0, ele: null });
  }
  return pts;
}

const effort = (track: Track, key: string) => bestEfforts(track).find((e) => e.key === key);

describe('the distances', () => {
  it('are the seven, in order, each under its world record', () => {
    expect(EFFORT_DISTANCES.map((d) => d.key)).toEqual([...EFFORT_KEYS]);
    expect(EFFORT_DISTANCES.find((d) => d.key === '1mile')!.metres).toBe(MILE_M);
    expect(EFFORT_DISTANCES.find((d) => d.key === 'marathon')!.metres).toBe(42_195);
    expect(EFFORTS_VERSION).toBe(1);
  });
});

describe('best efforts', () => {
  it('a steady 10 km at 5:00 /km: each distance at that pace', () => {
    const track: Track = { segments: [run(10_010, 10, () => 300)] };
    const all = bestEfforts(track);
    expect(all.map((e) => e.key)).toEqual(['400m', '1k', '1mile', '5k', '10k']);
    expect(effort(track, '400m')!.seconds).toBeCloseTo(120, 0);
    expect(effort(track, '1k')!.seconds).toBeCloseTo(300, 0);
    expect(effort(track, '1mile')!.seconds).toBeCloseTo(482.8, 0);
    expect(effort(track, '5k')!.seconds).toBeCloseTo(1500, 0);
    expect(effort(track, '10k')!.seconds).toBeCloseTo(3000, 0);
  });

  it('finds the fast kilometre in the middle, where it is', () => {
    // 3 km: the second at 4:00, the others at 6:00.
    const track: Track = { segments: [run(3000, 10, (m) => (m >= 1000 && m < 2000 ? 240 : 360))] };
    const km = effort(track, '1k')!;
    expect(km.seconds).toBeCloseTo(240, 0);
    expect(km.startM).toBeCloseTo(1000, -1);
  });

  it('is exact between points: interpolated at both ends', () => {
    // Points 300 m apart; the fastest km starts and ends between points.
    const track: Track = { segments: [run(3000, 300, (m) => (m >= 900 && m < 2100 ? 240 : 360))] };
    // 1,000 m inside the 1,200 m at 4:00 /km is 240 s exactly.
    expect(effort(track, '1k')!.seconds).toBeCloseTo(240, 1);
  });

  it('a pause adds no time: two stretches either side of a 10-minute stop', () => {
    const first = run(2510, 10, () => 300);
    const last = first[first.length - 1]!;
    const second = run(2510, 10, () => 300, last.t + 600, 2510).slice(1);
    const track: Track = { segments: [first, [{ ...last, t: last.t + 600 }, ...second]] };
    expect(effort(track, '5k')!.seconds).toBeCloseTo(1500, 0);
  });

  it('faster than the world record is left out (a GPS jump), the rest kept', () => {
    // 6 km at 5:00 /km with 400 m covered in 4 s at 3 km.
    const pts = run(6000, 10, () => 300);
    const jumped = pts.map((p, i) => (i <= 300 ? p : { ...p, t: p.t - 116 }));
    const track: Track = { segments: [jumped] };
    expect(effort(track, '400m')).toBeUndefined();
    expect(effort(track, '5k')).toBeDefined();
  });

  it('a run shorter than a distance has no effort for it; none at all under 400 m', () => {
    expect(bestEfforts({ segments: [run(390, 10, () => 300)] })).toEqual([]);
    expect(bestEfforts({ segments: [] })).toEqual([]);
    expect(bestEfforts({ segments: [run(1200, 10, () => 300)] }).map((e) => e.key)).toEqual(['400m', '1k']);
  });
});

describe('fastest (on distances and moving times)', () => {
  it('a stretch that starts or ends exactly on a point', () => {
    // 0, 400, 800 m at 100 s and 90 s: the second 400 m is the fastest.
    expect(fastest([0, 400, 800], [0, 100, 190], 400)).toEqual({ seconds: 90, startM: 400 });
    // The whole run, exactly.
    expect(fastest([0, 200, 400], [0, 60, 130], 400)).toEqual({ seconds: 130, startM: 0 });
  });

  it('standing still at the start (two points at 0 m)', () => {
    expect(fastest([0, 0, 500], [0, 20, 170], 400)).toEqual({ seconds: 120, startM: 0 });
  });

  it('too few points, or too short', () => {
    expect(fastest([0], [0], 400)).toBeNull();
    expect(fastest([0, 300], [0, 90], 400)).toBeNull();
  });
});

describe('distance badges', () => {
  it('the five, three with a reward', () => {
    expect(DISTANCE_BADGES.map((b) => b.id)).toEqual(['first-run', 'first-5k', 'first-10k', 'first-half', 'first-marathon']);
    expect(DISTANCE_BADGES.filter((b) => b.reward !== null).map((b) => b.id)).toEqual(['first-10k', 'first-half', 'first-marathon']);
  });

  it('any run is a first run; a distance counts from what reads as it', () => {
    expect(badgesFor(0)).toEqual(['first-run']);
    expect(badgesFor(5000 - BADGE_SLACK_M - 0.1)).toEqual(['first-run']);
    expect(badgesFor(5000 - BADGE_SLACK_M)).toEqual(['first-run', 'first-5k']);
    expect(badgesFor(21_097.5)).toEqual(['first-run', 'first-5k', 'first-10k', 'first-half']);
    expect(badgesFor(42_195)).toHaveLength(5);
  });
});
