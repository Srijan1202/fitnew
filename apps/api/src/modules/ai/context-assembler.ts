/**
 * Phase 6.6 — UserContextAssembler → FitosAiContext (ADR-010).
 *
 * What the assistant knows about the user, gathered from the existing
 * services (never the repositories, never SQL), bounded so a request stays
 * small: today's session, the programme's shape, the last three completed
 * sessions summarised, the current week's volume, targets. Every part is
 * optional and says so when absent. Health Connect data is not here and
 * cannot be: it never reaches the server (owner B4). Food intake is not
 * here because Phase 8 has not been built; the context says that too, so
 * the model never invents either.
 */
import type {
  Program,
  ProgressionRecommendation,
  SessionListItem,
  TodayResponse,
  UserProfileDetail,
  VolumeResponse,
  WorkoutSession,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { TrainingService } from '../training/service.js';
import type { UserService } from '../user/service.js';
import type { WorkoutService } from '../workout/service.js';

/** Bounds: what keeps a request small and the answer specific. */
export const CONTEXT_RECENT_SESSIONS = 3;
export const CONTEXT_SETS_PER_EXERCISE = 6;

export interface NutritionTargetsSummary {
  readonly kcal: number;
  readonly proteinG: number;
  readonly carbG: number;
  readonly fatG: number;
  readonly fiberG: number;
  readonly reason: string;
}

export interface FitosAiContext {
  readonly generatedAt: string;
  readonly profile: {
    readonly displayName: string | null;
    readonly sex: string | null;
    readonly ageYears: number | null;
    readonly heightCm: number | null;
    readonly latestWeightKg: number | null;
    readonly experienceLevel: string | null;
    readonly activityLevel: string | null;
    readonly trainingDaysPerWeek: number | null;
    readonly preferredSessionMinutes: number | null;
    readonly trainingLocation: string | null;
    readonly equipment: readonly string[];
    readonly timezone: string;
  };
  readonly goal: {
    readonly type: string;
    readonly targetWeightKg: number | null;
    readonly targets: NutritionTargetsSummary | null;
  } | null;
  readonly programme: {
    readonly name: string;
    readonly splitType: string;
    readonly daysPerWeek: number;
    readonly mesocycleWeek: number;
    readonly days: readonly { readonly dayOfWeek: number; readonly sessionName: string; readonly isRest: boolean; readonly exercises: readonly string[] }[];
  } | null;
  readonly today: {
    readonly date: string;
    readonly dayOfWeek: number;
    readonly isRest: boolean;
    readonly sessionName: string | null;
    readonly status: 'rest' | 'ready' | 'in-progress' | 'completed' | 'no-programme';
    readonly mesocycleWeek: number | null;
    readonly deload: TodayResponse['deload'];
    readonly neglected: readonly { readonly muscle: string; readonly daysSince: number | null }[];
    readonly exercises: readonly {
      readonly exerciseId: string;
      readonly name: string;
      readonly sets: number;
      readonly reps: string;
      readonly rir: number;
      readonly targetWeightKg: number | null;
      readonly recommendation: ProgressionRecommendation | null;
      readonly lastTime: string | null;
      readonly substitution: string | null;
    }[];
  } | null;
  readonly recentSessions: readonly {
    readonly sessionId: string;
    readonly name: string;
    readonly date: string;
    readonly workingSets: number;
    readonly tonnageKg: number | null;
    readonly records: readonly string[];
    readonly exercises: readonly { readonly name: string; readonly sets: readonly string[] }[];
  }[];
  readonly volume: {
    readonly isoWeek: string;
    readonly muscles: readonly { readonly muscle: string; readonly hardSets: number; readonly status: string; readonly mev: number; readonly mav: string; readonly mrv: number }[];
  } | null;
  readonly nutrition: {
    readonly targets: NutritionTargetsSummary | null;
    readonly loggingAvailable: false;
    readonly note: string;
  };
  readonly health: {
    readonly availableToServer: false;
    readonly note: string;
  };
}

export interface ContextServices {
  readonly user: UserService;
  readonly training: TrainingService;
  readonly workout: WorkoutService;
}

const fmtSet = (s: { weightKg: number | null; reps: number; rir: number | null }): string =>
  `${s.weightKg === null ? 'bw' : `${s.weightKg}kg`}×${s.reps}${s.rir === null ? '' : `@${s.rir}`}`;

export class UserContextAssembler {
  constructor(private readonly services: ContextServices, private readonly now: () => Date = () => new Date()) {}

  async assemble(userId: string): Promise<FitosAiContext> {
    const [profile, goal, today, programme, volume, history] = await Promise.all([
      this.services.user.getProfile(userId),
      this.services.user.getGoal(userId),
      this.services.workout.today(userId).catch(() => null),
      this.services.training.getProgram(userId).catch(swallowNotFound),
      this.services.workout.volume(userId).catch(() => null),
      this.services.workout.list(userId, { limit: 10, status: 'completed' }).catch(() => null),
    ]);
    const recent = history === null ? [] : await this.recentSessions(userId, history.items);
    const targets =
      goal.targets === null
        ? null
        : { kcal: goal.targets.kcal, proteinG: goal.targets.proteinG, carbG: goal.targets.carbG, fatG: goal.targets.fatG, fiberG: goal.targets.fiberG, reason: goal.targets.reason };

    return {
      generatedAt: this.now().toISOString(),
      profile: UserContextAssembler.profileOf(profile, this.now()),
      goal: goal.goal === null ? null : { type: goal.goal.goalType, targetWeightKg: goal.goal.targetWeightKg, targets },
      programme: programme === null ? null : UserContextAssembler.programmeOf(programme),
      today: today === null ? null : UserContextAssembler.todayOf(today),
      recentSessions: recent,
      volume: volume === null ? null : UserContextAssembler.volumeOf(volume),
      nutrition: {
        targets,
        loggingAvailable: false,
        note: 'Food logging is not available in this version; the user\'s intake today is unknown. Only the targets are known.',
      },
      health: {
        availableToServer: false,
        note: 'Health Connect data (steps, sleep, resting heart rate, calories, body measurements from the phone) stays on the phone and is not sent to this server or to the assistant. The Home screen shows it.',
      },
    };
  }

  /* --------------------------------------------------------- projections -- */

  static profileOf(p: UserProfileDetail, now: Date): FitosAiContext['profile'] {
    let age: number | null = null;
    if (p.birthDate !== null) {
      const b = new Date(`${p.birthDate}T00:00:00Z`);
      age = now.getUTCFullYear() - b.getUTCFullYear() - (now.getUTCMonth() < b.getUTCMonth() || (now.getUTCMonth() === b.getUTCMonth() && now.getUTCDate() < b.getUTCDate()) ? 1 : 0);
    }
    return {
      displayName: p.displayName,
      sex: p.sex,
      ageYears: age,
      heightCm: p.heightCm,
      latestWeightKg: p.latestWeightKg,
      experienceLevel: p.experienceLevel,
      activityLevel: p.activityLevel,
      trainingDaysPerWeek: p.trainingDaysPerWeek,
      preferredSessionMinutes: p.preferredSessionMinutes,
      trainingLocation: p.trainingLocation,
      equipment: p.equipment,
      timezone: p.timezone,
    };
  }

  static programmeOf(p: Program): NonNullable<FitosAiContext['programme']> {
    return {
      name: p.name,
      splitType: p.splitType,
      daysPerWeek: p.daysPerWeek,
      mesocycleWeek: p.mesocycleWeek,
      days: p.days.map((d) => ({ dayOfWeek: d.dayOfWeek, sessionName: d.sessionName, isRest: d.isRest, exercises: d.exercises.map((x) => x.name) })),
    };
  }

  static todayOf(t: TodayResponse): NonNullable<FitosAiContext['today']> {
    const status: NonNullable<FitosAiContext['today']>['status'] =
      t.programId === null ? 'no-programme' : t.activeSession !== null ? 'in-progress' : t.completedSessionId !== null ? 'completed' : t.isRest ? 'rest' : 'ready';
    return {
      date: t.date,
      dayOfWeek: t.dayOfWeek,
      isRest: t.isRest,
      sessionName: t.sessionName,
      status,
      mesocycleWeek: t.mesocycleWeek,
      deload: t.deload,
      neglected: t.neglected,
      exercises: t.exercises.map((x) => {
        const first = x.targets[0];
        return {
          exerciseId: x.exerciseId,
          name: x.name,
          sets: x.targets.length,
          reps: first === undefined ? '' : first.repsMin === first.repsMax ? `${first.repsMax}` : `${first.repsMin}–${first.repsMax}`,
          rir: first?.rir ?? 0,
          targetWeightKg: first?.weightKg ?? null,
          recommendation: x.recommendation,
          lastTime: x.lastPerformance === null ? null : x.lastPerformance.sets.map(fmtSet).join(' '),
          substitution: x.substitution === null ? null : `${x.substitution.alternative?.name ?? 'no alternative'}: ${x.substitution.reason}`,
        };
      }),
    };
  }

  static volumeOf(v: VolumeResponse): NonNullable<FitosAiContext['volume']> {
    const week = v.weeks[v.weeks.length - 1];
    if (week === undefined) return { isoWeek: '', muscles: [] };
    return {
      isoWeek: week.isoWeek,
      muscles: week.muscles
        .filter((m) => m.owned || m.hardSets > 0)
        .map((m) => ({ muscle: m.muscle, hardSets: m.hardSets, status: m.status, mev: m.landmarks.mev, mav: `${m.landmarks.mavLow}–${m.landmarks.mavHigh}`, mrv: m.landmarks.mrv })),
    };
  }

  static sessionOf(s: WorkoutSession): FitosAiContext['recentSessions'][number] {
    return {
      sessionId: s.id,
      name: s.name,
      date: (s.completedAt ?? s.startedAt).slice(0, 10),
      workingSets: s.summary?.workingSets ?? s.exercises.reduce((n, x) => n + x.sets.filter((z) => z.setType === 'working').length, 0),
      tonnageKg: s.summary?.tonnageKg ?? null,
      records: (s.summary?.prs ?? []).map((p) => `${p.exerciseName}: ${p.reason}`),
      exercises: s.exercises
        .filter((x) => x.sets.length > 0)
        .map((x) => ({
          name: x.name,
          sets: x.sets
            .filter((z) => z.setType === 'working')
            .slice(0, CONTEXT_SETS_PER_EXERCISE)
            .map(fmtSet),
        })),
    };
  }

  private async recentSessions(userId: string, items: readonly SessionListItem[]): Promise<FitosAiContext['recentSessions']> {
    const picked = items.filter((i) => i.status === 'completed').slice(0, CONTEXT_RECENT_SESSIONS);
    const out: FitosAiContext['recentSessions'][number][] = [];
    for (const item of picked) {
      const s = await this.services.workout.get(userId, item.id).catch(() => null);
      if (s !== null) out.push(UserContextAssembler.sessionOf(s));
    }
    return out;
  }
}

function swallowNotFound(e: unknown): null {
  if (e instanceof AppError && e.code === 'NOT_FOUND') return null;
  throw e;
}
