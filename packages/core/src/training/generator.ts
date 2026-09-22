/**
 * Workout programme generator (§12.2, §12.3). Pure and deterministic: the
 * same input always yields the same programme, and every exercise and every
 * omission carries a reason. No I/O — the catalogue is passed in.
 *
 * The algorithm, in the order the spec gives it:
 *  1. Split from (days/week × experience) — the §12.2 table, verbatim.
 *  2. Filter the catalogue: performable with the available equipment
 *     (bodyweight is always available), not contraindicated by any
 *     limitation, not above the lifter's level.
 *  3. Weekly volume target per muscle from the §12.3 landmarks and the
 *     goal's volume bias (§12.1), ramped ~10%/week toward MAV.
 *  4. Per session: select by movement pattern, compound-first, greedily
 *     covering the muscles that session owns; secondary involvement counts
 *     0.5 set (§12.3).
 *  5. Fit to the preferred session length at ~3.5 min per working set.
 *
 * What cannot be satisfied is reported, never silently dropped: a muscle
 * with no performable exercise, or one the time budget cannot bring to
 * MEV, appears in `shortfalls` with the reason.
 */
import type { Goal } from '../nutrition/targets.js';

/* ------------------------------------------------------------ vocabulary -- */

export const MUSCLE_GROUPS = [
  'chest', 'back', 'quads', 'hamstrings', 'glutes',
  'shoulders', 'biceps', 'triceps', 'calves', 'abs',
] as const;
export type MuscleGroup = (typeof MUSCLE_GROUPS)[number];

export const MOVEMENT_PATTERNS = [
  'squat', 'hinge', 'lunge', 'horizontal-push', 'vertical-push',
  'horizontal-pull', 'vertical-pull', 'elbow-flexion', 'elbow-extension',
  'shoulder-isolation', 'chest-isolation', 'leg-isolation', 'calf-raise',
  'core', 'carry',
] as const;
export type MovementPattern = (typeof MOVEMENT_PATTERNS)[number];

/** Session order is compound-first (§12.2); this is the order. */
export const PATTERN_ORDER: readonly MovementPattern[] = [
  'squat', 'hinge', 'lunge', 'horizontal-push', 'vertical-push',
  'horizontal-pull', 'vertical-pull', 'chest-isolation', 'shoulder-isolation',
  'leg-isolation', 'elbow-flexion', 'elbow-extension', 'calf-raise', 'core', 'carry',
];
export const COMPOUND = new Set<MovementPattern>([
  'squat', 'hinge', 'lunge', 'horizontal-push', 'vertical-push', 'horizontal-pull', 'vertical-pull',
]);

export const EQUIPMENT = [
  'barbell', 'dumbbell', 'machine', 'cable', 'kettlebell',
  'resistance-band', 'pull-up-bar', 'bodyweight',
] as const;
export type Equipment = (typeof EQUIPMENT)[number];

export const BODY_PARTS = [
  'neck', 'shoulder', 'elbow', 'wrist', 'lower-back', 'hip', 'knee', 'ankle',
] as const;
export type BodyPart = (typeof BODY_PARTS)[number];

export type Experience = 'beginner' | 'intermediate' | 'advanced';
export type Difficulty = Experience;

export type SplitType =
  | 'full-body'
  | 'upper-lower'
  | 'push-pull-legs'
  | 'upper-lower-full'
  | 'ppl-upper-lower';

/* ---------------------------------------------------------------- input -- */

export interface CatalogueExercise {
  readonly id: string;
  readonly slug: string;
  readonly name: string;
  readonly movementPattern: MovementPattern;
  readonly equipment: readonly Equipment[];
  readonly difficulty: Difficulty;
  readonly isUnilateral: boolean;
  readonly defaultIncrementKg: number;
  readonly primaryMuscles: readonly MuscleGroup[];
  readonly secondaryMuscles: readonly MuscleGroup[];
  readonly contraindications: readonly BodyPart[];
}

export interface GeneratorInput {
  readonly goal: Goal;
  readonly experience: Experience;
  /** 2–6 (§12.2). */
  readonly daysPerWeek: number;
  readonly availableEquipment: readonly Equipment[];
  readonly limitations: readonly BodyPart[];
  /** Target session length; the programme lands within ±15 % of it where volume allows. */
  readonly preferredSessionMinutes: number;
  /** 1-based; volume ramps ~10 %/week from MEV toward MAV (§12.3). */
  readonly mesocycleWeek: number;
  readonly catalogue: readonly CatalogueExercise[];
  /**
   * Muscles the lifter asked to prioritise (Phase 6.6). Their weekly target
   * moves up a band (`emphasisedTarget`); nothing else changes — the same
   * MAV-high ceiling, time fitting and coverage rules apply, so an emphasis
   * can only add sets the split and the session length have room for.
   */
  readonly emphasis?: readonly MuscleGroup[];
}

/* --------------------------------------------------------------- output -- */

export interface PlannedExercise {
  readonly exerciseId: string;
  readonly slug: string;
  readonly name: string;
  readonly orderIndex: number;
  readonly setCount: number;
  readonly repMin: number;
  readonly repMax: number;
  readonly targetRir: number;
  readonly incrementKg: number;
  /** Why this exercise, with what it contributes. Rendered verbatim. */
  readonly reason: string;
}

export interface ProgramDay {
  /** 1 = Monday … 7 = Sunday. */
  readonly dayOfWeek: number;
  readonly sessionName: string;
  readonly focus: readonly MuscleGroup[];
  readonly isRest: boolean;
  readonly exercises: readonly PlannedExercise[];
  /** ~3.5 min per working set (§12.2). */
  readonly estimatedMinutes: number;
}

export type ShortfallReason = 'no-performable-exercise' | 'session-time' | 'limitation';

export interface VolumeShortfall {
  readonly muscle: MuscleGroup;
  readonly targetSets: number;
  readonly plannedSets: number;
  readonly reason: ShortfallReason;
  readonly detail: string;
}

export interface GeneratedProgram {
  /** A §12.2 split type, or a template's slug. */
  readonly splitType: string;
  readonly daysPerWeek: number;
  readonly days: readonly ProgramDay[];
  /** Weekly hard sets per muscle, secondaries at 0.5. */
  readonly weeklyVolume: Readonly<Record<MuscleGroup, number>>;
  /** Weekly targets the generator aimed for, after goal bias and ramp. */
  readonly weeklyTargets: Readonly<Record<MuscleGroup, number>>;
  readonly shortfalls: readonly VolumeShortfall[];
  /** Plain-language justification of the programme as a whole. */
  readonly rationale: readonly string[];
}

/* ------------------------------------------------------- §12.3 landmarks -- */

export interface VolumeLandmark {
  readonly mv: number;
  readonly mev: number;
  readonly mavLow: number;
  readonly mavHigh: number;
  readonly mrv: number;
}

/** Weekly hard sets per muscle (§12.3). */
export const VOLUME_LANDMARKS: Readonly<Record<MuscleGroup, VolumeLandmark>> = {
  chest: { mv: 6, mev: 10, mavLow: 12, mavHigh: 18, mrv: 20 },
  back: { mv: 6, mev: 10, mavLow: 12, mavHigh: 18, mrv: 20 },
  quads: { mv: 6, mev: 10, mavLow: 12, mavHigh: 18, mrv: 20 },
  shoulders: { mv: 6, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24 },
  biceps: { mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 20 },
  triceps: { mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 20 },
  hamstrings: { mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 18 },
  glutes: { mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 18 },
  calves: { mv: 6, mev: 8, mavLow: 12, mavHigh: 16, mrv: 20 },
  abs: { mv: 6, mev: 8, mavLow: 12, mavHigh: 16, mrv: 20 },
};

export const SECONDARY_CONTRIBUTION = 0.5;
export const MINUTES_PER_WORKING_SET = 3.5;
export const MIN_EXERCISES_PER_SESSION = 3;
/** A normal session aims for min(this, ⌊minutes/12⌋) movements when volume allows. */
export const EXERCISE_COUNT_TARGET_MAX = 5;

/* ------------------------------------------------------ §12.1 parameters -- */

export interface GoalTrainingParams {
  readonly repMin: number;
  readonly repMax: number;
  /** Per experience: beginners get the more conservative end of the range. */
  readonly targetRir: Readonly<Record<Experience, number>>;
  readonly volumeBias: 'mev-to-mav' | 'mev' | 'mv-to-mev' | 'lower-volume';
}

/** §12.1, rep range / RIR / volume bias columns. */
export const GOAL_PARAMS: Readonly<Record<Goal, GoalTrainingParams>> = {
  'muscle-gain': { repMin: 6, repMax: 12, targetRir: { beginner: 2, intermediate: 1, advanced: 1 }, volumeBias: 'mev-to-mav' },
  'fat-loss': { repMin: 6, repMax: 12, targetRir: { beginner: 2, intermediate: 2, advanced: 2 }, volumeBias: 'mev' },
  recomposition: { repMin: 6, repMax: 12, targetRir: { beginner: 2, intermediate: 1, advanced: 1 }, volumeBias: 'mev-to-mav' },
  strength: { repMin: 3, repMax: 6, targetRir: { beginner: 3, intermediate: 2, advanced: 2 }, volumeBias: 'lower-volume' },
  general: { repMin: 8, repMax: 15, targetRir: { beginner: 3, intermediate: 2, advanced: 2 }, volumeBias: 'mev' },
  maintenance: { repMin: 6, repMax: 15, targetRir: { beginner: 2, intermediate: 2, advanced: 2 }, volumeBias: 'mv-to-mev' },
};

/**
 * Weekly target for a muscle at a given mesocycle week. Starts at the
 * goal's baseline and ramps 10 %/week toward MAV-high for biases that
 * progress; never above MAV-high, never below MV.
 */
export function weeklyTarget(muscle: MuscleGroup, goal: Goal, mesocycleWeek: number): number {
  const lm = VOLUME_LANDMARKS[muscle];
  const bias = GOAL_PARAMS[goal].volumeBias;
  const week = Math.max(1, Math.floor(mesocycleWeek));
  const ramp = (base: number, cap: number): number => Math.min(cap, Math.round(base * (1 + 0.1 * (week - 1))));
  switch (bias) {
    case 'mev-to-mav':
      return ramp(lm.mev, lm.mavHigh);
    case 'mev':
      return lm.mev;
    case 'mv-to-mev':
      return Math.round((lm.mv + lm.mev) / 2);
    case 'lower-volume':
      // Strength: fewer sets, heavier. MEV-ish for the big movers, MV for the rest.
      return Math.max(lm.mv, Math.round(lm.mev * 0.8));
  }
}

/** How far an emphasised muscle's target moves above the goal's baseline. */
export const EMPHASIS_FACTOR = 1.25;

/**
 * Weekly target for a muscle the lifter wants to prioritise: the goal's
 * target raised by `EMPHASIS_FACTOR`, at least MAV-low so the emphasis is
 * real for low-volume goals, never above MAV-high (the same ceiling every
 * muscle has). Deterministic; the AI never sets a number.
 */
export function emphasisedTarget(muscle: MuscleGroup, goal: Goal, mesocycleWeek: number): number {
  const lm = VOLUME_LANDMARKS[muscle];
  const base = weeklyTarget(muscle, goal, mesocycleWeek);
  return Math.min(lm.mavHigh, Math.max(lm.mavLow, Math.round(base * EMPHASIS_FACTOR)));
}

/* --------------------------------------------------------- §12.2 splits -- */

export interface SessionTemplate {
  readonly name: string;
  readonly muscles: readonly MuscleGroup[];
  /** Compound patterns the session always contains, need or no need (§12.2 "select by movement pattern"). */
  readonly required: readonly MovementPattern[];
  /** Patterns that belong to another day of the split (no presses on pull day). */
  readonly excluded: readonly MovementPattern[];
  /**
   * Muscles the session must train DIRECTLY — at least one exercise with
   * the muscle as a primary mover — whenever a performable one exists.
   * Secondary involvement counts toward volume, never toward this.
   */
  readonly directCoverage: readonly MuscleGroup[];
  /** Per-muscle preference within the coverage slot (rear delts on pull day). */
  readonly coverageHint?: Partial<Record<MuscleGroup, (ex: CatalogueExercise) => boolean>>;
}

const ALL: readonly MuscleGroup[] = MUSCLE_GROUPS;
const UPPER: readonly MuscleGroup[] = ['chest', 'back', 'shoulders', 'biceps', 'triceps'];
const LOWER: readonly MuscleGroup[] = ['quads', 'hamstrings', 'glutes', 'calves', 'abs'];
const PUSH: readonly MuscleGroup[] = ['chest', 'shoulders', 'triceps'];
/** Rear delts train with the pull day in PPL, so shoulders sit on both push and pull. */
const PULL: readonly MuscleGroup[] = ['back', 'biceps', 'shoulders'];
const LEGS: readonly MuscleGroup[] = LOWER;

const PUSHES: readonly MovementPattern[] = ['horizontal-push', 'vertical-push'];
const PULLS: readonly MovementPattern[] = ['horizontal-pull', 'vertical-pull'];

/** "Rear delt" work in a ten-muscle vocabulary: shoulders primary with the back also involved. */
const rearDelt = (ex: CatalogueExercise): boolean => ex.secondaryMuscles.includes('back');

export const FULL: SessionTemplate = {
  name: 'Full Body', muscles: ALL,
  required: ['squat', 'hinge', 'horizontal-push', 'horizontal-pull'], excluded: [],
  directCoverage: ['chest', 'back', 'quads', 'hamstrings', 'glutes', 'shoulders'],
};
export const UP: SessionTemplate = {
  name: 'Upper', muscles: UPPER,
  required: [...PUSHES, ...PULLS], excluded: [],
  directCoverage: ['chest', 'back', 'shoulders', 'biceps', 'triceps'],
};
export const LO: SessionTemplate = {
  name: 'Lower', muscles: LOWER,
  required: ['squat', 'hinge'], excluded: [],
  directCoverage: ['quads', 'hamstrings', 'glutes', 'calves'],
};
/** Trunk work (bird-dog, carries) lists the back as a primary; it is a legs/abs-day movement, never a pull-day "row". */
const TRUNK: readonly MovementPattern[] = ['core', 'carry'];

export const PU: SessionTemplate = {
  name: 'Push', muscles: PUSH,
  required: PUSHES, excluded: [...PULLS, 'elbow-flexion', ...TRUNK],
  directCoverage: ['chest', 'shoulders', 'triceps'],
};
export const PL: SessionTemplate = {
  name: 'Pull', muscles: PULL,
  required: PULLS, excluded: [...PUSHES, 'chest-isolation', 'elbow-extension', ...TRUNK],
  directCoverage: ['back', 'biceps', 'shoulders'],
  coverageHint: { shoulders: rearDelt },
};
export const LG: SessionTemplate = {
  name: 'Legs', muscles: LEGS,
  required: ['squat', 'hinge'], excluded: [],
  directCoverage: ['quads', 'hamstrings', 'glutes', 'calves'],
};

/** The §12.2 table, row by row. Throws outside 2–6 days. */
export function selectSplit(daysPerWeek: number, experience: Experience): { type: SplitType; sessions: readonly SessionTemplate[] } {
  const advancedOrInter = experience !== 'beginner';
  switch (daysPerWeek) {
    case 2:
      return { type: 'full-body', sessions: [FULL, FULL] };
    case 3:
      return experience === 'advanced'
        ? { type: 'push-pull-legs', sessions: [PU, PL, LG] }
        : { type: 'full-body', sessions: [FULL, FULL, FULL] };
    case 4:
      return { type: 'upper-lower', sessions: [UP, LO, UP, LO] };
    case 5:
      return advancedOrInter
        ? { type: 'ppl-upper-lower', sessions: [PU, PL, LG, UP, LO] }
        : { type: 'upper-lower-full', sessions: [UP, LO, UP, LO, FULL] };
    case 6:
      return advancedOrInter
        ? { type: 'push-pull-legs', sessions: [PU, PL, LG, PU, PL, LG] }
        : { type: 'upper-lower', sessions: [UP, LO, UP, LO, UP, LO] };
    default:
      throw new RangeError(`daysPerWeek must be 2–6, got ${daysPerWeek}`);
  }
}

/** Which weekdays the sessions land on, spreading rest days (1 = Monday). */
export function trainingDays(daysPerWeek: number): readonly number[] {
  switch (daysPerWeek) {
    case 2: return [1, 4];
    case 3: return [1, 3, 5];
    case 4: return [1, 2, 4, 5];
    case 5: return [1, 2, 3, 5, 6];
    case 6: return [1, 2, 3, 4, 5, 6];
    default: throw new RangeError(`daysPerWeek must be 2–6, got ${daysPerWeek}`);
  }
}

/* -------------------------------------------------------------- filters -- */

const LEVEL: Readonly<Record<Experience, number>> = { beginner: 0, intermediate: 1, advanced: 2 };

/** Beginners may use intermediate lifts (the barbell squat is one) but never advanced ones. */
function allowedByLevel(ex: CatalogueExercise, experience: Experience): boolean {
  return LEVEL[ex.difficulty] <= LEVEL[experience] + (experience === 'beginner' ? 1 : 2);
}

export function isPerformable(ex: CatalogueExercise, available: readonly Equipment[]): boolean {
  return ex.equipment.every((q) => q === 'bodyweight' || available.includes(q));
}

export function isContraindicated(ex: CatalogueExercise, limitations: readonly BodyPart[]): boolean {
  return ex.contraindications.some((part) => limitations.includes(part));
}

/* ------------------------------------------------------------ selection -- */

type Need = Record<MuscleGroup, number>;

function emptyNeed(): Need {
  const n = {} as Need;
  for (const m of MUSCLE_GROUPS) n[m] = 0;
  return n;
}

function contributionTo(ex: CatalogueExercise, m: MuscleGroup): number {
  if (ex.primaryMuscles.includes(m)) return 1;
  if (ex.secondaryMuscles.includes(m)) return SECONDARY_CONTRIBUTION;
  return 0;
}

/**
 * How much one set of `ex` reduces the remaining need of this session.
 * Primaries decide the choice; secondaries only break ties. (Volume is
 * still counted at 0.5 for secondaries — this is selection, not accounting.
 * Counting secondaries fully here made a jump squat beat a goblet squat
 * because it "also" hits calves.)
 */
function usefulness(ex: CatalogueExercise, need: Need, focus: ReadonlySet<MuscleGroup>): number {
  // The single best-served primary decides; every other muscle it touches
  // is a small extra, so a two-primary lift does not beat the canonical
  // one-primary lift for the slot (close-grip bench vs bench).
  let main = 0;
  let extra = 0;
  for (const m of MUSCLE_GROUPS) {
    if (!focus.has(m) || need[m] <= 0) continue;
    const c = contributionTo(ex, m);
    if (c === 0) continue;
    const served = Math.min(need[m], c);
    if (c === 1 && served > main) {
      extra += main * 0.02;
      main = served;
    } else {
      extra += served * 0.02;
    }
  }
  return main + extra;
}

function maxSetsFor(ex: CatalogueExercise, goal: Goal): number {
  const compound = COMPOUND.has(ex.movementPattern);
  if (goal === 'strength') return compound ? 5 : 3;
  return compound ? 4 : 3;
}

function fmtSets(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}

interface Selection {
  readonly exercise: CatalogueExercise;
  sets: number;
  /** Set when this is the only direct work for a required muscle; never dropped by time fitting. */
  coverageFor?: MuscleGroup;
}

/**
 * The muscle a pattern is "for". An exercise whose first primary muscle is
 * this one is the canonical choice for the slot: a bench press for the
 * horizontal push, not a close-grip bench (triceps first); a Romanian
 * deadlift for the hinge, not a back extension.
 */
const CANONICAL: Partial<Record<MovementPattern, MuscleGroup>> = {
  squat: 'quads',
  hinge: 'hamstrings',
  lunge: 'quads',
  'horizontal-push': 'chest',
  'vertical-push': 'shoulders',
  'horizontal-pull': 'back',
  'vertical-pull': 'back',
  'chest-isolation': 'chest',
  'shoulder-isolation': 'shoulders',
  'elbow-flexion': 'biceps',
  'elbow-extension': 'triceps',
  'calf-raise': 'calves',
  core: 'abs',
  carry: 'abs',
};

/**
 * How well an exercise's equipment supports progressive overload (§12.4):
 * a barbell steps in 2.5 kg, a band does not step at all. Used only as a
 * tie-breaker, and only when the lifter has something to load.
 */
const LOAD_QUALITY: Readonly<Record<Equipment, number>> = {
  barbell: 0.2,
  dumbbell: 0.19,
  machine: 0.18,
  cable: 0.18,
  kettlebell: 0.15,
  'pull-up-bar': 0.12,
  'resistance-band': 0.05,
  bodyweight: 0,
};

function loadQuality(ex: CatalogueExercise): number {
  return Math.max(...ex.equipment.map((q) => LOAD_QUALITY[q]));
}

/**
 * Greedy, deterministic selection for one session. Patterns in compound-first
 * order; within a pattern the exercise that covers the most remaining
 * PRIMARY need wins. Tie-breakers, in weight order, all far smaller than one
 * set of usefulness: the pattern's canonical lift; loadable over
 * bodyweight-only when the lifter has equipment (progressive overload needs
 * load, §12.4); bilateral compounds; the lifter's own level; not used
 * earlier this week (so PPL×2 varies); secondaries; slug.
 *
 * `weekCap` is how many more sets each muscle may receive this week before
 * MAV-high — never exceeded, whatever the session share says.
 */
function selectForSession(
  template: SessionTemplate,
  pool: readonly CatalogueExercise[],
  share: Need,
  weekCap: Need,
  goal: Goal,
  experience: Experience,
  hasLoad: boolean,
  usedThisWeek: ReadonlySet<string>,
  maxExercises: number,
  order: readonly MovementPattern[] = PATTERN_ORDER,
): Selection[] {
  const focus = new Set<MuscleGroup>(template.muscles);
  const need: Need = { ...share };
  const cap: Need = { ...weekCap };
  const picked: Selection[] = [];
  const pickedSlugs = new Set<string>();

  const excluded = new Set<MovementPattern>(template.excluded);
  const passes = [order, order];
  passes.forEach((patterns, pass) => {
    for (const pattern of patterns) {
      if (picked.length >= maxExercises) break;
      if (excluded.has(pattern)) continue;
      // A required pattern is filled on the first pass even when the numbers
      // say the muscle is covered: a push day has a press overhead.
      const mustHave = pass === 0 && template.required.includes(pattern) && !picked.some((p) => p.exercise.movementPattern === pattern);
      let best: CatalogueExercise | null = null;
      let bestScore = 0;
      let bestSets = 0;
      for (const ex of pool) {
        if (ex.movementPattern !== pattern || pickedSlugs.has(ex.slug)) continue;
        const primaryInFocus = ex.primaryMuscles.some((m) => focus.has(m));
        if (!primaryInFocus) continue;
        if (!mustHave && !ex.primaryMuscles.some((m) => focus.has(m) && need[m] > 0)) continue;
        // Sets this exercise may take without breaching ANY touched muscle's weekly cap.
        const room = Math.min(
          ...MUSCLE_GROUPS.filter((m) => contributionTo(ex, m) > 0).map((m) => cap[m] / contributionTo(ex, m)),
        );
        if (room < 2) continue;
        const u = mustHave ? Math.max(usefulness(ex, need, focus), 0.5) : usefulness(ex, need, focus);
        if (u <= 0) continue;
        const canonical = CANONICAL[pattern] !== undefined && ex.primaryMuscles[0] === CANONICAL[pattern] ? 0.3 : 0;
        const loadable = hasLoad ? loadQuality(ex) : 0;
        const bilateral = COMPOUND.has(pattern) && !ex.isUnilateral ? 0.05 : 0;
        // At or below the lifter's level is equally fine: staples (a bench
        // press, a lat pulldown) are not "beginner" lifts to be outgrown.
        const levelFit = LEVEL[ex.difficulty] <= LEVEL[experience] ? 0.02 : 0;
        const fresh = usedThisWeek.has(ex.slug) ? 0 : 0.005;
        const hinted = ex.primaryMuscles.some((m) => focus.has(m) && need[m] > 0 && template.coverageHint?.[m]?.(ex) === true) ? 0.1 : 0;
        const score = u + canonical + loadable + bilateral + levelFit + fresh + hinted;
        if (score > bestScore || (score === bestScore && best !== null && ex.slug < best.slug)) {
          best = ex;
          bestScore = score;
          const primaryNeed = Math.max(...ex.primaryMuscles.filter((m) => focus.has(m)).map((m) => need[m]));
          bestSets = Math.max(2, Math.min(maxSetsFor(ex, goal), Math.round(primaryNeed), Math.floor(room)));
        }
      }
      if (best === null) continue;
      picked.push({ exercise: best, sets: bestSets });
      pickedSlugs.add(best.slug);
      for (const m of MUSCLE_GROUPS) {
        need[m] -= bestSets * contributionTo(best, m);
        cap[m] -= bestSets * contributionTo(best, m);
      }
    }
  });
  return picked;
}

/* ----------------------------------------------------------- time fitting -- */

function minutesOf(selection: readonly Selection[]): number {
  return selection.reduce((s, x) => s + x.sets, 0) * MINUTES_PER_WORKING_SET;
}

/**
 * Trim to ≤ preferred × 1.15: first shave isolation sets to 2, then drop
 * the least useful exercise (last isolation, then last compound), until it
 * fits. Never trims a compound below 2 sets.
 */
function fitToTime(selection: Selection[], preferredMinutes: number): { trimmedSets: number; dropped: string[] } {
  const ceiling = preferredMinutes * 1.15;
  let trimmedSets = 0;
  const dropped: string[] = [];
  const isolation = (x: Selection): boolean => !COMPOUND.has(x.exercise.movementPattern);
  const shave = (pred: (x: Selection) => boolean): boolean => {
    for (let i = selection.length - 1; i >= 0; i--) {
      const x = selection[i]!;
      if (pred(x)) {
        x.sets -= 1;
        trimmedSets += 1;
        return true;
      }
    }
    return false;
  };
  const drop = (pred: (x: Selection) => boolean): boolean => {
    for (let i = selection.length - 1; i >= 0; i--) {
      if (pred(selection[i]!)) {
        dropped.push(selection[i]!.exercise.name);
        selection.splice(i, 1);
        return true;
      }
    }
    return false;
  };
  // Cheapest cut first, the muscle's only direct work last:
  //  1. a set off an isolation lift above 2 (unprotected, then protected)
  //  2. a set off a compound above 3
  //  3. drop an unprotected isolation lift, then an unprotected compound
  //  4. a set off anything above 2
  //  5. drop a protected lift — only when nothing else is left to cut
  while (minutesOf(selection) > ceiling && selection.length > 0) {
    if (shave((x) => isolation(x) && x.coverageFor === undefined && x.sets > 2)) continue;
    if (shave((x) => isolation(x) && x.sets > 2)) continue;
    if (shave((x) => !isolation(x) && x.sets > 3)) continue;
    if (selection.length > 1 && drop((x) => isolation(x) && x.coverageFor === undefined)) continue;
    if (selection.length > 1 && drop((x) => !isolation(x) && x.coverageFor === undefined)) continue;
    if (shave((x) => x.sets > 2)) continue;
    if (selection.length > 1 && drop(() => true)) continue;
    break;
  }
  return { trimmedSets, dropped };
}

/** Mark each exercise that is the ONLY direct work for a required muscle. */
function protectCoverage(selection: Selection[], template: SessionTemplate): void {
  for (const m of template.directCoverage) {
    const direct = selection.filter((x) => x.exercise.primaryMuscles.includes(m));
    if (direct.length === 1 && direct[0]!.coverageFor === undefined) direct[0]!.coverageFor = m;
  }
}

/**
 * Use the time the lifter offered: when a session lands under 85 % of the
 * preferred length and the goal's volume bias progresses toward MAV, add
 * sets to compounds first, one at a time, while the muscle stays under its
 * MAV-low share for the session. Goals held at MEV (fat loss, general,
 * maintenance, strength) are NOT filled — more sets in a deficit is the
 * wrong answer, so those sessions may simply be short, and say so.
 */
function fillToTime(
  selection: Selection[],
  preferredMinutes: number,
  goal: Goal,
  focus: ReadonlySet<MuscleGroup>,
  mavLowShare: Need,
  weekCap: Need,
  more: (residual: Need, remainingCap: Need, exclude: ReadonlySet<string>, allowance: number) => Selection[],
  maxExercises: number,
): number {
  if (GOAL_PARAMS[goal].volumeBias !== 'mev-to-mav') return 0;
  const floor = preferredMinutes * 0.85;
  let added = 0;
  const plannedHere = emptyNeed();
  for (const s of selection) for (const m of MUSCLE_GROUPS) plannedHere[m] += s.sets * contributionTo(s.exercise, m);
  const bump = (): boolean => {
    const ordered = [...selection].sort((a, b) => {
      const ca = COMPOUND.has(a.exercise.movementPattern) ? 0 : 1;
      const cb = COMPOUND.has(b.exercise.movementPattern) ? 0 : 1;
      return ca - cb;
    });
    let progress = false;
    for (const s of ordered) {
      if (s.sets >= maxSetsFor(s.exercise, goal) + 1) continue;
      const headroom = s.exercise.primaryMuscles.every(
        (m) => !focus.has(m) || plannedHere[m] + 1 <= mavLowShare[m],
      ) && MUSCLE_GROUPS.every((m) => contributionTo(s.exercise, m) === 0 || plannedHere[m] + contributionTo(s.exercise, m) <= weekCap[m]);
      if (!headroom) continue;
      s.sets += 1;
      added += 1;
      for (const m of MUSCLE_GROUPS) plannedHere[m] += contributionTo(s.exercise, m);
      progress = true;
      if (minutesOf(selection) >= floor) break;
    }
    return progress;
  };
  // More movements before more sets on the same movement: a session that
  // has time left gets another exercise for a muscle under its MAV-low
  // share, and only then do existing lifts gain a set.
  if (minutesOf(selection) < floor) {
    const residual = emptyNeed();
    for (const m of MUSCLE_GROUPS) if (focus.has(m)) residual[m] = Math.max(0, Math.min(mavLowShare[m] - plannedHere[m], weekCap[m] - plannedHere[m]));
    // Extra exercises stay under this session's MAV-low share for every
    // muscle they touch, primary or secondary — not just the weekly ceiling.
    const remainingCap = emptyNeed();
    for (const m of MUSCLE_GROUPS) {
      const weekly = weekCap[m] - plannedHere[m];
      remainingCap[m] = Math.max(0, focus.has(m) ? Math.min(weekly, mavLowShare[m] - plannedHere[m]) : weekly);
    }
    const exclude = new Set(selection.map((s) => s.exercise.slug));
    const allowance = Math.max(0, maxExercises - selection.length);
    for (const extra of more(residual, remainingCap, exclude, allowance)) {
      if (minutesOf(selection) >= floor) break;
      selection.push(extra);
      added += extra.sets;
      for (const m of MUSCLE_GROUPS) plannedHere[m] += extra.sets * contributionTo(extra.exercise, m);
    }
    while (minutesOf(selection) < floor && bump()) {
      /* keep bumping */
    }
  }
  return added;
}

/** For filling spare time: isolation first, compounds last. */
const FILL_ORDER: readonly MovementPattern[] = [
  ...PATTERN_ORDER.filter((p) => !COMPOUND.has(p)),
  ...PATTERN_ORDER.filter((p) => COMPOUND.has(p)),
];

/* ------------------------------------------------------------ generator -- */

export function generateProgram(input: GeneratorInput): GeneratedProgram {
  const split = selectSplit(input.daysPerWeek, input.experience);
  return buildProgram(
    {
      splitType: split.type,
      sessions: split.sessions,
      opening: `${input.daysPerWeek} days/week as ${input.experience}: ${describeSplit(split.type)} (§12.2).`,
    },
    input,
  );
}

/** A week of sessions to build, whatever chose them (the §12.2 table or a template). */
export interface WeekPlan {
  readonly splitType: string;
  readonly sessions: readonly SessionTemplate[];
  /** First line of the rationale: where this structure came from. */
  readonly opening: string;
}

/**
 * The engine proper: filter, target, select, cover, fit, fill, report — for
 * any list of session templates. `generateProgram` feeds it the §12.2 split;
 * `materializeTemplate` (templates.ts) feeds it a professional structure.
 */
export function buildProgram(week: WeekPlan, input: Omit<GeneratorInput, 'daysPerWeek'>): GeneratedProgram {
  const { goal, experience, mesocycleWeek } = input;
  const daysPerWeek = week.sessions.length;
  const preferred = Math.max(15, input.preferredSessionMinutes);
  const params = GOAL_PARAMS[goal];
  const split = { type: week.splitType, sessions: week.sessions };
  const weekdays = trainingDays(daysPerWeek);
  const rationale: string[] = [];

  rationale.push(week.opening);
  rationale.push(
    `${goal}: ${params.repMin}–${params.repMax} reps at ${params.targetRir[experience]} RIR, volume ${describeBias(params.volumeBias)}.`,
  );

  // 2. Filter the catalogue, deterministically ordered.
  const sorted = [...input.catalogue].sort((a, b) => (a.slug < b.slug ? -1 : a.slug > b.slug ? 1 : 0));
  const performable = sorted.filter((ex) => isPerformable(ex, input.availableEquipment));
  const safe = performable.filter((ex) => !isContraindicated(ex, input.limitations));
  const pool = safe.filter((ex) => allowedByLevel(ex, experience));
  const excludedByLimitation = performable.length - safe.length;
  if (excludedByLimitation > 0) {
    rationale.push(
      `${excludedByLimitation} exercise(s) excluded for your ${input.limitations.join(', ')} limitation(s).`,
    );
  }

  // 3. Weekly targets and each session's share of them.
  const emphasis = [...new Set(input.emphasis ?? [])].filter((m) => MUSCLE_GROUPS.includes(m));
  const targets = emptyNeed();
  for (const m of MUSCLE_GROUPS) {
    targets[m] = emphasis.includes(m) ? emphasisedTarget(m, goal, mesocycleWeek) : weeklyTarget(m, goal, mesocycleWeek);
  }
  const sessionsCovering = emptyNeed();
  for (const s of split.sessions) for (const m of s.muscles) sessionsCovering[m] += 1;
  if (emphasis.length > 0) {
    const applied = emphasis.filter((m) => sessionsCovering[m] > 0);
    const orphaned = emphasis.filter((m) => sessionsCovering[m] === 0);
    if (applied.length > 0) {
      rationale.push(
        `Emphasis on ${applied.join(', ')}: weekly target raised to ${applied.map((m) => `${targets[m]} sets`).join(', ')} (never above MAV-high).`,
      );
    }
    if (orphaned.length > 0) {
      rationale.push(
        `Emphasis on ${orphaned.join(', ')} cannot apply: no session in this split trains ${orphaned.length === 1 ? 'it' : 'them'} directly.`,
      );
    }
  }

  // 4. Select per session.
  // Seven for a beginner (a fourth pattern plus three accessories is plenty
  // to learn), eight otherwise.
  const maxExercises = experience === 'beginner' ? 7 : 8;
  const hasLoad = input.availableEquipment.some((q) => q !== 'bodyweight');
  const usedThisWeek = new Set<string>();
  const days: ProgramDay[] = [];
  const planned = emptyNeed();
  let totalTrimmed = 0;
  let totalAdded = 0;
  const allDropped: string[] = [];

  split.sessions.forEach((template, i) => {
    // Each session owning a muscle takes an equal share of its weekly
    // target. A fixed share, not "what is left": a first session that
    // overshoots (sets are whole numbers) must not starve the second.
    const share = emptyNeed();
    for (const m of template.muscles) share[m] = targets[m] / Math.max(1, sessionsCovering[m]);
    // Room left this week under MAV-high (§12.3) — a hard ceiling — minus
    // two sets reserved for each LATER session that must train the muscle
    // directly, so a leg day's squats cannot eat the glute day's hip thrust.
    const weekCap = emptyNeed();
    for (const m of MUSCLE_GROUPS) {
      const laterDirect = split.sessions.slice(i + 1).filter((s) => s.directCoverage.includes(m)).length;
      weekCap[m] = Math.max(0, VOLUME_LANDMARKS[m].mavHigh - planned[m] - 2 * laterDirect);
    }
    const selection = selectForSession(template, pool, share, weekCap, goal, experience, hasLoad, usedThisWeek, maxExercises);
    // Session floor: three exercises. Low-volume goals on many days can be
    // numerically complete with two big lifts; a session still needs a
    // third movement, taken from what the day's muscles have room for.
    if (selection.length < MIN_EXERCISES_PER_SESSION) {
      const here = emptyNeed();
      for (const x of selection) for (const m of MUSCLE_GROUPS) here[m] += x.sets * contributionTo(x.exercise, m);
      const residual = emptyNeed();
      const remaining = emptyNeed();
      for (const m of MUSCLE_GROUPS) {
        remaining[m] = Math.max(0, weekCap[m] - here[m]);
        if (template.muscles.includes(m)) residual[m] = Math.max(0, Math.min(VOLUME_LANDMARKS[m].mavLow / Math.max(1, sessionsCovering[m]) - here[m], remaining[m]));
      }
      const exclude = new Set(selection.map((x) => x.exercise.slug));
      const extra = selectForSession(
        { ...template, required: [] }, pool.filter((ex) => !exclude.has(ex.slug)), residual, remaining,
        goal, experience, hasLoad, usedThisWeek, MIN_EXERCISES_PER_SESSION - selection.length, FILL_ORDER,
      );
      for (const x of extra) { x.sets = 2; selection.push(x); }
    }
    // Direct coverage: every muscle the session owns gets a primary
    // exercise when one is performable. The numbers may say a muscle is
    // "covered" by secondaries (bench + press → triceps); the session still
    // trains it directly. Nothing is added past the weekly MAV-high cap,
    // and nothing is invented: no performable primary → the muscle shows up
    // in shortfalls exactly as before.
    for (const m of template.directCoverage) {
      if (selection.some((x) => x.exercise.primaryMuscles.includes(m))) continue;
      const here = emptyNeed();
      for (const x of selection) for (const mm of MUSCLE_GROUPS) here[mm] += x.sets * contributionTo(x.exercise, mm);
      const remaining = emptyNeed();
      for (const mm of MUSCLE_GROUPS) remaining[mm] = Math.max(0, weekCap[mm] - here[mm]);
      const only = emptyNeed();
      only[m] = Math.max(2, share[m] - here[m]);
      const exclude = new Set(selection.map((x) => x.exercise.slug));
      const [pick] = selectForSession(
        { ...template, required: [] }, pool.filter((ex) => !exclude.has(ex.slug) && ex.primaryMuscles.includes(m)),
        only, remaining, goal, experience, hasLoad, usedThisWeek, 1, FILL_ORDER,
      );
      if (pick === undefined) continue;
      pick.sets = Math.min(pick.sets, 3);
      pick.coverageFor = m;
      selection.push(pick);
    }
    protectCoverage(selection, template);
    // Compound-first in the session (§12.2), whatever pass found them.
    selection.sort((a, b) => PATTERN_ORDER.indexOf(a.exercise.movementPattern) - PATTERN_ORDER.indexOf(b.exercise.movementPattern));
    const { trimmedSets, dropped } = fitToTime(selection, preferred);
    totalTrimmed += trimmedSets;
    allDropped.push(...dropped);
    const mavLowShare = emptyNeed();
    for (const m of template.muscles) mavLowShare[m] = VOLUME_LANDMARKS[m].mavLow / Math.max(1, sessionsCovering[m]);
    const capAfter = emptyNeed();
    for (const m of MUSCLE_GROUPS) capAfter[m] = weekCap[m];
    totalAdded += fillToTime(
      selection, preferred, goal, new Set(template.muscles), mavLowShare, capAfter,
      (residual, remainingCap, exclude, allowance) =>
        selectForSession(
          { ...template, required: [] },
          pool.filter((ex) => !exclude.has(ex.slug)),
          residual, remainingCap, goal, experience, hasLoad, usedThisWeek, Math.min(3, allowance), FILL_ORDER,
        ),
      maxExercises,
    );
    // Exercise count: a normal session should not stop at three movements
    // when time and volume allow more. Target min(5, ⌊minutes/12⌋); extra
    // movements only take volume the muscle still has room for under its
    // weekly target share — never junk sets, never past the time ceiling.
    const countTarget = Math.min(EXERCISE_COUNT_TARGET_MAX, Math.floor(preferred / 12));
    if (selection.length < countTarget && minutesOf(selection) + 2 * MINUTES_PER_WORKING_SET <= preferred * 1.15) {
      const here = emptyNeed();
      for (const x of selection) for (const m of MUSCLE_GROUPS) here[m] += x.sets * contributionTo(x.exercise, m);
      const residual = emptyNeed();
      const remaining = emptyNeed();
      for (const m of MUSCLE_GROUPS) {
        remaining[m] = Math.max(0, weekCap[m] - here[m]);
        if (template.muscles.includes(m)) residual[m] = Math.max(0, Math.min(mavLowShare[m] - here[m], remaining[m]));
      }
      const exclude = new Set(selection.map((x) => x.exercise.slug));
      const extra = selectForSession(
        { ...template, required: [] }, pool.filter((ex) => !exclude.has(ex.slug)), residual, remaining,
        goal, experience, hasLoad, usedThisWeek, Math.min(countTarget - selection.length, Math.max(0, maxExercises - selection.length)), FILL_ORDER,
      );
      for (const x of extra) {
        if (minutesOf(selection) + 2 * MINUTES_PER_WORKING_SET > preferred * 1.15) break;
        x.sets = 2;
        selection.push(x);
        totalAdded += 2;
      }
    }
    selection.sort((a, b) => PATTERN_ORDER.indexOf(a.exercise.movementPattern) - PATTERN_ORDER.indexOf(b.exercise.movementPattern));

    const exercises: PlannedExercise[] = selection.map((s, orderIndex) => {
      usedThisWeek.add(s.exercise.slug);
      const gives = MUSCLE_GROUPS.filter((m) => contributionTo(s.exercise, m) > 0 && template.muscles.includes(m))
        .map((m) => `${m} ${fmtSets(s.sets * contributionTo(s.exercise, m))}`)
        .join(', ');
      for (const m of MUSCLE_GROUPS) planned[m] += s.sets * contributionTo(s.exercise, m);
      return {
        exerciseId: s.exercise.id,
        slug: s.exercise.slug,
        name: s.exercise.name,
        orderIndex,
        setCount: s.sets,
        repMin: params.repMin,
        repMax: params.repMax,
        targetRir: params.targetRir[experience],
        incrementKg: s.exercise.defaultIncrementKg,
        reason: `${patternLabel(s.exercise.movementPattern)} for ${s.exercise.primaryMuscles.filter((m) => template.muscles.includes(m)).join(' and ')}: ${s.sets} sets → ${gives}.`,
      };
    });

    days.push({
      dayOfWeek: weekdays[i]!,
      sessionName: template.name,
      focus: template.muscles,
      isRest: false,
      exercises,
      estimatedMinutes: Math.round(minutesOf(selection)),
    });
  });

  // Rest days, so a week is always seven rows.
  for (let d = 1; d <= 7; d++) {
    if (!weekdays.includes(d)) {
      days.push({ dayOfWeek: d, sessionName: 'Rest', focus: [], isRest: true, exercises: [], estimatedMinutes: 0 });
    }
  }
  days.sort((a, b) => a.dayOfWeek - b.dayOfWeek);

  // 5. Report what could not be met, and why.
  const shortfalls: VolumeShortfall[] = [];
  for (const m of MUSCLE_GROUPS) {
    const mev = VOLUME_LANDMARKS[m].mev;
    const floor = Math.min(targets[m], mev);
    if (planned[m] + 1e-9 >= floor) continue;
    const anyPrimary = pool.some((ex) => ex.primaryMuscles.includes(m));
    const anyPerformablePrimary = performable.some((ex) => ex.primaryMuscles.includes(m));
    const reason: ShortfallReason = !anyPerformablePrimary
      ? 'no-performable-exercise'
      : !anyPrimary
        ? 'limitation'
        : 'session-time';
    const detail =
      reason === 'no-performable-exercise'
        ? `No exercise in the library trains ${m} as a primary mover with ${describeKit(input.availableEquipment)}; it gets ${fmtSets(planned[m])} sets from secondary work.`
        : reason === 'limitation'
          ? `Every ${m} exercise you could perform is contraindicated by your ${input.limitations.join(', ')} limitation(s).`
          : `${preferred}-minute sessions × ${daysPerWeek} days leave ${fmtSets(planned[m])} of ${targets[m]} sets for ${m}; add a day or minutes to reach MEV.`;
    shortfalls.push({ muscle: m, targetSets: targets[m], plannedSets: round1(planned[m]), reason, detail });
  }
  if (totalTrimmed > 0 || allDropped.length > 0) {
    rationale.push(
      `Fitted to ~${preferred} min/session at ${MINUTES_PER_WORKING_SET} min per working set: ${totalTrimmed} set(s) trimmed` +
        (allDropped.length > 0 ? `, dropped ${allDropped.join(', ')}.` : '.'),
    );
  }
  if (totalAdded > 0) {
    rationale.push(`Added ${totalAdded} set(s) to use your ${preferred}-minute sessions, staying under MAV.`);
  }
  const shortSessions = days.filter((d) => !d.isRest && d.estimatedMinutes < preferred * 0.85).length;
  if (shortSessions > 0 && params.volumeBias === 'mev-to-mav') {
    rationale.push(
      `${shortSessions} session(s) finish under your ${preferred} minutes: week ${Math.max(1, Math.floor(mesocycleWeek))} volume is capped at the low end of MAV; it ramps ~10 % a week (§12.3).`,
    );
  }
  if (shortSessions > 0 && params.volumeBias !== 'mev-to-mav') {
    rationale.push(
      `${shortSessions} session(s) finish under your ${preferred} minutes: volume is ${describeBias(params.volumeBias)} for ${goal}, so the time is not filled with extra sets.`,
    );
  }
  if (shortfalls.length === 0) {
    rationale.push('Every muscle reaches its weekly target.');
  } else {
    rationale.push(`Below target: ${shortfalls.map((s) => `${s.muscle} (${s.reason})`).join(', ')}.`);
  }

  const weeklyVolume = emptyNeed();
  for (const m of MUSCLE_GROUPS) weeklyVolume[m] = round1(planned[m]);

  return { splitType: split.type, daysPerWeek, days, weeklyVolume, weeklyTargets: targets, shortfalls, rationale };
}

/* -------------------------------------------------------------- helpers -- */

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

function describeSplit(t: SplitType): string {
  switch (t) {
    case 'full-body': return 'full body each session';
    case 'upper-lower': return 'upper / lower';
    case 'push-pull-legs': return 'push / pull / legs';
    case 'upper-lower-full': return 'upper / lower / upper / lower / full body';
    case 'ppl-upper-lower': return 'push / pull / legs / upper / lower';
  }
}

function describeBias(b: GoalTrainingParams['volumeBias']): string {
  switch (b) {
    case 'mev-to-mav': return 'from MEV ramping toward MAV';
    case 'mev': return 'held at MEV';
    case 'mv-to-mev': return 'between MV and MEV';
    case 'lower-volume': return 'lower volume, higher intensity';
  }
}

function describeKit(kit: readonly Equipment[]): string {
  const named = kit.filter((q) => q !== 'bodyweight');
  return named.length === 0 ? 'bodyweight only' : named.join(', ');
}

function patternLabel(p: MovementPattern): string {
  return p.replace(/-/g, ' ');
}
