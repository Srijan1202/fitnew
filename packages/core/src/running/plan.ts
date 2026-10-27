/**
 * Running (beta 4.1, ADR-039): training plans for a 5K, a 10K, a half
 * marathon and a marathon — deterministic, from the runner's fitness (VDOT)
 * and the days they can run.
 *
 *  - Length: 8 weeks for 5K and 10K, 12 for the half, 16 for the marathon.
 *  - Each week: one long run (on the runner's long-run day), one or two
 *    quality sessions (intervals and tempo; with three days a week they
 *    alternate), and easy runs on the other days.
 *  - Every fourth week is easier; the last weeks taper; the final long-run
 *    day is the race.
 *  - A beginner 5K is run/walk from zero (three days a week), building to
 *    30 minutes of running and a 5K time trial in week 8. It carries no
 *    paces: effort words until there is a first timed run.
 */
import { addDays } from '../nutrition/log.js';
import { isoWeekday } from '../progress/streak.js';
import { RACE_DISTANCES_M, predictSeconds, zones, type PaceRange, type PaceZones, type RaceDistance } from './vdot.js';
import { around, expand, type WorkoutStep } from './workout.js';

export const PLAN_GOALS = ['5k', '10k', 'half', 'marathon'] as const satisfies readonly RaceDistance[];
export type PlanGoal = (typeof PLAN_GOALS)[number];
export const PLAN_LEVELS = ['beginner', 'runner'] as const;
export type PlanLevel = (typeof PLAN_LEVELS)[number];
export const PLANNED_RUN_KINDS = ['easy', 'long', 'tempo', 'intervals', 'run-walk', 'race'] as const;
export type PlannedRunKind = (typeof PLANNED_RUN_KINDS)[number];

export const PLAN_WEEKS: Readonly<Record<PlanGoal, number>> = { '5k': 8, '10k': 8, half: 12, marathon: 16 };
/** The weeks before the race that taper. */
export const TAPER_WEEKS: Readonly<Record<PlanGoal, number>> = { '5k': 1, '10k': 1, half: 2, marathon: 3 };

/** Long-run distance (km) per week, the race week excluded; every fourth week is easier. */
export const LONG_RUN_KM: Readonly<Record<PlanGoal, readonly number[]>> = {
  '5k': [5, 6, 7, 5, 7, 8, 6],
  '10k': [8, 9, 10, 8, 11, 12, 9],
  half: [10, 12, 13, 10, 14, 16, 17, 13, 18, 19, 14],
  marathon: [14, 16, 18, 14, 20, 22, 24, 18, 26, 28, 30, 22, 32, 26, 19],
};

/** The longest tempo block per goal, minutes. */
export const TEMPO_CAP_MIN: Readonly<Record<PlanGoal, number>> = { '5k': 20, '10k': 25, half: 35, marathon: 40 };

/** Interval sessions over a plan, by its share done: [reps, metres, recovery s]. */
const INTERVALS: readonly (readonly [number, number, number])[] = [
  [6, 400, 90],
  [8, 400, 90],
  [5, 800, 120],
  [4, 800, 120],
  [5, 1000, 120],
  [6, 1000, 120],
  [4, 1000, 120],
];

/** Beginner run/walk: [run s, walk s, reps] for weeks 1–7. */
export const RUN_WALK: readonly (readonly [number, number, number])[] = [
  [60, 90, 8],
  [90, 120, 6],
  [120, 120, 6],
  [180, 90, 5],
  [300, 120, 4],
  [480, 120, 3],
  [720, 60, 2],
];

export interface PlanInput {
  readonly goal: PlanGoal;
  readonly level: PlanLevel;
  /** From a recent race or the goal time; null for a beginner. */
  readonly vdot: number | null;
  readonly daysPerWeek: 3 | 4 | 5;
  /** ISO weekdays (1 Monday … 7 Sunday), as many as `daysPerWeek`. */
  readonly weekdays: readonly number[];
  /** One of `weekdays`. */
  readonly longRunWeekday: number;
  /** yyyy-mm-dd: the plan's first week is the ISO week holding it; earlier days of it are left out. */
  readonly startDate: string;
}

export interface PlannedRun {
  readonly date: string;
  readonly week: number;
  readonly kind: PlannedRunKind;
  readonly title: string;
  readonly distanceM: number | null;
  readonly seconds: number | null;
  readonly pace: PaceRange | null;
  /** The structured session (intervals, tempo, run/walk); null for a steady run. */
  readonly steps: readonly WorkoutStep[] | null;
  readonly note: string;
}

export interface Plan {
  readonly goal: PlanGoal;
  readonly level: PlanLevel;
  readonly weeks: number;
  readonly zones: PaceZones | null;
  /** The predicted race time at the plan's VDOT; null for a beginner. */
  readonly predictedSeconds: number | null;
  readonly runs: readonly PlannedRun[];
}

export class PlanError extends Error {
  override readonly name = 'PlanError';
}

const NOTES: Readonly<Record<PlannedRunKind, string>> = {
  easy: 'Conversational: you could talk in full sentences.',
  long: 'Slow and steady. Time on your feet matters, not speed.',
  tempo: 'Comfortably hard: you could say a few words, not chat.',
  intervals: 'Hard reps, easy jogs. Keep every rep about the same.',
  'run-walk': 'Run easy, walk briskly. Finishing matters, not speed.',
  race: 'Race day. Start a little slower than goal pace and build.',
};

const km = (m: number) => (Number.isInteger(m / 1000) ? `${m / 1000}` : (m / 1000).toFixed(1));
const raceLabel: Readonly<Record<PlanGoal, string>> = { '5k': '5K', '10k': '10K', half: 'half marathon', marathon: 'marathon' };

export function checkInput(i: PlanInput): void {
  if (!PLAN_GOALS.includes(i.goal)) throw new PlanError('Unknown goal.');
  if (![3, 4, 5].includes(i.daysPerWeek)) throw new PlanError('3, 4 or 5 runs a week.');
  const days = new Set(i.weekdays);
  if (days.size !== i.weekdays.length || i.weekdays.length !== i.daysPerWeek || i.weekdays.some((d) => !Number.isInteger(d) || d < 1 || d > 7)) {
    throw new PlanError(`Choose ${i.daysPerWeek} different days of the week.`);
  }
  if (!days.has(i.longRunWeekday)) throw new PlanError('The long-run day must be one of the running days.');
  if (i.level === 'beginner') {
    if (i.goal !== '5k') throw new PlanError('The beginner plan is the 5K.');
    if (i.daysPerWeek !== 3) throw new PlanError('The beginner plan runs three days a week.');
  } else if (i.vdot === null) {
    throw new PlanError('A recent race or a goal time is needed for this plan.');
  }
}

function weekStart(startDate: string): string {
  return addDays(startDate, 1 - isoWeekday(startDate));
}

function runWalk(week: number, session: number): Omit<PlannedRun, 'date' | 'week'> {
  if (week === 8) {
    if (session === 2) {
      return { kind: 'race', title: '5K time trial', distanceM: 5000, seconds: null, pace: null, steps: null, note: 'Your first 5K. Run it steady; walk if you need to.' };
    }
    const minutes = session === 0 ? 20 : 25;
    return { kind: 'easy', title: `Run ${minutes} min`, distanceM: null, seconds: minutes * 60, pace: null, steps: null, note: NOTES.easy };
  }
  const [run, walk, reps] = RUN_WALK[week - 1]!;
  const steps = expand({
    warmup: { seconds: 300 },
    blocks: [{ count: reps, work: { seconds: run }, workPace: null, workEffort: 'easy run', recover: { seconds: walk }, recoverMode: 'walk' }],
    cooldown: { seconds: 300 },
    easy: null,
  });
  const runLabel = run % 60 === 0 ? `${run / 60} min` : `${run} s`;
  return {
    kind: 'run-walk',
    title: `Run/walk: ${reps} × ${runLabel}`,
    distanceM: null,
    // 5 minutes' walk either side of the reps (no walk after the last).
    seconds: 300 + reps * run + (reps - 1) * walk + 300,
    pace: null,
    steps,
    note: NOTES['run-walk'],
  };
}

function intervals(goal: PlanGoal, week: number, weeks: number, z: PaceZones): Omit<PlannedRun, 'date' | 'week'> {
  // The session follows the plan's progress, so a 16-week plan builds as a 8-week one does.
  const idx = Math.min(INTERVALS.length - 1, Math.floor(((week - 1) / (weeks - 1)) * (INTERVALS.length - 1)));
  const [reps, metres, rest] = week === weeks ? ([4, 400, 90] as const) : INTERVALS[idx]!;
  // Half and marathon runners do their reps at threshold-to-interval, not full interval pace.
  const pace = goal === 'half' || goal === 'marathon' ? around(Math.round((z.interval + z.threshold) / 2)) : around(z.interval);
  return {
    kind: 'intervals',
    title: `Intervals: ${reps} × ${metres >= 1000 ? `${km(metres)} km` : `${metres} m`}`,
    distanceM: null,
    seconds: null,
    pace,
    steps: expand({
      warmup: { seconds: 600 },
      blocks: [{ count: reps, work: { distanceM: metres }, workPace: pace, workEffort: 'hard', recover: { seconds: rest }, recoverMode: 'jog' }],
      cooldown: { seconds: 600 },
      easy: z.easy,
    }),
    note: NOTES.intervals,
  };
}

export function tempoMinutes(goal: PlanGoal, week: number, weeks: number): number {
  const taper = TAPER_WEEKS[goal];
  if (week > weeks - taper) return 15;
  const base = Math.min(TEMPO_CAP_MIN[goal], 15 + 3 * (week - 1));
  return week % 4 === 0 ? Math.max(15, base - 6) : base;
}

function tempo(goal: PlanGoal, week: number, weeks: number, z: PaceZones): Omit<PlannedRun, 'date' | 'week'> {
  const minutes = tempoMinutes(goal, week, weeks);
  const pace = around(z.threshold);
  return {
    kind: 'tempo',
    title: `Tempo ${minutes} min`,
    distanceM: null,
    seconds: null,
    pace,
    steps: expand({
      warmup: { seconds: 600 },
      blocks: [{ count: 1, work: { seconds: minutes * 60 }, workPace: pace, workEffort: 'comfortably hard', recover: null, recoverMode: 'jog' }],
      cooldown: { seconds: 600 },
      easy: z.easy,
    }),
    note: NOTES.tempo,
  };
}

/** The plan, or [PlanError] for input that does not make one. */
export function generatePlan(input: PlanInput): Plan {
  checkInput(input);
  const weeks = PLAN_WEEKS[input.goal];
  const monday = weekStart(input.startDate);
  const days = [...input.weekdays].sort((a, b) => a - b);
  const runs: PlannedRun[] = [];
  const push = (week: number, weekday: number, run: Omit<PlannedRun, 'date' | 'week'>) => {
    const date = addDays(monday, 7 * (week - 1) + weekday - 1);
    if (date >= input.startDate) runs.push({ date, week, ...run });
  };

  if (input.level === 'beginner') {
    for (let w = 1; w <= weeks; w++) days.forEach((d, s) => push(w, d, runWalk(w, s)));
    return { goal: input.goal, level: input.level, weeks, zones: null, predictedSeconds: null, runs };
  }

  const z = zones(input.vdot!);
  const raceM = RACE_DISTANCES_M[input.goal];
  const predicted = predictSeconds(input.vdot!, raceM);
  const others = days.filter((d) => d !== input.longRunWeekday);
  for (let w = 1; w <= weeks; w++) {
    const raceWeek = w === weeks;
    const longKm = raceWeek ? null : LONG_RUN_KM[input.goal][w - 1]!;
    push(
      w,
      input.longRunWeekday,
      raceWeek
        ? {
            kind: 'race',
            title: `Race: ${raceLabel[input.goal]}`,
            distanceM: raceM,
            seconds: null,
            pace: around(Math.round(predicted / (raceM / 1000)), 3),
            steps: null,
            note: NOTES.race,
          }
        : { kind: 'long', title: `Long run ${longKm} km`, distanceM: longKm! * 1000, seconds: null, pace: z.easy, steps: null, note: NOTES.long },
    );
    // Quality: with 4–5 days both sessions; with 3 they alternate, intervals first.
    const quality: ('intervals' | 'tempo')[] = input.daysPerWeek === 3 ? [w % 2 === 1 ? 'intervals' : 'tempo'] : ['intervals', 'tempo'];
    // The race week keeps one short sharpener and easy runs.
    const sessions = raceWeek ? quality.slice(0, 1) : quality;
    // An easy run is half the week's long run, 3 km at least (the race week: 4 km).
    const easyM = Math.max(3000, Math.round(((longKm ?? 8) * 1000) / 2 / 500) * 500);
    others.forEach((d, i) => {
      const q = sessions[i];
      if (q === 'intervals') push(w, d, intervals(input.goal, w, weeks, z));
      else if (q === 'tempo') push(w, d, tempo(input.goal, w, weeks, z));
      else push(w, d, { kind: 'easy', title: `Easy ${km(easyM)} km`, distanceM: easyM, seconds: null, pace: z.easy, steps: null, note: NOTES.easy });
    });
  }
  runs.sort((a, b) => a.date.localeCompare(b.date));
  return { goal: input.goal, level: input.level, weeks, zones: z, predictedSeconds: predicted, runs };
}
