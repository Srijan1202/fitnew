/**
 * Phase 6 assembly: the ONLY caller of packages/core's progression,
 * volume, deload and substitution engines (§7.3, §30). Rows → engine
 * inputs → contract shapes. No rules live here; every number the client
 * sees is the engine's, with the engine's reason.
 */
import { DELOAD_DAYS, deloadEndsOn, deloadTargets, mesocycleAfterDeload, shouldOfferDeload } from '@fitos/core/training/deload';
import { COMPOUND, type CatalogueExercise, type MuscleGroup } from '@fitos/core/training/generator';
import { mesocycleWeekFrom } from '@fitos/core/training/mesocycle';
import { recommendProgression, estimate1RM, type SessionLog } from '@fitos/core/training/progression';
import { substitute } from '@fitos/core/training/substitution';
import { daysSinceTrained, neglectedMuscles, recentWeeks, volumeReport, weeklyVolume, type VolumeSet } from '@fitos/core/training/volume';
import { isoWeekKey } from '@fitos/core/training/mesocycle';
import type {
  DeloadState,
  PlannedSet,
  PriorBest,
  ProgressionRecommendation,
  Substitution,
  VolumeResponse,
} from '@fitos/contracts';

import type { PlannedExerciseJoined, ProgramBundle, TrainingRepository } from '../training/repository.js';
import { toCatalogueExercise } from '../training/service.js';
import type { PriorWork, WorkoutRepository } from './repository.js';

const num = (s: string | null): number | null => (s === null ? null : Number(s));

/** "yyyy-mm-dd" of an instant in an IANA zone (same rule as service.ts). */
export function localDate(at: Date, timeZone: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(at);
}

export const VOLUME_WEEKS = 4;

export interface DeloadWindow {
  readonly startedAt: Date;
  readonly endsAt: Date;
}

export class ProgressionAssembler {
  constructor(
    private readonly repo: WorkoutRepository,
    private readonly training: TrainingRepository,
  ) {}

  /* -------------------------------------------------------- history -- */

  /**
   * A lift's history as the engine reads it: completed sessions only, most
   * recent LAST, at most three, minus any session completed inside a deload
   * week (owner 12.4: deload sessions never read as a decline).
   */
  static toSessionLogs(prior: readonly PriorWork[], exerciseId: string, tz: string, deload: DeloadWindow | null): SessionLog[] {
    return prior
      .filter((p) => p.exerciseId === exerciseId)
      .filter((p) => deload === null || p.completedAt < deload.startedAt || p.completedAt >= deload.endsAt)
      .slice(0, 3)
      .reverse()
      .map((p) => ({
        date: localDate(p.completedAt, tz),
        sets: p.sets.map((s) => ({ weightKg: num(s.weightKg) ?? 0, reps: s.reps, rir: s.rir })),
      }));
  }

  static recommendation(history: SessionLog[], x: PlannedExerciseJoined): ProgressionRecommendation {
    const rec = recommendProgression({
      history,
      target: { repMin: x.repMin, repMax: x.repMax, targetRir: x.targetRir, sets: x.setCount, incrementKg: Number(x.incrementKg) },
    });
    return { ...rec, basis: history.length > 0 ? 'calculated' : 'logged', sessionsConsidered: history.length };
  }

  static priorBest(prior: readonly PriorWork[], exerciseId: string): PriorBest {
    const sets = prior.filter((p) => p.exerciseId === exerciseId).flatMap((p) => p.sets).filter((s) => s.weightKg !== null && Number(s.weightKg) > 0 && s.reps >= 1);
    if (sets.length === 0) return { weightKg: null, repsAtBestWeight: null, estimated1rm: null };
    const best = Math.max(...sets.map((s) => Number(s.weightKg)));
    const repsAtBest = Math.max(...sets.filter((s) => Number(s.weightKg) === best).map((s) => s.reps));
    const est = Math.max(...sets.map((s) => estimate1RM(Number(s.weightKg), s.reps)));
    return { weightKg: best, repsAtBestWeight: repsAtBest, estimated1rm: est };
  }

  /* --------------------------------------------------------- deload -- */

  static deloadWindow(program: ProgramBundle | null): DeloadWindow | null {
    const started = program?.program.deloadStartedAt ?? null;
    if (started === null) return null;
    return { startedAt: started, endsAt: new Date(started.getTime() + DELOAD_DAYS * 86_400_000) };
  }

  /** Lighter targets for the week (owner 12.4), keeping the plan's originals beside them. */
  static deloaded(targets: PlannedSet[], lastLoad: number | null): PlannedSet[] {
    return deloadTargets(targets, lastLoad).map((t, i) => ({ ...targets[i]!, ...t }));
  }

  /**
   * The deload offer / active state for the programme today. Fatigue is
   * counted on lead (compound) lifts whose recommendation is `deload`.
   */
  async deloadState(
    program: ProgramBundle | null,
    prior: readonly PriorWork[],
    volumeSets: readonly VolumeSet[],
    today: string,
    tz: string,
  ): Promise<DeloadState> {
    if (program === null) return { state: 'none', trigger: null, reason: 'No programme, so no block to deload from.', endsOn: null };
    const window = ProgressionAssembler.deloadWindow(program);
    const active = window !== null && today < localDate(window.endsAt, tz);
    if (active) {
      return { state: 'active', trigger: null, reason: 'A lighter week is running: sets × 0.6, load × 0.9, two more reps in reserve.', endsOn: localDate(window.endsAt, tz) };
    }
    const seen = new Set<string>();
    const leadLifts = program.exercises.filter((x) => COMPOUND.has(x.movementPattern as CatalogueExercise['movementPattern']) && !seen.has(x.exerciseId) && seen.add(x.exerciseId));
    const weekAgo = new Date(Date.now() - 7 * 86_400_000);
    const fatigued: { exerciseId: string; name: string }[] = [];
    for (const x of leadLifts) {
      const recent = prior.filter((p) => p.exerciseId === x.exerciseId && p.completedAt >= weekAgo);
      if (recent.length === 0) continue;
      const rec = ProgressionAssembler.recommendation(ProgressionAssembler.toSessionLogs(prior, x.exerciseId, tz, window), x);
      if (rec.action === 'deload') fatigued.push({ exerciseId: x.exerciseId, name: x.name });
    }
    const offer = shouldOfferDeload({
      mesocycleWeek: program.program.mesocycleWeek,
      thisWeek: weeklyVolume(volumeSets, isoWeekKey(today)),
      fatiguedLeadLifts: fatigued,
      snoozedUntil: program.program.deloadSnoozedUntil,
      active: false,
      today,
    });
    return { state: offer.offer ? 'offered' : 'none', trigger: offer.trigger, reason: offer.reason, endsOn: null };
  }

  async acceptDeload(program: ProgramBundle, now: Date): Promise<void> {
    await this.repo.setDeload(program.program.id, { deloadStartedAt: now, deloadSnoozedUntil: null });
  }

  /** Not offered again for DELOAD_SNOOZE_DAYS (the same seven as the week itself). */
  async declineDeload(program: ProgramBundle, today: string): Promise<void> {
    await this.repo.setDeload(program.program.id, { deloadSnoozedUntil: deloadEndsOn(today) });
  }

  /** Called on completion: a deload week that has run its course closes and the block restarts at week 1. */
  async closeElapsedDeload(program: ProgramBundle, completedAt: Date): Promise<boolean> {
    const window = ProgressionAssembler.deloadWindow(program);
    if (window === null || completedAt < window.endsAt) return false;
    await this.repo.setDeload(program.program.id, { deloadStartedAt: null, mesocycleResetAt: completedAt, mesocycleWeek: mesocycleAfterDeload() });
    return true;
  }

  /** The mesocycle week from completions since the last reset (owner 8.2 + 12.4). */
  async mesocycleWeek(program: ProgramBundle, tz: string): Promise<number> {
    const reset = program.program.mesocycleResetAt;
    const dates = (await this.repo.completedAtOfProgram(program.program.id))
      .filter((d) => reset === null || d >= reset)
      .map((d) => localDate(d, tz));
    return mesocycleWeekFrom(dates);
  }

  /* --------------------------------------------------------- volume -- */

  static owned(program: ProgramBundle | null): MuscleGroup[] {
    if (program === null) return [];
    const out = new Set<MuscleGroup>();
    for (const x of program.exercises) for (const m of x.primaryMuscles) out.add(m);
    return [...out];
  }

  async volumeSets(userId: string, today: string, tz: string): Promise<VolumeSet[]> {
    // Four ISO weeks back from today, plus a day of slack for time zones.
    const [first] = recentWeeks(today, VOLUME_WEEKS);
    const monday = ProgressionAssembler.mondayOf(first!);
    const rows = await this.repo.volumeSets(userId, new Date(Date.parse(`${monday}T00:00:00Z`) - 86_400_000));
    return rows.map((r) => ({
      localDate: localDate(r.completedAt, tz),
      exerciseId: r.exerciseId,
      primaryMuscles: r.primaryMuscles,
      secondaryMuscles: r.secondaryMuscles,
      setType: r.setType,
      weightKg: num(r.weightKg),
      reps: r.reps,
    }));
  }

  /** The Monday (yyyy-mm-dd) of an ISO week key. */
  static mondayOf(isoWeek: string): string {
    const m = /^(\d{4})-W(\d{2})$/.exec(isoWeek);
    if (m === null) throw new RangeError(`bad iso week ${isoWeek}`);
    const year = Number(m[1]);
    const week = Number(m[2]);
    // ISO week 1 contains 4 January.
    const jan4 = new Date(Date.UTC(year, 0, 4));
    const jan4Dow = jan4.getUTCDay() === 0 ? 7 : jan4.getUTCDay();
    const week1Monday = new Date(jan4.getTime() - (jan4Dow - 1) * 86_400_000);
    return new Date(week1Monday.getTime() + (week - 1) * 7 * 86_400_000).toISOString().slice(0, 10);
  }

  neglected(sets: readonly VolumeSet[], owned: readonly MuscleGroup[], today: string): { muscle: MuscleGroup; daysSince: number | null }[] {
    return neglectedMuscles(sets, owned, today).map((muscle) => ({ muscle, daysSince: daysSinceTrained(sets, muscle, today) }));
  }

  async volume(userId: string, program: ProgramBundle | null, prior: readonly PriorWork[], today: string, tz: string): Promise<VolumeResponse> {
    const sets = await this.volumeSets(userId, today, tz);
    const owned = ProgressionAssembler.owned(program);
    const weeks = recentWeeks(today, VOLUME_WEEKS);
    return {
      weeks: volumeReport(sets, weeks, owned).map((w) => ({ isoWeek: w.isoWeek, muscles: w.muscles.map((m) => ({ ...m })) })),
      owned,
      neglected: this.neglected(sets, owned, today),
      mesocycleWeek: program?.program.mesocycleWeek ?? null,
      deload: await this.deloadState(program, prior, sets, today, tz),
    };
  }

  /** Recompute and cache one ISO week (called on completion; the rebuild script calls it for every week). */
  async cacheWeek(userId: string, isoWeek: string, sets: readonly VolumeSet[]): Promise<void> {
    const v = weeklyVolume(sets, isoWeek);
    await this.repo.upsertWeeklyVolume(
      userId,
      isoWeek,
      (Object.keys(v) as MuscleGroup[]).filter((m) => v[m].hardSets > 0).map((m) => ({ muscleGroup: m, hardSets: v[m].hardSets, tonnageKg: v[m].tonnageKg })),
    );
  }

  /* --------------------------------------------------- substitution -- */

  async substitutions(
    userId: string,
    planned: readonly PlannedExerciseJoined[],
    kit: readonly CatalogueExercise['equipment'][number][],
    limitations: readonly CatalogueExercise['contraindications'][number][],
  ): Promise<Map<string, Substitution | null>> {
    const ids = [...new Set(planned.map((x) => x.exerciseId))];
    const [rejections, alternatives] = await Promise.all([this.repo.rejectionCounts(userId, ids), this.repo.alternativesFor(ids)]);
    const needed = new Set<string>([...ids, ...[...alternatives.values()].flat()]);
    const catalogue = new Map((await this.training.catalogue()).filter((c) => needed.has(c.id)).map((c) => [c.id, toCatalogueExercise(c)]));
    const out = new Map<string, Substitution | null>();
    for (const x of planned) {
      const ex = catalogue.get(x.exerciseId);
      if (ex === undefined) {
        out.set(x.id, null);
        continue;
      }
      const alts = (alternatives.get(x.exerciseId) ?? []).map((id) => catalogue.get(id)).filter((a): a is CatalogueExercise => a !== undefined);
      const s = substitute(ex, alts, kit, limitations, rejections.get(x.exerciseId) ?? 0);
      out.set(
        x.id,
        s === null
          ? null
          : {
              trigger: s.trigger,
              alternative: s.alternative === null ? null : { exerciseId: s.alternative.id, slug: s.alternative.slug, name: s.alternative.name, equipment: [...s.alternative.equipment] },
              reason: s.reason,
            },
      );
    }
    return out;
  }
}
