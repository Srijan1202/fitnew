/**
 * Deload (§12.5; owner decisions 12.2–12.4). A deload week is OFFERED —
 * never applied on its own — when either:
 *
 *   fatigue  the §12.4 rule-2 deload recommendation has fired on at least
 *            two lead (compound) lifts within the last seven days, or
 *   mrv      the programme is in mesocycle week ≥ 6 and any muscle is at or
 *            above its MRV this week.
 *
 * Accepted, the next seven days' sessions seed with sets × 0.6 (minimum 1),
 * load × 0.9 rounded to 0.5 kg, RIR + 2 capped at 5; afterwards the
 * mesocycle week resets to 1. Declined, it is not offered again for seven
 * days. Deterministic; every offer carries its reason.
 */
import { MUSCLE_GROUPS, VOLUME_LANDMARKS, type MuscleGroup } from './generator.js';
import type { PlannedSetTarget } from './prefill.js';
import type { MuscleVolume } from './volume.js';

export const DELOAD_DAYS = 7;
export const DELOAD_SNOOZE_DAYS = 7;
export const DELOAD_MESOCYCLE_WEEK = 6;
export const DELOAD_LEAD_LIFTS = 2;
export const DELOAD_SET_FACTOR = 0.6;
export const DELOAD_LOAD_FACTOR = 0.9;
export const DELOAD_RIR_BONUS = 2;

export type DeloadTrigger = 'fatigue' | 'mrv';

export interface DeloadOffer {
  readonly offer: boolean;
  readonly trigger: DeloadTrigger | null;
  readonly reason: string;
}

export interface DeloadInput {
  readonly mesocycleWeek: number;
  /** This ISO week's volume per muscle. */
  readonly thisWeek: Readonly<Record<MuscleGroup, MuscleVolume>>;
  /** Lead lifts whose progression came back `deload` in the last seven days, with names for the reason. */
  readonly fatiguedLeadLifts: readonly { exerciseId: string; name: string }[];
  /** Not offered again before this local date (a declined offer). */
  readonly snoozedUntil: string | null;
  /** A deload week already running. */
  readonly active: boolean;
  readonly today: string;
}

export function shouldOfferDeload(input: DeloadInput): DeloadOffer {
  if (input.active) return { offer: false, trigger: null, reason: 'A deload week is already running.' };
  if (input.snoozedUntil !== null && input.today < input.snoozedUntil) {
    return { offer: false, trigger: null, reason: `Declined; not offered again before ${input.snoozedUntil}.` };
  }
  const fatigued = [...new Map(input.fatiguedLeadLifts.map((l) => [l.exerciseId, l])).values()];
  if (fatigued.length >= DELOAD_LEAD_LIFTS) {
    const names = fatigued.map((l) => l.name).join(' and ');
    return {
      offer: true,
      trigger: 'fatigue',
      reason: `Reps have dropped across three sessions at the same load on ${names} while the sets felt harder. That is accumulated fatigue on your main lifts, not lost strength. Take one lighter week and the reps come back.`,
    };
  }
  if (input.mesocycleWeek >= DELOAD_MESOCYCLE_WEEK) {
    const atMrv = MUSCLE_GROUPS.filter((m) => input.thisWeek[m].hardSets >= VOLUME_LANDMARKS[m].mrv);
    if (atMrv.length > 0) {
      return {
        offer: true,
        trigger: 'mrv',
        reason: `Week ${input.mesocycleWeek} of this block and ${atMrv.join(', ')} ${atMrv.length === 1 ? 'is' : 'are'} at the most volume you can recover from (MRV). A lighter week now lets the next block start fresh.`,
      };
    }
  }
  return { offer: false, trigger: null, reason: 'No fatigue signal on your lead lifts and no muscle at MRV.' };
}

/** Round to the nearest 0.5 kg. */
export function roundToHalf(kg: number): number {
  return Math.round(kg * 2) / 2;
}

/** The deload week's targets for one exercise, from its planned sets and last working load. */
export function deloadTargets(planned: readonly PlannedSetTarget[], lastLoadKg: number | null): PlannedSetTarget[] {
  const count = Math.max(1, Math.round(planned.length * DELOAD_SET_FACTOR));
  return planned.slice(0, count).map((s, i) => ({
    ...s,
    setIndex: i + 1,
    weightKg: lastLoadKg !== null && lastLoadKg > 0 ? roundToHalf(lastLoadKg * DELOAD_LOAD_FACTOR) : s.weightKg === null ? null : roundToHalf(s.weightKg * DELOAD_LOAD_FACTOR),
    rir: Math.min(5, s.rir + DELOAD_RIR_BONUS),
  }));
}

/** The local date a deload week accepted on `startedOn` ends (exclusive). */
export function deloadEndsOn(startedOn: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(startedOn);
  if (m === null) throw new RangeError(`expected yyyy-mm-dd, got "${startedOn}"`);
  return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]) + DELOAD_DAYS)).toISOString().slice(0, 10);
}

/** After a deload week the block starts again (§12.5). */
export function mesocycleAfterDeload(): number {
  return 1;
}
