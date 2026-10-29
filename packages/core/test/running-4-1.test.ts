/**
 * Beta 4.1 (ADR-039): fitness and paces (Daniels' VDOT), workouts, the
 * training plans, laps, and running load in readiness — every rule and
 * branch (§26.1).
 */
import { describe, expect, it } from 'vitest';

import { addDays } from '../src/nutrition/log.js';
import { isoWeekday } from '../src/progress/streak.js';
import {
  BAND_ADVICE,
  RUNNING_LOAD,
  RUNNING_LOAD_ADVICE,
  readinessOn,
  runningLoadPenalty,
  runningLoadRatio,
  type RunLoad,
} from '../src/recovery/readiness.js';
import { LapError, MAX_LAPS, checkMarks, lapsOf } from '../src/running/laps.js';
import {
  LONG_RUN_KM,
  PLAN_GOALS,
  PLAN_WEEKS,
  PlanError,
  RUN_WALK,
  TEMPO_CAP_MIN,
  generatePlan,
  tempoMinutes,
  type PlanInput,
} from '../src/running/plan.js';
import { type TrackPoint } from '../src/running/track.js';
import { RACE_DISTANCES_M, VDOT_MAX, VDOT_MIN, paceAt, predictSeconds, speedFor, vdotForGoal, vdotFromRace, vo2At, zones } from '../src/running/vdot.js';
import { PRESET_IDS, around, expand, presets, sprints } from '../src/running/workout.js';

const hms = (h: number, m: number, s: number) => h * 3600 + m * 60 + s;

describe('VDOT (Daniels & Gilbert): the published table', () => {
  // Daniels' Running Formula, VDOT table: race times for VDOT 40, 50 and 60.
  const table = [
    { vdot: 40, '5k': hms(0, 24, 8), '10k': hms(0, 50, 3), half: hms(1, 50, 59), marathon: hms(3, 49, 45) },
    { vdot: 50, '5k': hms(0, 19, 57), '10k': hms(0, 41, 21), half: hms(1, 31, 35), marathon: hms(3, 10, 49) },
    { vdot: 60, '5k': hms(0, 17, 3), '10k': hms(0, 35, 22), half: hms(1, 18, 9), marathon: hms(2, 43, 25) },
  ] as const;

  for (const row of table) {
    it(`VDOT ${row.vdot}: its 5K gives it back, and every race time is within 0.5 %`, () => {
      expect(vdotFromRace(5000, row['5k'])).toBeCloseTo(row.vdot, 0);
      for (const d of ['5k', '10k', 'half', 'marathon'] as const) {
        const got = predictSeconds(row.vdot, RACE_DISTANCES_M[d]);
        expect(Math.abs(got - row[d]) / row[d], d).toBeLessThan(0.005);
      }
    });
  }

  it('the training paces for VDOT 50: easy 4:54–5:38, marathon 4:31, threshold 4:15, interval 3:55, repetition 3:39 per km', () => {
    const z = zones(50);
    expect(z).toEqual({ vdot: 50, easy: { fast: 294, slow: 338 }, marathon: 271, threshold: 255, interval: 235, repetition: 219 });
  });

  it('speed and oxygen cost are each other’s inverse; paces get faster with share', () => {
    expect(vo2At(speedFor(45))).toBeCloseTo(45, 8);
    expect(paceAt(50, 0.9)).toBeLessThan(paceAt(50, 0.8));
  });

  it('VDOT is held to its range; a goal time gives the VDOT it needs', () => {
    expect(vdotFromRace(5000, hms(2, 0, 0))).toBe(VDOT_MIN);
    expect(vdotFromRace(5000, hms(0, 10, 0))).toBe(VDOT_MAX);
    expect(vdotForGoal(10_000, hms(0, 41, 21))).toBeCloseTo(50, 0);
  });
});

describe('workouts', () => {
  it('a definition expands to warm-up, work and recovery (none after the last rep), cool-down', () => {
    const steps = expand({
      warmup: { seconds: 600 },
      blocks: [{ count: 3, work: { distanceM: 400 }, workPace: around(240), workEffort: 'hard', recover: { seconds: 90 }, recoverMode: 'jog' }],
      cooldown: { distanceM: 1000 },
      easy: { fast: 300, slow: 340 },
    });
    expect(steps.map((s) => s.kind)).toEqual(['warmup', 'work', 'recover', 'work', 'recover', 'work', 'cooldown']);
    expect(steps[1]).toEqual({ kind: 'work', distanceM: 400, seconds: null, pace: { fast: 235, slow: 245 }, effort: 'hard', rep: { index: 1, of: 3 } });
    expect(steps[2]).toMatchObject({ kind: 'recover', distanceM: null, seconds: 90, effort: 'jog', pace: null });
    expect(steps[6]).toMatchObject({ kind: 'cooldown', distanceM: 1000, pace: { fast: 300, slow: 340 } });
  });

  it('no warm-up, no cool-down, no recovery', () => {
    const steps = expand({
      warmup: null,
      blocks: [{ count: 2, work: { seconds: 60 }, workPace: null, workEffort: 'fast', recover: null, recoverMode: 'stand' }],
      cooldown: null,
      easy: null,
    });
    expect(steps.map((s) => s.kind)).toEqual(['work', 'work']);
  });

  it('presets: paces from the zones, effort words without', () => {
    const withZones = presets(zones(50));
    expect(withZones.map((p) => p.id)).toEqual([...PRESET_IDS]);
    const fiveK = withZones.find((p) => p.id === '5x1k')!;
    expect(fiveK.steps.filter((s) => s.kind === 'work').every((s) => s.pace?.fast === 230)).toBe(true);
    const tempo = withZones.find((p) => p.id === '3x2k-tempo')!;
    expect(tempo.steps.find((s) => s.kind === 'work')!.pace).toEqual(around(255));
    const plain = presets(null);
    expect(plain.every((p) => p.steps.every((s) => s.pace === null))).toBe(true);
    expect(plain.find((p) => p.id === '10x1min')!.steps.filter((s) => s.kind === 'work')).toHaveLength(10);
  });

  it('a sprint session: all-out reps, standing rests, no pace', () => {
    const s = sprints(6, 100, 120);
    expect(s.filter((x) => x.kind === 'work')).toHaveLength(6);
    expect(s.find((x) => x.kind === 'work')).toMatchObject({ distanceM: 100, effort: 'all out', pace: null });
    expect(s.find((x) => x.kind === 'recover')).toMatchObject({ seconds: 120, effort: 'stand' });
  });
});

describe('training plans', () => {
  // 2026-11-02 is a Monday.
  const base: PlanInput = { goal: '10k', level: 'runner', vdot: 45, daysPerWeek: 4, weekdays: [2, 4, 6, 7], longRunWeekday: 7, startDate: '2026-11-02' };

  it('refuses what makes no plan', () => {
    const bad = (over: Partial<PlanInput>, word: string) => expect(() => generatePlan({ ...base, ...over } as PlanInput)).toThrow(word);
    bad({ goal: 'ultra' as never }, 'Unknown goal');
    bad({ daysPerWeek: 6 as never, weekdays: [1, 2, 3, 4, 5, 6] }, '1 to 5 runs');
    bad({ daysPerWeek: 0 as never, weekdays: [] }, '1 to 5 runs');
    bad({ weekdays: [2, 2, 6, 7] }, 'different days');
    bad({ weekdays: [2, 4, 6] }, 'different days');
    bad({ weekdays: [0, 4, 6, 7] }, 'different days');
    bad({ weekdays: [2, 4, 6, 7.5] }, 'different days');
    bad({ longRunWeekday: 1 }, 'long-run day');
    bad({ level: 'beginner', vdot: null }, 'beginner plan is the 5K');
    bad({ goal: '5k', level: 'beginner', vdot: null }, '1, 2 or 3 days');
    bad({ vdot: null }, 'recent race or a goal time');
    expect(() => generatePlan({ ...base, vdot: null })).toThrow(PlanError);
  });

  for (const goal of PLAN_GOALS) {
    for (const days of [3, 4, 5] as const) {
      it(`${goal}, ${days} days a week: the weeks, the days, a long run each week and the race last`, () => {
        const weekdays = [1, 2, 3, 4, 5, 6, 7].slice(7 - days);
        const plan = generatePlan({ ...base, goal, daysPerWeek: days, weekdays, longRunWeekday: weekdays[weekdays.length - 1]! });
        expect(plan.weeks).toBe(PLAN_WEEKS[goal]);
        expect(plan.runs).toHaveLength(PLAN_WEEKS[goal] * days);
        expect(plan.runs.every((r) => weekdays.includes(isoWeekday(r.date)))).toBe(true);
        const last = plan.runs[plan.runs.length - 1]!;
        expect(last).toMatchObject({ kind: 'race', distanceM: RACE_DISTANCES_M[goal], week: PLAN_WEEKS[goal] });
        for (let w = 1; w < plan.weeks; w++) {
          const long = plan.runs.find((r) => r.week === w && r.kind === 'long')!;
          expect(long.distanceM).toBe(LONG_RUN_KM[goal][w - 1]! * 1000);
        }
        // Every fourth week is easier than the one before.
        expect(LONG_RUN_KM[goal][3]!).toBeLessThan(LONG_RUN_KM[goal][2]!);
        const kinds = new Set(plan.runs.map((r) => r.kind));
        expect(kinds.has('intervals') && kinds.has('tempo') && kinds.has('easy')).toBe(days > 3 || plan.weeks > 1);
        expect(plan.predictedSeconds).toBe(predictSeconds(45, RACE_DISTANCES_M[goal]));
      });
    }
  }

  it('three days: one quality session a week, intervals then tempo in turn; the race week a short sharpener', () => {
    const plan = generatePlan({ ...base, daysPerWeek: 3, weekdays: [2, 4, 7] });
    const quality = (w: number) => plan.runs.filter((r) => r.week === w && (r.kind === 'intervals' || r.kind === 'tempo')).map((r) => r.kind);
    expect(quality(1)).toEqual(['intervals']);
    expect(quality(2)).toEqual(['tempo']);
    expect(quality(8)).toEqual(['tempo']);
    const four = generatePlan(base);
    expect(four.runs.filter((r) => r.week === 8 && r.kind === 'intervals').map((r) => r.title)).toEqual(['Intervals: 4 × 400 m']);
  });

  it('paces come from the zones; long and easy runs at easy pace; half and marathon reps between threshold and interval', () => {
    const z = zones(45);
    const plan = generatePlan(base);
    expect(plan.zones).toEqual(z);
    expect(plan.runs.find((r) => r.kind === 'easy')!.pace).toEqual(z.easy);
    expect(plan.runs.find((r) => r.kind === 'long')!.pace).toEqual(z.easy);
    expect(plan.runs.find((r) => r.kind === 'intervals')!.pace).toEqual(around(z.interval));
    const half = generatePlan({ ...base, goal: 'half' });
    expect(half.runs.find((r) => r.kind === 'intervals')!.pace).toEqual(around(Math.round((z.interval + z.threshold) / 2)));
    expect(half.runs.find((r) => r.kind === 'intervals')!.title).toBe('Intervals: 6 × 400 m');
    expect(generatePlan({ ...base, goal: 'marathon' }).runs.some((r) => r.title === 'Intervals: 5 × 1 km')).toBe(true);
  });

  it('easy runs are half the long run, 3 km at least; 4 km in the race week', () => {
    const plan = generatePlan({ ...base, goal: '5k' });
    expect(plan.runs.find((r) => r.week === 1 && r.kind === 'easy')!.distanceM).toBe(3000);
    const ten = generatePlan(base);
    expect(ten.runs.find((r) => r.week === 6 && r.kind === 'easy')!).toMatchObject({ distanceM: 6000, title: 'Easy 6 km' });
    expect(generatePlan({ ...base, goal: 'half' }).runs.find((r) => r.week === 3 && r.kind === 'easy')!.title).toBe('Easy 6.5 km');
    expect(ten.runs.find((r) => r.week === 8 && r.kind === 'easy')!.distanceM).toBe(4000);
  });

  it('tempo builds 3 minutes a week to its cap, eases every fourth week, and is short in the taper', () => {
    expect(tempoMinutes('10k', 1, 8)).toBe(15);
    expect(tempoMinutes('10k', 3, 8)).toBe(21);
    expect(tempoMinutes('10k', 4, 8)).toBe(18);
    expect(tempoMinutes('10k', 7, 8)).toBe(TEMPO_CAP_MIN['10k']);
    expect(tempoMinutes('10k', 8, 8)).toBe(15);
    expect(tempoMinutes('5k', 4, 8)).toBe(15);
    expect(tempoMinutes('marathon', 13, 16)).toBe(TEMPO_CAP_MIN.marathon);
    expect(tempoMinutes('marathon', 14, 16)).toBe(15);
  });

  it('a mid-week start leaves out the days already gone', () => {
    // A Friday start: Tuesday and Thursday of that week are gone; Saturday and Sunday stay.
    const plan = generatePlan({ ...base, startDate: '2026-11-06' });
    expect(plan.runs[0]!.date).toBe('2026-11-07');
    expect(plan.runs.filter((r) => r.week === 1)).toHaveLength(2);
  });

  it('a beginner 5K: run/walk three days a week, no paces, 20 and 25 minutes then a 5K trial in week 8', () => {
    const plan = generatePlan({ goal: '5k', level: 'beginner', vdot: null, daysPerWeek: 3, weekdays: [1, 3, 5], longRunWeekday: 5, startDate: '2026-11-02' });
    expect(plan.zones).toBeNull();
    expect(plan.predictedSeconds).toBeNull();
    expect(plan.runs).toHaveLength(24);
    expect(plan.runs.every((r) => r.pace === null)).toBe(true);
    const w1 = plan.runs[0]!;
    const [run, walk, reps] = RUN_WALK[0]!;
    expect(w1).toMatchObject({ kind: 'run-walk', title: `Run/walk: ${reps} × 1 min` });
    expect(w1.seconds).toBe(300 + reps * run + (reps - 1) * walk + 300);
    expect(plan.runs[3]!.title).toBe('Run/walk: 6 × 90 s');
    expect(plan.runs[6]!.title).toBe('Run/walk: 6 × 2 min');
    expect(plan.runs.slice(21).map((r) => [r.kind, r.title, r.seconds, r.distanceM])).toEqual([
      ['easy', 'Run 20 min', 1200, null],
      ['easy', 'Run 25 min', 1500, null],
      ['race', '5K time trial', null, 5000],
    ]);
  });
});

describe('laps', () => {
  /** 3 m/s north from the equator, one point a second, a pause between 60 s and 100 s. */
  const M_PER_DEG = (Math.PI / 180) * 6_371_008.8;
  const seg = (t0: number, n: number, d0: number): TrackPoint[] =>
    Array.from({ length: n }, (_, i) => ({ t: t0 + i, lat: (d0 + 3 * i) / M_PER_DEG, lon: 0, ele: null }));
  const track = { segments: [seg(0, 61, 0), seg(100, 61, 180)] };

  it('distance and moving time between two clock times, interpolated; a pause adds neither', () => {
    const [a, b, c] = lapsOf(track, [
      { step: 0, startT: 0, endT: 30 },
      { step: 1, startT: 30.5, endT: 130 },
      { step: 2, startT: 130, endT: 130 },
    ]);
    expect(a).toEqual({ step: 0, distanceM: 90, seconds: 30, pace: expect.closeTo(333.3, 1) as number });
    // 30.5 → 60 (29.5 s) and 100 → 130 (30 s): no time or distance across the pause.
    expect(b!.seconds).toBe(59.5);
    expect(b!.distanceM).toBeCloseTo(178.5, 1);
    expect(c).toEqual({ step: 2, distanceM: 0, seconds: 0, pace: null });
  });

  it('checks marks: known steps, in order, not overlapping, at most the cap', () => {
    expect(() => checkMarks([{ step: 0, startT: 0, endT: 10 }, { step: 1, startT: 10, endT: 20 }], 2)).not.toThrow();
    expect(() => checkMarks([{ step: 2, startT: 0, endT: 10 }], 2)).toThrow('step the workout does not have');
    expect(() => checkMarks([{ step: 0.5, startT: 0, endT: 10 }], 2)).toThrow(LapError);
    expect(() => checkMarks([{ step: 0, startT: 10, endT: 5 }], 2)).toThrow('ends before it starts');
    expect(() => checkMarks([{ step: 0, startT: -1, endT: 5 }], 2)).toThrow('ends before it starts');
    expect(() => checkMarks([{ step: 0, startT: 0, endT: 10 }, { step: 1, startT: 5, endT: 20 }], 2)).toThrow('overlap');
    const many = Array.from({ length: MAX_LAPS + 1 }, (_, i) => ({ step: 0, startT: i, endT: i }));
    expect(() => checkMarks(many, 1)).toThrow('at most');
  });
});

describe('running load in readiness (owner: a sixth part, ADR-039)', () => {
  const DAY = '2026-11-20';
  const r = (daysAgo: number, minutes: number, effort: number | null = 5): RunLoad => ({ date: addDays(DAY, -daysAgo), minutes, effort });
  const steady = [r(25, 40), r(18, 40), r(11, 40), r(4, 40)];

  it('needs three runs in 28 days; older runs and later ones do not count', () => {
    expect(runningLoadRatio([r(3, 40), r(5, 40)], DAY)).toBeNull();
    expect(runningLoadRatio([r(3, 40), r(5, 40), r(40, 40), { date: addDays(DAY, 1), minutes: 40, effort: 5 }], DAY)).toBeNull();
    expect(runningLoadPenalty([r(3, 40)], DAY)).toEqual({ key: 'running', penalty: 0, max: 10, available: false });
  });

  it('steady weeks: ratio 1, no penalty', () => {
    expect(runningLoadRatio(steady, DAY)).toBeCloseTo(1, 5);
    expect(runningLoadPenalty(steady, DAY)).toEqual({ key: 'running', penalty: 0, max: 10, available: true });
  });

  it('rises evenly from 1.3 to the cap at 1.8 and stays there', () => {
    // Acute A, chronic weekly (A + 120)/4: choose A for the ratio wanted.
    const at = (ratio: number) => {
      const acute = (120 * ratio) / (4 - ratio);
      return runningLoadPenalty([r(25, 40), r(18, 40), r(11, 40), r(2, acute)], DAY).penalty;
    };
    expect(at(1.3)).toBe(0);
    expect(at(1.55)).toBe(5);
    expect(at(1.8)).toBe(10);
    expect(at(2.5)).toBe(10);
    expect(RUNNING_LOAD).toEqual({ acuteDays: 7, chronicDays: 28, minRuns: 3, from: 1.3, to: 1.8 });
  });

  it('effort weights the minutes; no effort counts as 5', () => {
    const hard = [r(25, 40), r(18, 40), r(11, 40), r(2, 40, 10)];
    const unknown = [r(25, 40), r(18, 40), r(11, 40), r(2, 40, null)];
    expect(runningLoadRatio(hard, DAY)).toBeGreaterThan(runningLoadRatio(unknown, DAY)!);
    expect(runningLoadRatio(unknown, DAY)).toBeCloseTo(1, 5);
  });

  const checkIn = { date: DAY, sleepHours: 8, sleepQuality: null, soreness: 1, energy: 5, stress: null };
  const input = { day: DAY, checkIns: [checkIn], lifts: [], nutritionDays: [], targets: [] };

  it('with runs, readiness has a sixth part; the advice names it when it is the biggest', () => {
    const jumped = [r(25, 30), r(18, 30), r(11, 30), r(2, 200)];
    const with6 = readinessOn({ ...input, runs: jumped })!;
    expect(with6.components.map((c) => c.key)).toEqual(['sleep', 'soreness', 'energy', 'performance', 'adherence', 'running']);
    expect(with6.score).toBe(90);
    expect(with6.advice).toBe(`${BAND_ADVICE.ready} ${RUNNING_LOAD_ADVICE}`);
    expect(readinessOn({ ...input, runs: steady })!.advice).toBe(BAND_ADVICE.ready);
    expect(readinessOn(input)!.components).toHaveLength(5);
  });

  it('the advice stays the band’s when another part takes more off', () => {
    const jumped = [r(25, 30), r(18, 30), r(11, 30), r(2, 200)];
    const sore = readinessOn({ ...input, checkIns: [{ ...checkIn, soreness: 5 }], runs: jumped })!;
    expect(sore.advice).toBe(BAND_ADVICE[sore.band]);
  });
});
