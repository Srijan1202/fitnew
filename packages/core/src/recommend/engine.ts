/**
 * The decision layer behind the TODAY screen.
 *
 * Takes the whole user model, generates every action that is currently
 * justified, scores them, and returns a short ranked list. Deterministic: the
 * same state always yields the same actions in the same order.
 *
 * An LLM may later rephrase `headline` and `detail` for tone. It may not add,
 * remove, reorder or renumber anything here.
 */

import type { Goal } from '../nutrition/targets.js';
import type { ProgressionRecommendation } from '../training/progression.js';

export type ActionKind =
  | 'start-workout'
  | 'progress-load'
  | 'rest-day'
  | 'deload'
  | 'eat-protein'
  | 'eat-meal'
  | 'calorie-adjust'
  | 'log-weight'
  | 'add-steps'
  | 'hydrate'
  | 'muscle-neglected'
  | 'celebrate-pr';

/** Where the action sends the user. Keeps navigation out of the UI's head. */
export type ActionTarget = 'train' | 'eat' | 'progress' | 'today';

export interface Action {
  readonly kind: ActionKind;
  readonly headline: string;
  readonly detail: string;
  readonly target: ActionTarget;
  /** Higher surfaces first. Computed, not hand-assigned per action. */
  readonly priority: number;
  /** Machine-readable provenance so the UI can badge estimates honestly. */
  readonly basis: 'logged' | 'calculated' | 'estimated';
}

export interface UserModel {
  readonly goal: Goal;
  readonly dietPreference: 'vegetarian' | 'eggetarian' | 'non-vegetarian';

  // --- training ----------------------------------------------------------
  /** Null on a scheduled rest day. */
  readonly todaysSessionName: string | null;
  readonly todaysSessionMinutes: number | null;
  readonly workoutCompletedToday: boolean;
  readonly daysSinceLastWorkout: number | null;
  /** Muscle groups not trained in the last 7 days, from logged sets. */
  readonly neglectedMuscles: readonly string[];
  readonly leadLiftProgression: ProgressionRecommendation | null;
  readonly newPrToday: string | null;

  // --- nutrition ---------------------------------------------------------
  readonly kcalConsumed: number;
  readonly kcalTarget: number;
  readonly proteinConsumed: number;
  readonly proteinTarget: number;
  /** Meal the user has not yet logged and can still eat today. */
  readonly nextMealSlot: 'breakfast' | 'lunch' | 'snacks' | 'dinner' | null;
  readonly messConfigured: boolean;

  // --- body / adherence --------------------------------------------------
  readonly loggedWeightToday: boolean;
  readonly daysSinceWeighIn: number | null;
  readonly pendingCalorieAdjustment: { readonly deltaKcal: number; readonly reason: string } | null;
  readonly stepsToday: number | null;
  readonly weeklyAdherence: number; // 0..1
}

const PROTEIN_SHORTFALL_THRESHOLD = 0.75; // below 75% of target with a meal left
const NEGLECT_DAYS = 6;

function pct(part: number, whole: number): number {
  return whole > 0 ? part / whole : 0;
}

/**
 * Priority model. Kept as one readable function rather than scattered magic
 * numbers so the ordering can be reasoned about and tested.
 *
 * Bands:
 *   90+  time-critical and actionable right now (train, eat before mess closes)
 *   70+  today's remaining obligations
 *   50+  useful nudges
 *   30+  informational
 */
function priorityFor(kind: ActionKind, model: UserModel): number {
  switch (kind) {
    case 'deload':
      return 95; // safety first: never bury a fatigue warning under a meal tip
    case 'start-workout':
      return 90;
    case 'eat-protein':
      return model.nextMealSlot === 'dinner' ? 88 : 80;
    case 'eat-meal':
      return 75;
    case 'progress-load':
      return 72;
    case 'muscle-neglected':
      return 68;
    case 'rest-day':
      return 60;
    case 'calorie-adjust':
      return 55;
    case 'celebrate-pr':
      return 50;
    case 'log-weight':
      return 45;
    case 'add-steps':
      return 40;
    case 'hydrate':
      return 30;
  }
}

export function buildActions(model: UserModel): Action[] {
  const actions: Action[] = [];
  const push = (
    kind: ActionKind,
    headline: string,
    detail: string,
    target: ActionTarget,
    basis: Action['basis'],
  ): void => {
    actions.push({ kind, headline, detail, target, priority: priorityFor(kind, model), basis });
  };

  /* ---------------------------------------------------------- training -- */

  const progression = model.leadLiftProgression;
  if (progression !== null && progression.action === 'deload') {
    push(
      'deload',
      'Take a lighter week',
      progression.reason,
      'train',
      'calculated',
    );
  }

  if (model.todaysSessionName !== null && !model.workoutCompletedToday) {
    const minutes = model.todaysSessionMinutes;
    push(
      'start-workout',
      model.todaysSessionName,
      minutes === null ? 'Your session is ready.' : `About ${minutes} minutes.`,
      'train',
      'calculated',
    );
  }

  if (
    model.todaysSessionName === null &&
    !model.workoutCompletedToday &&
    (progression === null || progression.action !== 'deload')
  ) {
    push(
      'rest-day',
      'Recovery day',
      model.daysSinceLastWorkout === null
        ? 'No session scheduled. Eat to target and move a little.'
        : `Last session was ${model.daysSinceLastWorkout} day${model.daysSinceLastWorkout === 1 ? '' : 's'} ago. Growth happens now, not in the gym.`,
      'today',
      'calculated',
    );
  }

  if (
    progression !== null &&
    progression.action === 'increase-load' &&
    model.todaysSessionName !== null &&
    !model.workoutCompletedToday
  ) {
    push('progress-load', 'Load goes up today', progression.reason, 'train', 'calculated');
  }

  for (const muscle of model.neglectedMuscles.slice(0, 1)) {
    push(
      'muscle-neglected',
      `${muscle} is behind`,
      `You have not trained ${muscle.toLowerCase()} in ${NEGLECT_DAYS}+ days. It is falling below the volume that drives growth.`,
      'train',
      'logged',
    );
  }

  if (model.newPrToday !== null) {
    push('celebrate-pr', 'New personal record', model.newPrToday, 'progress', 'logged');
  }

  /* --------------------------------------------------------- nutrition -- */

  const proteinRatio = pct(model.proteinConsumed, model.proteinTarget);
  const proteinRemaining = Math.max(0, model.proteinTarget - model.proteinConsumed);
  const kcalRemaining = Math.max(0, model.kcalTarget - model.kcalConsumed);

  if (proteinRatio < PROTEIN_SHORTFALL_THRESHOLD && model.nextMealSlot !== null) {
    push(
      'eat-protein',
      `${Math.round(proteinRemaining)} g protein to go`,
      model.messConfigured
        ? `You have about ${Math.round(kcalRemaining)} kcal left. Let's find the highest-protein combination at ${model.nextMealSlot}.`
        : `You have about ${Math.round(kcalRemaining)} kcal left. Prioritise a protein source at ${model.nextMealSlot}.`,
      'eat',
      'calculated',
    );
  } else if (model.nextMealSlot !== null && kcalRemaining > 250) {
    push(
      'eat-meal',
      `${model.nextMealSlot.charAt(0).toUpperCase()}${model.nextMealSlot.slice(1)}`,
      `About ${Math.round(kcalRemaining)} kcal and ${Math.round(proteinRemaining)} g protein left today.`,
      'eat',
      'calculated',
    );
  }

  const adjustment = model.pendingCalorieAdjustment;
  if (adjustment !== null) {
    const direction = adjustment.deltaKcal > 0 ? 'up' : 'down';
    push(
      'calorie-adjust',
      `Calories move ${direction} ${Math.abs(adjustment.deltaKcal)}`,
      adjustment.reason,
      'progress',
      'calculated',
    );
  }

  /* ---------------------------------------------------- body / habits -- */

  if (!model.loggedWeightToday && (model.daysSinceWeighIn ?? 99) >= 2) {
    push(
      'log-weight',
      'Log your weight',
      'Daily readings feed the trend line. Individual numbers do not matter; the trend does.',
      'progress',
      'calculated',
    );
  }

  if (model.stepsToday !== null && model.stepsToday < 4000 && model.todaysSessionName === null) {
    push(
      'add-steps',
      'Get a walk in',
      `${model.stepsToday.toLocaleString()} steps so far. A 20-minute walk aids recovery without adding fatigue.`,
      'today',
      'logged',
    );
  }

  return actions.sort((a, b) => b.priority - a.priority);
}

/**
 * The TODAY screen shows a handful of actions, not everything that is true.
 * Two actions competing for the same decision (eat-protein vs eat-meal) are
 * already mutually exclusive above; this just caps the list.
 */
export function topActions(model: UserModel, limit = 4): Action[] {
  return buildActions(model).slice(0, limit);
}
