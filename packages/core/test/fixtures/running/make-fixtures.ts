/**
 * Beta 4.0 (ADR-038): writes the shared running fixtures. Each is a
 * synthetic but realistic track (a seeded random walk, so the files never
 * change unless this script does) with the summary core computes for it.
 * Core's test checks the summary still comes out the same; the app's test
 * checks its live engine and offline summary agree with it.
 *
 *   pnpm --filter @fitos/core exec tsx test/fixtures/running/make-fixtures.ts
 */
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { summarizeTrack } from '../../../src/running/summary.js';
import { decodeTrack, encodeTrack, quantize, type TrackPoint } from '../../../src/running/track.js';

const here = dirname(fileURLToPath(import.meta.url));

/** Mulberry32: a small seeded PRNG. */
function rng(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const M_PER_DEG_LAT = 111_195;

interface Leg {
  /** Seconds of running. */
  readonly seconds: number;
  /** Metres a second. */
  readonly speed: number;
  /** Degrees a second the heading turns. */
  readonly turn: number;
}

function walk(seed: number, legs: readonly (readonly Leg[])[], withEle: boolean): TrackPoint[][] {
  const r = rng(seed);
  let lat = 12.9692; // VIT Vellore
  let lon = 79.1559;
  let heading = 30;
  let ele = 216;
  let t = 0;
  const segments: TrackPoint[][] = [];
  for (const segment of legs) {
    const points: TrackPoint[] = [];
    for (const leg of segment) {
      for (let s = 0; s < leg.seconds; s++) {
        // About one fix a second, never exactly.
        t += 0.9 + r() * 0.2;
        heading += leg.turn + (r() - 0.5) * 4;
        const step = leg.speed * (0.92 + r() * 0.16);
        lat += (Math.cos((heading * Math.PI) / 180) * step) / M_PER_DEG_LAT;
        lon += (Math.sin((heading * Math.PI) / 180) * step) / (M_PER_DEG_LAT * Math.cos((lat * Math.PI) / 180));
        ele += Math.sin(t / 90) * 0.12 + (r() - 0.5) * 0.3;
        points.push(quantize({ t, lat, lon, ele: withEle ? ele : null }));
      }
    }
    segments.push(points);
    // The pause: time passes, the runner stands still.
    t += 45;
  }
  return segments;
}

interface Fixture {
  readonly name: string;
  readonly description: string;
  readonly segments: readonly (readonly Leg[])[];
  readonly withEle: boolean;
  readonly seed: number;
  readonly weightKg: number | null;
}

const fixtures: Fixture[] = [
  {
    name: 'easy-loop',
    description: 'An easy 5 km-ish loop at about 5:40/km, one segment, with elevation.',
    segments: [[{ seconds: 1800, speed: 2.95, turn: 0.2 }]],
    withEle: true,
    seed: 4,
    weightKg: 72,
  },
  {
    name: 'intervals-with-pauses',
    description: 'Warm-up, three fast reps with standing rests (three pauses), cool-down walk.',
    segments: [
      [{ seconds: 420, speed: 2.7, turn: 0 }, { seconds: 120, speed: 4.4, turn: 0.5 }],
      [{ seconds: 120, speed: 4.5, turn: -0.5 }],
      [{ seconds: 120, speed: 4.6, turn: 0.4 }],
      [{ seconds: 300, speed: 1.4, turn: 0.1 }],
    ],
    withEle: true,
    seed: 7,
    weightKg: 60,
  },
  {
    name: 'no-elevation',
    description: 'A 1.3 km straight run from a phone that gave no altitude, no weight known.',
    segments: [[{ seconds: 400, speed: 3.3, turn: 0 }]],
    withEle: false,
    seed: 11,
    weightKg: null,
  },
];

for (const f of fixtures) {
  const segments = walk(f.seed, f.segments, f.withEle);
  const track = encodeTrack({ segments });
  const moving = segments.reduce((s, seg) => s + (seg[seg.length - 1]!.t - seg[0]!.t), 0);
  // The phone's timer runs a little longer than the track (the first fix
  // after a start or resume).
  const durationSeconds = Math.round(moving) + segments.length;
  const expected = summarizeTrack(decodeTrack(track), durationSeconds, f.weightKg);
  writeFileSync(
    join(here, `${f.name}.json`),
    `${JSON.stringify({ name: f.name, description: f.description, track, durationSeconds, weightKg: f.weightKg, expected }, null, 1)}\n`,
  );
  console.log(`${f.name}: ${expected.distanceM} m, ${expected.splitsKm.length} km splits`);
}
