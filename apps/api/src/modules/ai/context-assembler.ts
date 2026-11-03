/**
 * Phase 6.6 — UserContextAssembler → FitosAiContext (ADR-010).
 *
 * What the assistant knows about the user, gathered from the existing
 * services (never the repositories, never SQL), bounded so a request stays
 * small: today's session, the programme's shape, the last three completed
 * sessions summarised, the current week's volume, targets. Every part is
 * optional and says so when absent. Health Connect data is not here and
 * cannot be: it never reaches the server (owner B4).
 *
 * Beta 5.4 (owner, reversing J17 for today only): today's food log — the
 * totals against the targets and the dishes logged today, never another
 * day — plus today's readiness and the week's check-ins, the weight trend,
 * and the user's mess with today's menu. Each part is bounded too.
 */
import type {
  NutritionDay,
  ProgressSummary,
  Program,
  ProgressionRecommendation,
  RecoveryLog,
  RecoveryToday,
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
/** Beta 5.4: today's logged dishes, the check-in days, a meal's dishes. */
export const CONTEXT_FOOD_ITEMS = 25;
export const CONTEXT_CHECKIN_DAYS = 7;
export const CONTEXT_MESS_DISHES = 15;

export interface NutritionTargetsSummary {
  readonly kcal: number;
  readonly proteinG: number;
  readonly carbG: number;
  readonly fatG: number;
  readonly fiberG: number;
  readonly reason: string;
  /** Beta 3.2 (ADR-031): true when the user set calories and protein themselves. */
  readonly setByUser: boolean;
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
    /** Beta 5.4: today's log is shared; other days never are. */
    readonly foodLogShared: 'today-only';
    readonly today: TodayFood | null;
    readonly note: string;
  };
  /** Beta 5.4: today's readiness (FITOS's own score) and the week's check-ins. */
  readonly readiness: {
    readonly checkedInToday: boolean;
    readonly today: { readonly score: number; readonly band: string; readonly advice: string } | null;
    readonly lastDays: readonly {
      readonly date: string;
      readonly sleepHours: number | null;
      readonly sleepQuality: number | null;
      readonly soreness: number | null;
      readonly energy: number | null;
      readonly stress: number | null;
    }[];
  } | null;
  /** Beta 5.4: the weight trend over the last 30 days, not every reading. */
  readonly weight: {
    readonly trendKg: number | null;
    readonly weeklyChangeKg: number | null;
    readonly change30DaysKg: number | null;
    readonly daysOfData: number;
    readonly reliable: boolean;
  } | null;
  /** Beta 5.4: where the user eats, and today's menu. */
  readonly mess: MessContext | null;
  readonly health: {
    readonly availableToServer: false;
    readonly note: string;
  };
}

/** Beta 5.4: today's food as FITOS AI sees it. A range means estimates. */
export interface TodayFood {
  readonly date: string;
  readonly eaten: { readonly kcal: string; readonly proteinG: string; readonly carbG: string; readonly fatG: string };
  readonly left: { readonly kcal: string; readonly proteinG: string } | null;
  readonly mealsLogged: readonly string[];
  readonly items: readonly { readonly meal: string; readonly food: string; readonly portion: string; readonly kcal: string; readonly proteinG: string }[];
  readonly moreItems: number;
  readonly includesEstimates: boolean;
}

/** Beta 5.4: the user's mess and today's menu (dish names per meal). */
export interface MessContext {
  readonly hostel: string;
  readonly mess: string;
  readonly menuDate: string;
  /** published: the mess's own menu; inferred: the usual menu for this day of the cycle; none: no menu. */
  readonly menu: 'published' | 'inferred' | 'none';
  readonly meals: readonly { readonly meal: string; readonly dishes: readonly string[] }[];
}

export interface ContextServices {
  readonly user: UserService;
  readonly training: TrainingService;
  readonly workout: WorkoutService;
  /** Beta 5.4: each optional, so a part is simply absent where not wired. */
  readonly food?: { today(userId: string): Promise<NutritionDay> };
  readonly recovery?: { today(userId: string): Promise<RecoveryToday>; recent(userId: string, days?: number): Promise<{ today: string; logs: RecoveryLog[] }> };
  readonly progress?: { summary(userId: string, window: '30d'): Promise<ProgressSummary> };
  readonly mess?: { today(userId: string): Promise<MessContext | null> };
}

/** "1436" or "1241–1436": a range where the log holds estimates. */
const range = (low: number, high: number): string => {
  const lo = Math.round(low);
  const hi = Math.round(high);
  return lo === hi ? `${hi}` : `${lo}–${hi}`;
};

const fmtSet = (s: { weightKg: number | null; reps: number; rir: number | null }): string =>
  `${s.weightKg === null ? 'bw' : `${s.weightKg}kg`}×${s.reps}${s.rir === null ? '' : `@${s.rir}`}`;

export class UserContextAssembler {
  constructor(private readonly services: ContextServices, private readonly now: () => Date = () => new Date()) {}

  async assemble(userId: string): Promise<FitosAiContext> {
    const s = this.services;
    const [profile, goal, today, programme, volume, history, food, recoveryToday, recoveryDays, progress, mess] = await Promise.all([
      s.user.getProfile(userId),
      s.user.getGoal(userId),
      s.workout.today(userId).catch(() => null),
      s.training.getProgram(userId).catch(swallowNotFound),
      s.workout.volume(userId).catch(() => null),
      s.workout.list(userId, { limit: 10, status: 'completed' }).catch(() => null),
      s.food === undefined ? null : s.food.today(userId).catch(() => null),
      s.recovery === undefined ? null : s.recovery.today(userId).catch(() => null),
      s.recovery === undefined ? null : s.recovery.recent(userId, CONTEXT_CHECKIN_DAYS).catch(() => null),
      s.progress === undefined ? null : s.progress.summary(userId, '30d').catch(() => null),
      s.mess === undefined ? null : s.mess.today(userId).catch(() => null),
    ]);
    const recent = history === null ? [] : await this.recentSessions(userId, history.items);
    const targets =
      goal.targets === null
        ? null
        : { kcal: goal.targets.kcal, proteinG: goal.targets.proteinG, carbG: goal.targets.carbG, fatG: goal.targets.fatG, fiberG: goal.targets.fiberG, reason: goal.targets.reason, setByUser: goal.targets.source === 'custom' };

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
        foodLogShared: 'today-only',
        today: food === null ? null : UserContextAssembler.foodOf(food),
        note:
          food === null
            ? "Today's food log could not be read; you know the targets only."
            : "Today's food log is shared: totals against the targets and the dishes logged today. Other days are not shared; the Nutrition tab shows them. A number given as a range includes FITOS estimates.",
      },
      readiness: recoveryToday === null && recoveryDays === null ? null : UserContextAssembler.readinessOf(recoveryToday, recoveryDays?.logs ?? []),
      weight: progress === null ? null : UserContextAssembler.weightOf(progress),
      mess,
      health: {
        availableToServer: false,
        note: 'Health Connect data (steps, sleep, resting heart rate, calories, body measurements from the phone) stays on the phone and is not sent to this server or to the assistant. The Home screen shows it.',
      },
    };
  }

  /* --------------------------------------------------------- projections -- */

  /** Beta 5.4: today's food, bounded; the numbers are the server's own. */
  static foodOf(d: NutritionDay): TodayFood {
    const t = d.totals;
    const items = d.logs.flatMap((log) =>
      log.items.map((i) => ({
        meal: log.mealSlot,
        food: i.foodName,
        portion: i.servingLabel === null ? `${i.servings}` : `${i.servings} × ${i.servingLabel}`,
        kcal: range(i.kcalLow, i.kcalHigh),
        proteinG: range(i.proteinLow, i.proteinHigh),
      })),
    );
    const r = d.remaining;
    return {
      date: d.date,
      eaten: { kcal: range(t.kcalLow, t.kcalHigh), proteinG: range(t.proteinLow, t.proteinHigh), carbG: range(t.carbLow, t.carbHigh), fatG: range(t.fatLow, t.fatHigh) },
      left: r === null ? null : { kcal: range(r.kcal.low, r.kcal.high), proteinG: range(r.protein.low, r.protein.high) },
      mealsLogged: [...new Set(d.logs.map((l) => l.mealSlot))],
      items: items.slice(0, CONTEXT_FOOD_ITEMS),
      moreItems: Math.max(0, items.length - CONTEXT_FOOD_ITEMS),
      includesEstimates: t.kcalLow !== t.kcalHigh || t.proteinLow !== t.proteinHigh,
    };
  }

  /** Beta 5.4: today's readiness and the last days' check-ins, oldest first. */
  static readinessOf(today: RecoveryToday | null, logs: readonly RecoveryLog[]): NonNullable<FitosAiContext['readiness']> {
    const r = today?.readiness ?? null;
    return {
      checkedInToday: today?.log !== null && today?.log !== undefined,
      today: r === null ? null : { score: r.score, band: r.band, advice: r.advice },
      lastDays: logs.slice(-CONTEXT_CHECKIN_DAYS).map((l) => ({
        date: l.date,
        sleepHours: l.sleepHours,
        sleepQuality: l.sleepQuality,
        soreness: l.soreness,
        energy: l.energy,
        stress: l.stress,
      })),
    };
  }

  /** Beta 5.4: the trend, never the raw readings. */
  static weightOf(p: ProgressSummary): NonNullable<FitosAiContext['weight']> {
    const w = p.weight;
    return {
      trendKg: w.currentTrendKg,
      weeklyChangeKg: w.weeklyChangeKg,
      change30DaysKg: w.windowChangeKg,
      daysOfData: w.daysOfData,
      reliable: w.isReliable,
    };
  }

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

/** Beta 5.4: the user's mess and today's menu, dish names only, bounded. */
export function messContextOf(
  row: { readonly hostelLabel: string; readonly messLabel: string },
  date: string,
  day: { readonly resolution: { readonly kind: string }; readonly meals: readonly { readonly slot: string; readonly dishes: readonly { readonly name: string }[] }[] },
): MessContext {
  const kind = day.resolution.kind;
  const menu = kind === 'exact' ? 'published' : kind === 'cycle-inferred' ? 'inferred' : 'none';
  return {
    hostel: row.hostelLabel,
    mess: row.messLabel,
    menuDate: date,
    menu,
    meals: menu === 'none' ? [] : day.meals.map((m) => ({ meal: m.slot, dishes: m.dishes.slice(0, CONTEXT_MESS_DISHES).map((d) => d.name) })),
  };
}

function swallowNotFound(e: unknown): null {
  if (e instanceof AppError && e.code === 'NOT_FOUND') return null;
  throw e;
}
