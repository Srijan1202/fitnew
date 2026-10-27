/**
 * The decision layer behind TODAY (MASTER-SPEC §16; Phase 11, ADR-017).
 *
 * Takes the server-assembled `UserModel`, generates every action that is
 * currently justified, ranks them by the §16.1 priority bands and returns at
 * most four. Deterministic: the same model always yields the same actions,
 * reasons, wording, hashes and digest, in the same order.
 *
 * Each action carries a structured reason (`code` + `values`) — the
 * machine-readable source of truth — and deterministic English
 * `headline` / `detail` produced here from those values alone. No LLM
 * chooses, orders or words anything (owner D3, D14).
 *
 * The server owns only the rules it has authoritative data for (D2, D5).
 * Resume, sleep, steps and the Health Connect prompt stay on the phone
 * (ADR-008/009); `hydrate` (no data) and `add-steps` (device-only) are not
 * built here. `calorie-adjust` arrived in Phase 12 (ADR-018) and
 * `low-readiness` in Phase 13 (ADR-019): both only suggest — nothing in the
 * plan or the targets changes unless the user accepts.
 */

import { localDateOf, localHourOf } from '../nutrition/log.js';
import type { Goal } from '../nutrition/targets.js';
import { defaultRecommendationSlot } from '../mess/recommendation.js';
import type { MealSlot } from '../mess/types.js';
import type { ReadinessBand } from '../recovery/readiness.js';
import { canonicalJson, sha256Hex } from './hash.js';

/** Bump when rules, wording or hashing change; stored with every action row. */
export const ENGINE_VERSION = 'today-3';

/** The approved server action vocabulary (D5 + P1), in tie-break order. */
export const ACTION_KINDS = [
  'deload',
  'injured-limitation',
  'start-workout',
  'low-readiness',
  'eat-protein',
  'eat-meal',
  'progress-load',
  'muscle-neglected',
  'rest-day',
  'calorie-adjust',
  'celebrate-pr',
  'log-weight',
  // Beta 4.1 (ADR-039): a running plan's run for today.
  'start-run',
] as const;
export type ActionKind = (typeof ACTION_KINDS)[number];

/** §16.1 bands; `injured-limitation` at 91 per owner P1. Pinned by tests. */
export const PRIORITIES = {
  deload: 95,
  'injured-limitation': 91,
  'start-workout': 90,
  // Phase 13 (§18; ADR-019 D9): beside the session it is about, advisory only.
  'low-readiness': 89,
  'eat-protein': { dinner: 88, other: 80 },
  'eat-meal': 75,
  'progress-load': 72,
  'muscle-neglected': 68,
  'rest-day': 60,
  // Phase 12 (the Phase 11 amendment's deferral; §16.1 band).
  'calorie-adjust': 55,
  'celebrate-pr': 50,
  'log-weight': 45,
  // Beta 4.1: under the gym session and its readiness note, above food.
  'start-run': 87,
} as const;

/** At most this many actions reach the surface (§16.1). */
export const MAX_ACTIONS = 4;
/** P7: no eat action from 22:00 local (21:59 is still eligible). */
export const EAT_CUTOFF_HOUR = 22;
/** §16.1: protein below 75 % of target (at the HIGH end of the logged range). */
export const PROTEIN_SHORTFALL_THRESHOLD = 0.75;
/** §16.1: more than 250 kcal left (at the LOW end: target − eaten high). */
export const MEAL_KCAL_LEFT_MIN = 250;
/** §16.1: no weigh-in for 2+ days. */
export const WEIGH_IN_DUE_DAYS = 2;
/** Minutes per planned set, including rest (§12). */
export const MINUTES_PER_SET = 3.5;

export const REASON_CODES = [
  'deload-offered',
  'exercise-contraindicated',
  'session-scheduled',
  'readiness-low',
  'protein-behind',
  'meal-remaining',
  'load-increase-due',
  'muscle-untrained',
  'rest-day',
  'calorie-target-off-trend',
  'pr-today',
  'weigh-in-due',
  'run-scheduled',
] as const;
export type ReasonCode = (typeof REASON_CODES)[number];

export type ReasonValue = string | number | boolean | null | readonly string[];
export interface ActionReason {
  readonly code: ReasonCode;
  readonly values: Readonly<Record<string, ReasonValue>>;
}

/** Where the action sends the user. */
export type ActionTarget = 'train' | 'eat' | 'progress' | 'today';
/** §16.1: provenance, so the UI can badge estimates honestly. */
export type ActionBasis = 'logged' | 'calculated' | 'estimated';

export interface Action {
  readonly kind: ActionKind;
  /** What the action is about within its kind ('' when there is only ever one). */
  readonly subjectKey: string;
  readonly priority: number;
  /** Current rank, 1-based, after suppression. Never part of the content hash (P5). */
  readonly rank: number;
  readonly basis: ActionBasis;
  readonly target: ActionTarget;
  readonly reason: ActionReason;
  readonly headline: string;
  readonly detail: string;
  readonly engineVersion: string;
  /** sha256 of the action's content (everything above except rank). */
  readonly contentHash: string;
}

/* -------------------------------------------------------------- model -- */

export type DeloadState = 'none' | 'offered' | 'active';
export type DeloadTrigger = 'fatigue' | 'mrv' | 'readiness';
export type PrType = '1rm_est' | 'weight' | 'reps' | 'volume';

export interface TrainingState {
  /** The user has a programme at all. */
  readonly hasProgramme: boolean;
  /** Today's scheduled session; null on a rest day or without a programme. */
  readonly sessionName: string | null;
  readonly exerciseCount: number;
  readonly plannedSetCount: number;
  readonly completedToday: boolean;
  /** A session is open (the phone shows "resume"; the server does not suggest starting). */
  readonly activeSessionOpen: boolean;
  readonly deload: { readonly state: DeloadState; readonly trigger: DeloadTrigger | null };
  /** Today's exercises whose progression is `increase-load`, in plan order. */
  readonly increaseLoad: readonly {
    readonly exerciseId: string;
    readonly exerciseName: string;
    readonly weightKg: number | null;
    readonly repTarget: string;
  }[];
  /**
   * Today's planned exercises ruled out by an active limitation
   * (`/training/today` substitution with trigger `limitation`), in plan
   * order, with the library's safer swap when there is one.
   */
  readonly limitationSwaps: readonly {
    readonly exerciseId: string;
    readonly exerciseName: string;
    readonly bodyParts: readonly string[];
    readonly alternativeId: string | null;
    readonly alternativeName: string | null;
  }[];
  /** Owned muscles with no working set in 6+ days, as the server orders them. */
  readonly neglected: readonly { readonly muscle: string; readonly daysSince: number | null }[];
  /** Records set on the local date, earliest first. */
  readonly prsToday: readonly {
    readonly prId: string;
    readonly exerciseName: string;
    readonly prType: PrType;
    readonly value: number;
    readonly previous: number;
  }[];
  /** The next scheduled session after today, for the rest-day action (§16.2). */
  readonly nextSession: { readonly name: string; readonly date: string } | null;
  /**
   * Phase 13: today's accessory (non-compound) exercises that are not ruled
   * out, in plan order — what "one fewer set on accessories" is about.
   */
  readonly accessories: readonly string[];
}

export interface NutritionState {
  readonly targets: { readonly kcal: number; readonly proteinG: number } | null;
  /** What was eaten today, as the Phase 8 ranges. */
  readonly eaten: {
    readonly kcalLow: number;
    readonly kcalHigh: number;
    readonly proteinLow: number;
    readonly proteinHigh: number;
  };
  /** Meals with at least one log today. */
  readonly loggedSlots: readonly MealSlot[];
  /**
   * Phase 12: the §13.2 adjustment policy's decision, when it fired
   * (`calorieAdjustmentFrom` in model.ts); null otherwise.
   */
  readonly adjustment: CalorieAdjustmentFact | null;
}

/** A calorie-target change the §13.2 policy proposes (advisory; the user accepts it). */
export interface CalorieAdjustmentFact {
  readonly currentKcal: number;
  readonly newKcal: number;
  /** newKcal − currentKcal; ±150 at most, a multiple of 10. */
  readonly deltaKcal: number;
  /** The trend's weekly change (kg/week) the decision was made from. */
  readonly weeklyChangeKg: number;
}

/** Phase 13 (§18): today's readiness from the check-in; nulls when there is none. */
export interface RecoveryState {
  readonly readiness: number | null;
  readonly band: ReadinessBand | null;
  /** Local days running with readiness under 35 (`lowReadinessRun`). */
  readonly lowDays: number;
}

export interface BodyState {
  readonly weighedToday: boolean;
  /** Days since the latest weight reading; null when there is none. */
  readonly daysSinceWeighIn: number | null;
}

/** Beta 4.1 (ADR-039): today's run from a running plan. */
export interface RunningState {
  /** The plan's run for today, or null (no plan, or nothing planned today). */
  readonly planned: {
    readonly plannedRunId: string;
    readonly title: string;
    readonly distanceM: number | null;
    readonly seconds: number | null;
    /** Seconds per km. */
    readonly paceFast: number | null;
    readonly paceSlow: number | null;
  } | null;
  /** Today's planned run is done (a run is linked to it). */
  readonly doneToday: boolean;
}

/** The whole user state TODAY decides from (server-assembled; ADR-017). */
export interface UserModel {
  /** yyyy-mm-dd in the user's zone. */
  readonly localDate: string;
  /** 0–23 in the user's zone (never UTC). */
  readonly hourOfDay: number;
  readonly goal: Goal;
  readonly training: TrainingState;
  readonly nutrition: NutritionState;
  readonly body: BodyState;
  readonly recovery: RecoveryState;
  /** Beta 4.1: absent for a user without a running plan (and in older models). */
  readonly running?: RunningState;
  /** (kind, subject) the user dismissed today: hidden for the rest of the local day (D7). */
  readonly dismissedToday: readonly { readonly kind: ActionKind; readonly subjectKey: string }[];
}

export interface TodayResult {
  readonly engineVersion: string;
  readonly localDate: string;
  /** sha256 of the canonical `UserModel` (D16: only the digest is stored). */
  readonly inputDigest: string;
  readonly actions: readonly Action[];
}

/** The user's local date and hour for an instant — TODAY never uses UTC (P7). */
export function todayClock(instant: Date, timeZone: string): { localDate: string; hourOfDay: number } {
  return { localDate: localDateOf(instant, timeZone), hourOfDay: localHourOf(instant, timeZone) };
}

/* -------------------------------------------------------------- words -- */

const r1 = (v: number): number => Math.round(v * 10) / 10;
const num = (v: number): string => (Number.isInteger(v) ? String(v) : v.toFixed(1));
const range = (lo: number, hi: number): string => (lo === hi ? num(lo) : `${num(lo)}–${num(hi)}`);
const title = (s: string): string => s.charAt(0).toUpperCase() + s.slice(1);
const label = (s: string): string => s.replace(/-/g, ' ');
const list = (xs: readonly string[]): string =>
  xs.length <= 1 ? xs.join('') : `${xs.slice(0, -1).join(', ')} and ${xs[xs.length - 1]}`;
const plural = (n: number, one: string, many = `${one}s`): string => `${n} ${n === 1 ? one : many}`;
/** Seconds as m:ss (a pace). */
const mss = (sec: number): string => `${Math.floor(sec / 60)}:${String(Math.round(sec % 60)).padStart(2, '0')}`;

const PR_WORDS: Readonly<Record<PrType, (value: number, previous: number) => string>> = {
  weight: (v, p) => `${num(v)} kg, up from ${num(p)} kg.`,
  reps: (v, p) => `${num(v)} reps, up from ${num(p)}.`,
  '1rm_est': (v, p) => `Estimated one-rep max ${num(v)} kg, up from ${num(p)} kg.`,
  volume: (v, p) => `${num(v)} kg lifted in one set, up from ${num(p)} kg.`,
};

/**
 * Deterministic English for a reason. Only the reason's values are read, so
 * the words can never say something the structured reason does not.
 */
export function wordReason(reason: ActionReason): { headline: string; detail: string } {
  const v = reason.values;
  const s = (k: string): string => String(v[k] ?? '');
  const n = (k: string): number => Number(v[k] ?? 0);
  switch (reason.code) {
    case 'deload-offered':
      return {
        headline: 'Take a lighter week',
        detail:
          v['trigger'] === 'mrv'
            ? 'Your weekly volume has reached what you can recover from. A lighter week is offered; nothing changes until you accept it.'
            : v['trigger'] === 'readiness'
              ? 'Your readiness has been under 35 for three days or more. A lighter week is offered; nothing changes until you accept it.'
              : 'Your recent sessions show fatigue building. A lighter week is offered; nothing changes until you accept it.',
      };
    case 'exercise-contraindicated': {
      const more = n('affectedCount') - 1;
      return {
        headline: `Swap ${s('exerciseName')} for ${s('alternativeName')}`,
        detail:
          `${s('exerciseName')} is ruled out by your ${list((v['bodyParts'] as readonly string[]).map(label))} limitation. ` +
          `${s('alternativeName')} is the safer swap for today.` +
          (more > 0 ? ` ${plural(more, 'more exercise')} today ${more === 1 ? 'has' : 'have'} a safer swap too.` : ''),
      };
    }
    case 'session-scheduled':
      return {
        headline: s('sessionName'),
        detail: `${plural(n('exerciseCount'), 'exercise')} · about ${n('minutes')} minutes.`,
      };
    case 'readiness-low': {
      if (v['band'] === 'reduce') {
        return {
          headline: `Readiness ${n('readiness')}: one fewer set on accessories`,
          detail: `Consider one fewer set on ${list(v['accessories'] as readonly string[])} today. Your main lifts stay as planned. Nothing changes unless you choose to.`,
        };
      }
      const low = n('lowDays');
      return {
        headline: `Readiness ${n('readiness')}: consider resting`,
        detail:
          (low >= 2 ? `Readiness has been under 35 for ${plural(low, 'day')} running. ` : 'Your check-in points to low recovery today. ') +
          'Resting is reasonable; the session stays planned if you feel ready. Nothing changes unless you choose to.',
      };
    }
    case 'protein-behind': {
      const target = n('proteinTarget');
      const leftLow = Math.max(0, r1(target - n('proteinHigh')));
      const leftHigh = Math.max(0, r1(target - n('proteinLow')));
      return {
        headline: `${range(leftLow, leftHigh)} g protein to go`,
        detail: `Protein logged today is under three quarters of your ${num(target)} g target. Make ${s('slot')} count — about ${range(n('kcalLeftLow'), n('kcalLeftHigh'))} kcal are left.`,
      };
    }
    case 'meal-remaining':
      return {
        headline: title(s('slot')),
        detail: `About ${range(n('kcalLeftLow'), n('kcalLeftHigh'))} kcal and ${range(n('proteinLeftLow'), n('proteinLeftHigh'))} g protein left today. Protein is on track.`,
      };
    case 'load-increase-due':
      return {
        headline: 'Load goes up today',
        detail:
          v['weightKg'] === null
            ? `${s('exerciseName')}: ${s('repTarget')}.`
            : `${s('exerciseName')}: ${num(n('weightKg'))} kg for ${s('repTarget')}.`,
      };
    case 'muscle-untrained':
      return {
        headline: `${title(label(s('muscle')))} is behind`,
        detail:
          v['daysSince'] === null
            ? `No working set for ${label(s('muscle'))} yet this block.`
            : `No working set for ${label(s('muscle'))} in ${plural(n('daysSince'), 'day')}.`,
      };
    case 'run-scheduled': {
      const what =
        v['distanceM'] !== null ? `${num(r1(n('distanceM') / 1000))} km` : v['seconds'] !== null ? `${Math.round(n('seconds') / 60)} minutes` : 'Your planned session';
      const pace = v['paceFast'] !== null && v['paceSlow'] !== null ? ` at ${mss(n('paceFast'))}–${mss(n('paceSlow'))} per km` : '';
      return { headline: s('title'), detail: `${what}${pace}. From your running plan.` };
    }
    case 'rest-day': {
      // §16.2: a rest day carries recovery status (Phase 13), with or without a programme.
      const readiness = v['readiness'] !== null && v['readiness'] !== undefined ? ` Readiness today: ${n('readiness')}.` : '';
      if (v['hasProgramme'] !== true) {
        return {
          headline: 'No session today',
          detail: `Set up a programme and FITOS will plan your sessions. A walk is a good start.${readiness}`,
        };
      }
      const parts: string[] = [];
      if (v['nextSessionName'] !== null) parts.push(`Next: ${s('nextSessionName')} on ${s('nextSessionDate')}.`);
      if (v['kcalTarget'] !== null && v['proteinTarget'] !== null) {
        parts.push(`Eat to about ${num(n('kcalTarget'))} kcal and ${num(n('proteinTarget'))} g protein.`);
      }
      parts.push('A walk helps recovery without adding fatigue.');
      return { headline: 'Recovery day', detail: parts.join(' ') + readiness };
    }
    case 'calorie-target-off-trend': {
      const delta = n('deltaKcal');
      const weekly = n('weeklyChangeKg');
      const moving = weekly === 0 ? 'holding steady' : `${weekly > 0 ? 'rising' : 'falling'} about ${Math.abs(weekly).toFixed(2)} kg a week`;
      return {
        headline: `Move your target to ${num(n('newKcal'))} kcal`,
        detail:
          `Your trend weight is ${moving}, off pace for your goal. ` +
          `Moving the target ${delta > 0 ? 'up' : 'down'} by ${num(Math.abs(delta))} kcal (from ${num(n('currentKcal'))}) keeps it on track. ` +
          'Nothing changes unless you accept.',
      };
    }
    case 'pr-today': {
      const more = n('count') - 1;
      return {
        headline: `New record on ${s('exerciseName')}`,
        detail:
          PR_WORDS[s('prType') as PrType](n('value'), n('previous')) +
          (more > 0 ? ` ${plural(more, 'more record')} today.` : ''),
      };
    }
    case 'weigh-in-due':
      return {
        headline: 'Log your weight',
        detail:
          v['daysSinceWeighIn'] === null
            ? 'No weight logged yet. The trend needs readings; single numbers do not matter.'
            : `Last reading ${plural(n('daysSinceWeighIn'), 'day')} ago. The trend needs regular readings; single numbers do not matter.`,
      };
  }
}

/* -------------------------------------------------------------- rules -- */

interface Candidate {
  readonly kind: ActionKind;
  readonly subjectKey: string;
  readonly priority: number;
  readonly basis: ActionBasis;
  readonly target: ActionTarget;
  readonly reason: ActionReason;
}

/** The meal still to come today (Phase 10's rule, 11/16/19), or null when none is. */
export function nextMealSlot(hourOfDay: number, loggedSlots: readonly MealSlot[]): MealSlot | null {
  const next = defaultRecommendationSlot(true, hourOfDay, loggedSlots);
  return next.alreadyLogged ? null : next.slot;
}

function candidates(m: UserModel): Candidate[] {
  const out: Candidate[] = [];
  const t = m.training;
  const trainingDay = t.sessionName !== null && !t.completedToday;

  // 95 — a deload the programme has offered (never buried under a meal tip).
  if (t.deload.state === 'offered') {
    out.push({
      kind: 'deload', subjectKey: '', priority: PRIORITIES.deload, basis: 'calculated', target: 'train',
      reason: { code: 'deload-offered', values: { trigger: t.deload.trigger } },
    });
  }

  // 91 — P1: a planned exercise ruled out by an active limitation AND a safer swap exists.
  const swaps = t.limitationSwaps.filter((x) => x.alternativeId !== null && x.alternativeName !== null);
  const swap = swaps[0];
  if (trainingDay && swap !== undefined) {
    out.push({
      kind: 'injured-limitation',
      subjectKey: `${swap.exerciseId}>${swap.alternativeId}`,
      priority: PRIORITIES['injured-limitation'],
      basis: 'logged',
      target: 'train',
      reason: {
        code: 'exercise-contraindicated',
        values: {
          exerciseId: swap.exerciseId,
          exerciseName: swap.exerciseName,
          bodyParts: [...swap.bodyParts].sort(),
          alternativeId: swap.alternativeId,
          alternativeName: swap.alternativeName,
          affectedCount: swaps.length,
        },
      },
    });
  }

  // 90 — today's session, not done, none open.
  if (trainingDay && !t.activeSessionOpen) {
    out.push({
      kind: 'start-workout', subjectKey: '', priority: PRIORITIES['start-workout'], basis: 'calculated', target: 'train',
      reason: {
        code: 'session-scheduled',
        values: { sessionName: t.sessionName, exerciseCount: t.exerciseCount, minutes: Math.round(t.plannedSetCount * MINUTES_PER_SET) },
      },
    });
  }

  // 87 — beta 4.1: today's run from the running plan, not done yet.
  const planned = m.running?.planned ?? null;
  if (planned !== null && m.running!.doneToday !== true) {
    out.push({
      kind: 'start-run',
      subjectKey: planned.plannedRunId,
      priority: PRIORITIES['start-run'],
      basis: 'calculated',
      target: 'train',
      reason: {
        code: 'run-scheduled',
        values: {
          title: planned.title,
          distanceM: planned.distanceM,
          seconds: planned.seconds,
          paceFast: planned.paceFast,
          paceSlow: planned.paceSlow,
        },
      },
    });
  }

  // 89 — §18: low readiness on a training day. Advisory: it names what to go
  // easier on; the plan is never changed (ADR-019 D9).
  const rec = m.recovery;
  if (trainingDay && rec.readiness !== null && (rec.band === 'rest' || (rec.band === 'reduce' && t.accessories.length > 0))) {
    out.push({
      kind: 'low-readiness',
      subjectKey: rec.band === 'rest' ? 'rest' : 'fewer-sets',
      priority: PRIORITIES['low-readiness'],
      basis: 'calculated',
      target: 'train',
      reason: {
        code: 'readiness-low',
        values: { readiness: rec.readiness, band: rec.band, accessories: rec.band === 'rest' ? [] : [...t.accessories], lowDays: rec.lowDays },
      },
    });
  }

  // 88/80 and 75 — food, on the Phase 8 ranges; eat-protein XOR eat-meal; nothing from 22:00 (P7).
  const targets = m.nutrition.targets;
  const slot = nextMealSlot(m.hourOfDay, m.nutrition.loggedSlots);
  if (targets !== null && slot !== null && m.hourOfDay < EAT_CUTOFF_HOUR) {
    const e = m.nutrition.eaten;
    const kcalLeftLow = Math.max(0, Math.round(targets.kcal - e.kcalHigh));
    const kcalLeftHigh = Math.max(0, Math.round(targets.kcal - e.kcalLow));
    if (e.proteinHigh < targets.proteinG * PROTEIN_SHORTFALL_THRESHOLD) {
      out.push({
        kind: 'eat-protein',
        subjectKey: slot,
        priority: slot === 'dinner' ? PRIORITIES['eat-protein'].dinner : PRIORITIES['eat-protein'].other,
        basis: 'calculated',
        target: 'eat',
        reason: {
          code: 'protein-behind',
          values: {
            slot, proteinTarget: r1(targets.proteinG), proteinLow: r1(e.proteinLow), proteinHigh: r1(e.proteinHigh), kcalLeftLow, kcalLeftHigh,
          },
        },
      });
    } else if (kcalLeftLow > MEAL_KCAL_LEFT_MIN) {
      out.push({
        kind: 'eat-meal', subjectKey: slot, priority: PRIORITIES['eat-meal'], basis: 'calculated', target: 'eat',
        reason: {
          code: 'meal-remaining',
          values: {
            slot, kcalLeftLow, kcalLeftHigh,
            proteinLeftLow: Math.max(0, r1(targets.proteinG - e.proteinHigh)),
            proteinLeftHigh: Math.max(0, r1(targets.proteinG - e.proteinLow)),
          },
        },
      });
    }
  }

  // 72 — a load increase due on today's session.
  const load = t.increaseLoad[0];
  if (trainingDay && load !== undefined) {
    out.push({
      kind: 'progress-load', subjectKey: load.exerciseId, priority: PRIORITIES['progress-load'], basis: 'calculated', target: 'train',
      reason: { code: 'load-increase-due', values: { exerciseId: load.exerciseId, exerciseName: load.exerciseName, weightKg: load.weightKg, repTarget: load.repTarget } },
    });
  }

  // 68 — the first neglected muscle.
  const neglected = t.neglected[0];
  if (neglected !== undefined) {
    out.push({
      kind: 'muscle-neglected', subjectKey: neglected.muscle, priority: PRIORITIES['muscle-neglected'], basis: 'logged', target: 'train',
      reason: { code: 'muscle-untrained', values: { muscle: neglected.muscle, daysSince: neglected.daysSince } },
    });
  }

  // 60 — a rest day is never a shrug (§16.2); a deload offer suppresses it (§16.1).
  // Beta 4.1: a day with a planned run is not a rest day.
  if (t.sessionName === null && !t.completedToday && t.deload.state !== 'offered' && planned === null) {
    out.push({
      kind: 'rest-day', subjectKey: '', priority: PRIORITIES['rest-day'], basis: 'calculated', target: 'today',
      reason: {
        code: 'rest-day',
        values: {
          hasProgramme: t.hasProgramme,
          nextSessionName: t.nextSession?.name ?? null,
          nextSessionDate: t.nextSession?.date ?? null,
          kcalTarget: targets === null ? null : Math.round(targets.kcal),
          proteinTarget: targets === null ? null : r1(targets.proteinG),
          readiness: m.recovery.readiness,
        },
      },
    });
  }

  // 55 — the §13.2 adjustment policy fired (Phase 12). Advisory: accepting it
  // creates a new target row; nothing changes otherwise.
  const adj = m.nutrition.adjustment;
  if (adj !== null) {
    out.push({
      kind: 'calorie-adjust', subjectKey: '', priority: PRIORITIES['calorie-adjust'], basis: 'calculated', target: 'eat',
      reason: {
        code: 'calorie-target-off-trend',
        values: { currentKcal: adj.currentKcal, newKcal: adj.newKcal, deltaKcal: adj.deltaKcal, weeklyChangeKg: adj.weeklyChangeKg },
      },
    });
  }

  // 50 — a record set today (the first; the count says how many).
  const pr = t.prsToday[0];
  if (pr !== undefined) {
    out.push({
      kind: 'celebrate-pr', subjectKey: pr.prId, priority: PRIORITIES['celebrate-pr'], basis: 'logged', target: 'progress',
      reason: { code: 'pr-today', values: { exerciseName: pr.exerciseName, prType: pr.prType, value: pr.value, previous: pr.previous, count: t.prsToday.length } },
    });
  }

  // 45 — no weigh-in for 2+ days (or none at all).
  const b = m.body;
  if (!b.weighedToday && (b.daysSinceWeighIn === null || b.daysSinceWeighIn >= WEIGH_IN_DUE_DAYS)) {
    out.push({
      kind: 'log-weight', subjectKey: '', priority: PRIORITIES['log-weight'], basis: 'calculated', target: 'progress',
      reason: { code: 'weigh-in-due', values: { daysSinceWeighIn: b.daysSinceWeighIn } },
    });
  }

  return out;
}

/** sha256 of an action's content — everything except its rank (P5). */
export function contentHashOf(a: Omit<Action, 'rank' | 'contentHash'>): string {
  return sha256Hex(
    canonicalJson({
      engineVersion: a.engineVersion, kind: a.kind, subjectKey: a.subjectKey, reason: a.reason,
      headline: a.headline, detail: a.detail, target: a.target, basis: a.basis, priority: a.priority,
    }),
  );
}

/** sha256 of the canonical `UserModel` (D16). */
export function inputDigestOf(model: UserModel): string {
  return sha256Hex(canonicalJson(model));
}

const KIND_ORDER = new Map<ActionKind, number>(ACTION_KINDS.map((k, i) => [k, i]));

/**
 * Every justified action, dismissed ones removed, ranked: priority first,
 * then the fixed kind order (so ties are deterministic). Not capped.
 */
export function buildActions(model: UserModel): Action[] {
  const dismissed = new Set(model.dismissedToday.map((d) => `${d.kind}\u0000${d.subjectKey}`));
  return candidates(model)
    .filter((c) => !dismissed.has(`${c.kind}\u0000${c.subjectKey}`))
    // No two candidates share a priority today; the kind order keeps it total if they ever do.
    /* v8 ignore next -- @preserve */
    .sort((a, b) => b.priority - a.priority || KIND_ORDER.get(a.kind)! - KIND_ORDER.get(b.kind)!)
    .map((c, i): Action => {
      const words = wordReason(c.reason);
      const content = { ...c, ...words, engineVersion: ENGINE_VERSION };
      return { ...content, rank: i + 1, contentHash: contentHashOf(content) };
    });
}

/** The surface: at most four, after suppression (§16.1). */
export function topActions(model: UserModel, limit = MAX_ACTIONS): Action[] {
  return buildActions(model).slice(0, limit);
}

/** What `GET /today` returns and persists. */
export function todayActions(model: UserModel): TodayResult {
  return { engineVersion: ENGINE_VERSION, localDate: model.localDate, inputDigest: inputDigestOf(model), actions: topActions(model) };
}
