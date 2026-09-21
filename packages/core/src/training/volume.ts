/**
 * The volume engine (§12.3, §31 Phase 6). Weekly hard sets per muscle from
 * what was actually logged, compared to the landmarks the generator plans
 * with, and the muscles a programme owns but has not trained lately.
 *
 * Counting rules, identical to the generator's accounting: only `working`
 * sets count; a set counts 1 for each primary muscle and 0.5 for each
 * secondary; tonnage sums weight × reps over loaded working sets. Weeks are
 * ISO weeks in the user's calendar — callers pass LOCAL dates, as
 * `mesocycle.ts` already requires. Deterministic, no clock.
 */
import { MUSCLE_GROUPS, SECONDARY_CONTRIBUTION, VOLUME_LANDMARKS, type MuscleGroup, type VolumeLandmark } from './generator.js';
import { isoWeekKey } from './mesocycle.js';
import type { SetType } from './records.js';

export interface VolumeSet {
  /** yyyy-mm-dd in the user's calendar (the session's completion date). */
  readonly localDate: string;
  readonly exerciseId: string;
  readonly primaryMuscles: readonly MuscleGroup[];
  readonly secondaryMuscles: readonly MuscleGroup[];
  readonly setType: SetType;
  readonly weightKg: number | null;
  readonly reps: number;
}

export interface MuscleVolume {
  readonly hardSets: number;
  readonly tonnageKg: number;
}

/** Where a week's hard sets sit against §12.3, lowest first. */
export type LandmarkStatus = 'none' | 'below-mv' | 'below-mev' | 'mev-to-mav' | 'above-mav' | 'at-mrv';

export interface MuscleWeek extends MuscleVolume {
  readonly muscle: MuscleGroup;
  readonly status: LandmarkStatus;
  readonly landmarks: VolumeLandmark;
  /** The programme trains this muscle; others are shown but never "behind". */
  readonly owned: boolean;
}

export interface WeekReport {
  readonly isoWeek: string;
  readonly muscles: readonly MuscleWeek[];
}

const round1 = (n: number): number => Math.round(n * 10) / 10;

function emptyWeek(): Record<MuscleGroup, { hardSets: number; tonnageKg: number }> {
  const out = {} as Record<MuscleGroup, { hardSets: number; tonnageKg: number }>;
  for (const m of MUSCLE_GROUPS) out[m] = { hardSets: 0, tonnageKg: 0 };
  return out;
}

/** Hard sets and tonnage per muscle for the sets that fall in `isoWeek`. */
export function weeklyVolume(sets: readonly VolumeSet[], isoWeek: string): Record<MuscleGroup, MuscleVolume> {
  const week = emptyWeek();
  for (const s of sets) {
    if (s.setType !== 'working' || isoWeekKey(s.localDate) !== isoWeek) continue;
    const tonnage = s.weightKg !== null && s.weightKg > 0 ? s.weightKg * s.reps : 0;
    for (const m of s.primaryMuscles) {
      week[m].hardSets += 1;
      week[m].tonnageKg += tonnage;
    }
    for (const m of s.secondaryMuscles) {
      if (s.primaryMuscles.includes(m)) continue;
      week[m].hardSets += SECONDARY_CONTRIBUTION;
      week[m].tonnageKg += tonnage * SECONDARY_CONTRIBUTION;
    }
  }
  for (const m of MUSCLE_GROUPS) {
    week[m] = { hardSets: round1(week[m].hardSets), tonnageKg: round1(week[m].tonnageKg) };
  }
  return week;
}

/** §12.3 boundaries, inclusive at the top of each band. */
export function landmarkStatus(muscle: MuscleGroup, hardSets: number): LandmarkStatus {
  const lm = VOLUME_LANDMARKS[muscle];
  if (hardSets <= 0) return 'none';
  if (hardSets < lm.mv) return 'below-mv';
  if (hardSets < lm.mev) return 'below-mev';
  if (hardSets <= lm.mavHigh) return 'mev-to-mav';
  if (hardSets < lm.mrv) return 'above-mav';
  return 'at-mrv';
}

/** The ISO week keys for `count` weeks ending at the week of `localDate`, oldest first. */
export function recentWeeks(localDate: string, count: number): string[] {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(localDate);
  if (m === null) throw new RangeError(`expected yyyy-mm-dd, got "${localDate}"`);
  const keys: string[] = [];
  for (let i = count - 1; i >= 0; i--) {
    const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]) - 7 * i));
    keys.push(isoWeekKey(d.toISOString().slice(0, 10)));
  }
  return keys;
}

export function volumeReport(sets: readonly VolumeSet[], weeks: readonly string[], owned: readonly MuscleGroup[]): WeekReport[] {
  return weeks.map((isoWeek) => {
    const v = weeklyVolume(sets, isoWeek);
    return {
      isoWeek,
      muscles: MUSCLE_GROUPS.map((muscle) => ({
        muscle,
        hardSets: v[muscle].hardSets,
        tonnageKg: v[muscle].tonnageKg,
        status: landmarkStatus(muscle, v[muscle].hardSets),
        landmarks: VOLUME_LANDMARKS[muscle],
        owned: owned.includes(muscle),
      })),
    };
  });
}

export const NEGLECT_DAYS = 6;

/** Days between two local dates (b − a). */
function daysBetween(a: string, b: string): number {
  const p = (s: string): number => {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
    if (m === null) throw new RangeError(`expected yyyy-mm-dd, got "${s}"`);
    return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  };
  return Math.round((p(b) - p(a)) / 86_400_000);
}

/**
 * Muscles the programme owns (owner decision 12.7) with no working set —
 * primary or secondary — in the last `days` days up to and including
 * `today`. A muscle never trained at all counts as neglected only once
 * there is at least one completed session to compare against.
 */
export function neglectedMuscles(
  sets: readonly VolumeSet[],
  owned: readonly MuscleGroup[],
  today: string,
  days: number = NEGLECT_DAYS,
): MuscleGroup[] {
  const working = sets.filter((s) => s.setType === 'working');
  if (working.length === 0) return [];
  const recent = new Set<MuscleGroup>();
  for (const s of working) {
    const age = daysBetween(s.localDate, today);
    if (age < 0 || age > days) continue;
    for (const m of s.primaryMuscles) recent.add(m);
    for (const m of s.secondaryMuscles) recent.add(m);
  }
  return MUSCLE_GROUPS.filter((m) => owned.includes(m) && !recent.has(m));
}

/** Days since the last working set for a muscle, or null when none. */
export function daysSinceTrained(sets: readonly VolumeSet[], muscle: MuscleGroup, today: string): number | null {
  let best: number | null = null;
  for (const s of sets) {
    if (s.setType !== 'working') continue;
    if (!s.primaryMuscles.includes(muscle) && !s.secondaryMuscles.includes(muscle)) continue;
    const age = daysBetween(s.localDate, today);
    if (age < 0) continue;
    if (best === null || age < best) best = age;
  }
  return best;
}
