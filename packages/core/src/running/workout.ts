/**
 * Running (beta 4.1, ADR-039): a structured workout — warm-up, repeats of
 * work and recovery, cool-down — as the flat list of steps the phone's coach
 * walks through, and FITOS's ready-made sessions.
 *
 * A step ends after its distance or its time (exactly one). Work steps carry
 * a pace range (seconds per km) when FITOS knows the runner's zones, or an
 * effort word when it doesn't (a beginner).
 */
import type { PaceRange, PaceZones } from './vdot.js';

export const STEP_KINDS = ['warmup', 'work', 'recover', 'cooldown'] as const;
export type StepKind = (typeof STEP_KINDS)[number];

/** What to do in a recovery: jog, walk or stand. */
export const RECOVERY_MODES = ['jog', 'walk', 'stand'] as const;
export type RecoveryMode = (typeof RECOVERY_MODES)[number];

export interface WorkoutStep {
  readonly kind: StepKind;
  /** Exactly one of the two ends the step. */
  readonly distanceM: number | null;
  readonly seconds: number | null;
  readonly pace: PaceRange | null;
  /** "easy", "5K pace", "jog"… what the coach says when there is no pace. */
  readonly effort: string;
  /** For work and recovery inside repeats: which one, of how many. */
  readonly rep: { readonly index: number; readonly of: number } | null;
}

/** One end of a step: a distance or a time. */
export type StepEnd = { readonly distanceM: number } | { readonly seconds: number };

export interface RepeatBlock {
  readonly count: number;
  readonly work: StepEnd;
  readonly workPace: PaceRange | null;
  readonly workEffort: string;
  readonly recover: StepEnd | null;
  readonly recoverMode: RecoveryMode;
}

export interface WorkoutDefinition {
  readonly warmup: StepEnd | null;
  readonly blocks: readonly RepeatBlock[];
  readonly cooldown: StepEnd | null;
  /** Easy pace for warm-up and cool-down, when known. */
  readonly easy: PaceRange | null;
}

/** A workout holds at most this many steps. */
export const MAX_STEPS = 120;

const endOf = (e: StepEnd) => ('distanceM' in e ? { distanceM: e.distanceM, seconds: null } : { distanceM: null, seconds: e.seconds });

/** The flat list of steps. */
export function expand(def: WorkoutDefinition): WorkoutStep[] {
  const out: WorkoutStep[] = [];
  if (def.warmup !== null) out.push({ kind: 'warmup', ...endOf(def.warmup), pace: def.easy, effort: 'easy', rep: null });
  for (const b of def.blocks) {
    for (let i = 1; i <= b.count; i++) {
      out.push({ kind: 'work', ...endOf(b.work), pace: b.workPace, effort: b.workEffort, rep: { index: i, of: b.count } });
      // No recovery after the block's last repeat: the next block or the cool-down follows.
      if (b.recover !== null && i < b.count) {
        out.push({ kind: 'recover', ...endOf(b.recover), pace: null, effort: b.recoverMode, rep: { index: i, of: b.count } });
      }
    }
  }
  if (def.cooldown !== null) out.push({ kind: 'cooldown', ...endOf(def.cooldown), pace: def.easy, effort: 'easy', rep: null });
  return out;
}

/** ± a few seconds either side of a single target pace. */
export function around(pace: number, spread = 5): PaceRange {
  return { fast: pace - spread, slow: pace + spread };
}

export const PRESET_IDS = ['6x400', '5x1k', '8x200-strides', '10x1min', '3x2k-tempo'] as const;
export type PresetId = (typeof PRESET_IDS)[number];

export interface Preset {
  readonly id: PresetId;
  readonly name: string;
  readonly about: string;
  readonly steps: readonly WorkoutStep[];
}

/**
 * FITOS's ready-made sessions. With zones (from a plan or a recent race)
 * every work step carries its pace; without, the effort words stand.
 */
export function presets(z: PaceZones | null): Preset[] {
  const easy = z?.easy ?? null;
  const at = (p: number | undefined) => (p === undefined ? null : around(p));
  const ten = { seconds: 600 };
  const define = (blocks: RepeatBlock[], warm: StepEnd = ten, cool: StepEnd = ten): WorkoutStep[] =>
    expand({ warmup: warm, blocks, cooldown: cool, easy });
  return [
    {
      id: '6x400',
      name: '6 × 400 m',
      about: 'Speed: 400 m at interval pace, 90 s jog between.',
      steps: define([{ count: 6, work: { distanceM: 400 }, workPace: at(z?.interval), workEffort: 'hard, 3K effort', recover: { seconds: 90 }, recoverMode: 'jog' }]),
    },
    {
      id: '5x1k',
      name: '5 × 1 km',
      about: 'VO2max: 1 km at interval pace, 2 min jog between.',
      steps: define([{ count: 5, work: { distanceM: 1000 }, workPace: at(z?.interval), workEffort: 'hard, 5K effort', recover: { seconds: 120 }, recoverMode: 'jog' }]),
    },
    {
      id: '8x200-strides',
      name: '8 × 200 m strides',
      about: 'Form and leg speed: 200 m quick and relaxed, walk back.',
      steps: define([{ count: 8, work: { distanceM: 200 }, workPace: at(z?.repetition), workEffort: 'quick, relaxed', recover: { seconds: 60 }, recoverMode: 'walk' }]),
    },
    {
      id: '10x1min',
      name: '10 × 1 min on, 1 min off',
      about: 'A classic: one minute fast, one minute easy.',
      steps: define([{ count: 10, work: { seconds: 60 }, workPace: at(z?.interval), workEffort: 'fast', recover: { seconds: 60 }, recoverMode: 'jog' }]),
    },
    {
      id: '3x2k-tempo',
      name: '3 × 2 km tempo',
      about: 'Threshold: 2 km comfortably hard, 2 min jog between.',
      steps: define([{ count: 3, work: { distanceM: 2000 }, workPace: at(z?.threshold), workEffort: 'comfortably hard', recover: { seconds: 120 }, recoverMode: 'jog' }]),
    },
  ];
}

/**
 * A sprint session: reps of 60–400 m from a countdown start, standing (or
 * walking back) between them. Work steps carry no pace: it is all-out.
 */
export function sprints(count: number, distanceM: number, restSeconds: number): WorkoutStep[] {
  return expand({
    warmup: { seconds: 600 },
    blocks: [{ count, work: { distanceM }, workPace: null, workEffort: 'all out', recover: { seconds: restSeconds }, recoverMode: 'stand' }],
    cooldown: { seconds: 300 },
    easy: null,
  });
}

export const SPRINT_LIMITS = { minM: 60, maxM: 400, minCount: 1, maxCount: 20, minRest: 30, maxRest: 600 } as const;
