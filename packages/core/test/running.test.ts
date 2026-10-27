/**
 * Beta 4.0 (ADR-038): running — the track encoding and a run's summary,
 * every rule and branch (§26.1), and the shared fixtures the app checks too.
 */
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import {
  CLIMB_THRESHOLD_M,
  MILE_M,
  OUTLINE_MAX_POINTS,
  elevationGain,
  kcalAt,
  summarizeTrack,
  summarizeTreadmill,
  vo2At,
  type RunSummary,
} from '../src/running/summary.js';
import {
  MAX_TRACK_POINTS,
  TrackError,
  decodeTrack,
  encodeTrack,
  haversine,
  quantize,
  type EncodedTrack,
  type Track,
  type TrackPoint,
} from '../src/running/track.js';

const here = dirname(fileURLToPath(import.meta.url));

/** Metres per degree of latitude on the mean sphere. */
const M_PER_DEG = (Math.PI / 180) * 6_371_008.8;

/** Points due north from the equator, `step` metres and one second apart. */
function north(n: number, step: number, opts: { t0?: number; lat0?: number; ele?: (i: number) => number | null } = {}): TrackPoint[] {
  const out: TrackPoint[] = [];
  for (let i = 0; i < n; i++) {
    out.push({ t: (opts.t0 ?? 0) + i, lat: (opts.lat0 ?? 0) + (i * step) / M_PER_DEG, lon: 0, ele: opts.ele ? opts.ele(i) : null });
  }
  return out;
}

const roundTrip = (track: Track) => decodeTrack(encodeTrack(track));

describe('track encoding', () => {
  it('round-trips points, pauses and elevation at the kept precision', () => {
    const a = north(5, 3, { ele: (i) => 100 + i * 0.25 });
    const b = north(3, 3, { t0: 60, lat0: 0.001, ele: (i) => 99.95 - i });
    const back = roundTrip({ segments: [a, b] });
    expect(back.segments).toHaveLength(2);
    expect(back.segments[0]).toEqual(a.map(quantize));
    expect(back.segments[1]).toEqual(b.map(quantize));
  });

  it('negative coordinates and large jumps survive', () => {
    const pts: TrackPoint[] = [
      { t: 0, lat: -33.8688, lon: 151.2093, ele: -12.3 },
      { t: 1.5, lat: 40.7128, lon: -74.006, ele: 4000 },
      { t: 3, lat: -89.999999, lon: 179.999999, ele: 0 },
    ];
    expect(roundTrip({ segments: [pts] }).segments[0]).toEqual(pts);
  });

  it('quantize keeps the encoding precision, and no elevation', () => {
    expect(quantize({ t: 1.26, lat: 1.23456789, lon: -2.00000049, ele: null })).toEqual({ t: 1.3, lat: 1.234568, lon: -2, ele: null });
  });

  it('no elevation anywhere: decoded as null, encoded as zeros', () => {
    const e = encodeTrack({ segments: [north(3, 2)] });
    expect(e.elevation).toBe(false);
    expect(decodeTrack(e).segments[0]!.every((p) => p.ele === null)).toBe(true);
  });

  it('a point missing elevation in a track that has some keeps the last known (the first, before any)', () => {
    const pts = north(4, 2, { ele: (i) => [null, 10, null, 12][i]! });
    const back = roundTrip({ segments: [pts] }).segments[0]!;
    expect(back.map((p) => p.ele)).toEqual([10, 10, 10, 12]);
  });

  it('empty segments are dropped; an empty track is empty', () => {
    expect(encodeTrack({ segments: [[], north(2, 1), []] }).breaks).toEqual([]);
    expect(decodeTrack(encodeTrack({ segments: [] }))).toEqual({ segments: [] });
  });

  const good = encodeTrack({ segments: [north(3, 2), north(2, 2, { t0: 10 })] });
  const bad = (patch: Partial<EncodedTrack>) => () => decodeTrack({ ...good, ...patch });

  it('refuses a cut value, a stray character, an oversized value and a part point', () => {
    expect(bad({ points: good.points.slice(0, -1) + '_' })).toThrow('ends in the middle');
    expect(bad({ points: good.points + ' ' })).toThrow('outside the encoding');
    expect(bad({ points: good.points + 'ÿ' })).toThrow('outside the encoding');
    expect(bad({ points: '_'.repeat(7) + '?' })).toThrow('too large');
    expect(bad({ points: good.points + '?' })).toThrow('whole points');
  });

  it('refuses points off the globe, before the start, or out of time order', () => {
    const one = (p: TrackPoint) => encodeTrack({ segments: [[p]] });
    expect(() => decodeTrack(one({ t: 0, lat: 91, lon: 0, ele: null }))).toThrow('globe');
    expect(() => decodeTrack(one({ t: 0, lat: -91, lon: 0, ele: null }))).toThrow('globe');
    expect(() => decodeTrack(one({ t: 0, lat: 0, lon: 181, ele: null }))).toThrow('globe');
    expect(() => decodeTrack(one({ t: 0, lat: 0, lon: -181, ele: null }))).toThrow('globe');
    expect(() => decodeTrack(one({ t: -1, lat: 0, lon: 0, ele: null }))).toThrow('before the start');
    const same = encodeTrack({ segments: [[{ t: 1, lat: 0, lon: 0, ele: null }, { t: 1, lat: 0, lon: 0, ele: null }]] });
    expect(() => decodeTrack(same)).toThrow('time order');
  });

  it('refuses pauses outside the track, repeated or at the start', () => {
    expect(bad({ breaks: [5] })).toThrow('pause');
    expect(bad({ breaks: [0] })).toThrow('pause');
    expect(bad({ breaks: [2, 2] })).toThrow('pause');
    expect(() => decodeTrack({ v: 1, points: '', breaks: [1], elevation: false })).toThrow('pause');
  });

  it('refuses more than the point cap', () => {
    const many: TrackPoint[] = Array.from({ length: MAX_TRACK_POINTS + 1 }, (_, i) => ({ t: i, lat: 0, lon: 0, ele: null }));
    expect(() => decodeTrack(encodeTrack({ segments: [many] }))).toThrow(TrackError);
  });

  it('haversine: one degree of latitude, and none', () => {
    expect(haversine({ lat: 0, lon: 0 }, { lat: 1, lon: 0 })).toBeCloseTo(M_PER_DEG, 3);
    expect(haversine({ lat: 10, lon: 10 }, { lat: 10, lon: 10 })).toBe(0);
  });
});

describe('a run from its track', () => {
  it('distance, pace and time: the pause gap adds nothing', () => {
    // 11 points 10 m apart (100 m), then a pause, then 100 m more 1 km away.
    const s = summarizeTrack({ segments: [north(11, 10), north(11, 10, { t0: 100, lat0: 1000 / M_PER_DEG })] }, 30, null);
    expect(s.distanceM).toBeCloseTo(200, 1);
    expect(s.durationSeconds).toBe(30);
    expect(s.avgPaceSecPerKm).toBe(150);
    expect(s.calories).toBeNull();
    expect(s.elevationGainM).toBeNull();
  });

  it('too short for a pace', () => {
    expect(summarizeTrack({ segments: [north(2, 4)] }, 5, 70).avgPaceSecPerKm).toBeNull();
  });

  it('nothing recorded', () => {
    const s = summarizeTrack({ segments: [] }, 0, 70);
    expect(s).toMatchObject({ distanceM: 0, avgPaceSecPerKm: null, splitsKm: [], series: [], outline: [], calories: 0 });
  });

  it('km splits: full ones, then the rest; the time is interpolated at the boundary', () => {
    // 2,500 m at 5 m/s (one point a second): 200 s per km, the last 500 m in 100 s.
    const s = summarizeTrack({ segments: [north(501, 5)] }, 500, null);
    expect(s.splitsKm.map((x) => [x.index, x.distanceM, x.seconds, x.pace])).toEqual([
      [1, 1000, 200, 200],
      [2, 1000, 200, 200],
      [3, 500, 100, 200],
    ]);
    expect(s.splitsMi[0]).toMatchObject({ index: 1, distanceM: round1(MILE_M), pace: round1(MILE_M / 5) });
  });

  it('a last split under 10 m is left out', () => {
    const s = summarizeTrack({ segments: [north(203, 5)] }, 202, null);
    expect(s.splitsKm.map((x) => x.distanceM)).toEqual([1000]);
  });

  it('a pause inside a split costs no time in it', () => {
    const s = summarizeTrack({ segments: [north(101, 5), north(101, 5, { t0: 400, lat0: 500 / M_PER_DEG })] }, 200, null);
    expect(s.splitsKm[0]).toMatchObject({ distanceM: 1000, seconds: 200 });
  });

  it('split elevation change, and none without elevation', () => {
    const s = summarizeTrack({ segments: [north(401, 5, { ele: (i) => i / 20 })] }, 400, null);
    expect(s.splitsKm[0]!.elevationChangeM).toBe(10);
    expect(summarizeTrack({ segments: [north(401, 5)] }, 400, null).splitsKm[0]!.elevationChangeM).toBeNull();
  });

  it('the chart: buckets of 50 m up to 100, none under 50 m', () => {
    expect(summarizeTrack({ segments: [north(10, 4)] }, 9, null).series).toEqual([]);
    const short = summarizeTrack({ segments: [north(61, 5, { ele: () => 3 })] }, 60, null).series;
    expect(short.map((p) => [p.distanceM, p.pace, p.ele])).toEqual([50, 100, 150, 200, 250, 300].map((d) => [d, 200, 3]));
    const long = summarizeTrack({ segments: [north(2001, 5)] }, 2000, null).series;
    expect(long).toHaveLength(100);
    expect(long[99]).toMatchObject({ distanceM: 10_000, pace: 200, ele: null });
  });

  it('standing still on a point (no distance between fixes) reads the later fix', () => {
    const pts = [...north(3, 5), { t: 3, lat: (2 * 5) / M_PER_DEG, lon: 0, ele: null }, ...north(30, 5, { t0: 4, lat0: 15 / M_PER_DEG })];
    const s = summarizeTrack({ segments: [pts] }, 32, null);
    expect(s.series[0]!.pace).toBeGreaterThan(0);
  });

  it('elevation gain: climbs of 5 m or more over the lowest point since the last', () => {
    const track = (eles: (number | null)[]): Track => ({ segments: [eles.map((ele, i) => ({ t: i, lat: 0, lon: 0, ele }))] });
    expect(elevationGain(track([null, null]))).toBeNull();
    expect(elevationGain(track([100, 104, 101, 104.9]))).toBe(0);
    expect(elevationGain(track([100, 106, 102, 98, 103]))).toBe(11);
    expect(elevationGain(track([100, null, 100 + CLIMB_THRESHOLD_M]))).toBe(5);
  });

  it('calories: ACSM walking below 6 km/h, running above, 24 km/h at most', () => {
    expect(vo2At(80)).toBeCloseTo(11.5);
    expect(vo2At(200)).toBeCloseTo(43.5);
    expect(vo2At(1000)).toBe(vo2At(400));
    // 10 km/h for an hour at 70 kg: 0.2·166.7 + 3.5 = 36.83 ml/kg/min → ~773 kcal.
    expect(kcalAt(10_000 / 60, 3600, 70)).toBeCloseTo(773.5, 0);
    const s = summarizeTrack({ segments: [north(601, 2.5)] }, 600, 70);
    expect(s.calories).toBe(Math.round(kcalAt(150, 600, 70)));
  });

  it('the outline: every point under the cap, evenly picked above it, one point alone', () => {
    expect(summarizeTrack({ segments: [north(1, 5)] }, 0, null).outline).toEqual([[0, 0]]);
    expect(summarizeTrack({ segments: [north(10, 5)] }, 9, null).outline).toHaveLength(10);
    const big = summarizeTrack({ segments: [north(1000, 5)] }, 999, null).outline;
    expect(big).toHaveLength(OUTLINE_MAX_POINTS);
    expect(big[OUTLINE_MAX_POINTS - 1]![0]).toBeCloseTo((999 * 5) / M_PER_DEG, 5);
  });
});

describe('a treadmill run', () => {
  it('the typed distance and an even pace; no splits, chart or map', () => {
    const s = summarizeTreadmill(5000, 1500, 70);
    expect(s).toMatchObject({ distanceM: 5000, avgPaceSecPerKm: 300, elevationGainM: null, splitsKm: [], series: [], outline: [] });
    expect(s.calories).toBe(Math.round(kcalAt(200, 1500, 70)));
  });

  it('no weight, or no time', () => {
    expect(summarizeTreadmill(3000, 900, null).calories).toBeNull();
    expect(summarizeTreadmill(0, 0, 70)).toMatchObject({ calories: 0, avgPaceSecPerKm: null });
  });
});

describe('the shared fixtures (the app checks the same files)', () => {
  const dir = join(here, 'fixtures', 'running');
  const files = readdirSync(dir).filter((f) => f.endsWith('.json'));

  it('there are fixtures', () => {
    expect(files.length).toBeGreaterThanOrEqual(3);
  });

  for (const file of files) {
    it(`${file}: the summary is unchanged`, () => {
      const f = JSON.parse(readFileSync(join(dir, file), 'utf8')) as {
        track: EncodedTrack;
        durationSeconds: number;
        weightKg: number | null;
        expected: RunSummary;
      };
      expect(summarizeTrack(decodeTrack(f.track), f.durationSeconds, f.weightKg)).toEqual(f.expected);
    });
  }
});

function round1(x: number): number {
  return Math.round(x * 10) / 10;
}
