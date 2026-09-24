/**
 * TODAY (Phase 11, ADR-017): assembles the server `UserModel` from the
 * user's own records, runs the deterministic core engine, persists what it
 * put on the surface and records how the user responded.
 *
 * Every business rule lives in core: the engine (`todayActions`), the
 * limitation/progression split (`trainingFromPlan`, owner Q1), the event
 * transitions and timing (`checkTransition`, `checkEventTiming`). This file
 * only gathers facts and applies those functions.
 */
import type { TodayActionsResponse, TodayEventRecord, TodayEventRequest, TodayReason } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import type { Goal } from '@fitos/core/nutrition/targets';
import type { MealSlot } from '@fitos/core/mess/types';
import { todayActions, todayClock, type PrType, type TrainingState, type UserModel } from '@fitos/core/recommend/engine';
import { COMPLETION_EVIDENCE, checkEventTiming, checkTransition, type TodayEvent } from '@fitos/core/recommend/events';
import { trainingFromPlan, type PlannedExerciseFacts } from '@fitos/core/recommend/model';

import type { RecommendationEventRow, RecommendationRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { RecommendRepository } from '../mess/recommend-repository.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { TrainingRepository } from '../training/repository.js';
import { ProgressionAssembler } from '../workout/progression.js';
import { isoDayOfWeek, type WorkoutService } from '../workout/service.js';
import type { TodayRepository } from './repository.js';

/** Whole days from `from` to `to` (both yyyy-mm-dd). */
function daysBetween(from: string, to: string): number {
  const at = (d: string): number => {
    const [y, m, day] = d.split('-').map(Number) as [number, number, number];
    return Date.UTC(y, m - 1, day);
  };
  return Math.round((at(to) - at(from)) / 86_400_000);
}

function eventRecord(row: RecommendationEventRow): TodayEventRecord {
  return {
    id: row.id,
    recommendationId: row.recommendationId,
    event: row.event,
    clientEventId: row.clientEventId,
    occurredAt: row.occurredAt.toISOString(),
    receivedAt: row.receivedAt.toISOString(),
  };
}

const NOTHING_EATEN = { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0 } as const;

export class TodayService {
  constructor(
    private readonly repo: TodayRepository,
    private readonly workout: WorkoutService,
    private readonly training: TrainingRepository,
    private readonly logs: FoodLogRepository,
    private readonly slots: RecommendRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** The `UserModel` for the user's local day at `now`, in their stored zone (P7). */
  async model(userId: string, now: Date): Promise<{ model: UserModel; timeZone: string; trainingDate: string }> {
    const timeZone = await this.logs.timezoneOf(userId);
    const { localDate, hourOfDay } = todayClock(now, timeZone);

    const [day, inputs, program, targets, totals, loggedSlots, lastWeighIn, prs, dismissed] = await Promise.all([
      this.workout.today(userId),
      this.training.profileInputs(userId),
      this.training.activeProgram(userId),
      this.logs.targetsOn(userId, localDate),
      this.logs.dayTotals(userId, localDate),
      this.slots.loggedSlots(userId, localDate),
      this.repo.latestWeighIn(userId),
      // Two days back covers every zone; the local day is kept below.
      this.repo.prsSince(userId, new Date(now.getTime() - 48 * 3_600_000)),
      this.repo.dismissedOn(userId, localDate),
    ]);

    // Owner Q1: the facts go through core's `trainingFromPlan`, which keeps a
    // ruled-out exercise out of `increaseLoad`. Nothing here re-derives either list.
    const active = new Set(inputs.limitations);
    const contraindications = await this.repo.contraindications([...new Set(day.exercises.map((x) => x.exerciseId))]);
    const facts: PlannedExerciseFacts[] = day.exercises.map((x) => {
      // The library's swap is performable and itself not contraindicated (core `pickAlternative`).
      const alternative = x.substitution?.alternative ?? null;
      return {
        exerciseId: x.exerciseId,
        exerciseName: x.name,
        progression: x.recommendation === null ? null : { action: x.recommendation.action, weightKg: x.recommendation.weightKg, repTarget: x.recommendation.repTarget },
        ruledOutBy: [...new Set((contraindications.get(x.exerciseId) ?? []).filter((p) => active.has(p)))],
        swap: alternative === null ? null : { exerciseId: alternative.exerciseId, exerciseName: alternative.name },
      };
    });

    // The next scheduled session after today, within the coming week (§16.2, for rest-day).
    let nextSession: TrainingState['nextSession'] = null;
    if (program !== null) {
      for (let d = 1; d <= 7 && nextSession === null; d++) {
        const date = addDays(localDate, d);
        const next = program.days.find((x) => x.dayOfWeek === isoDayOfWeek(date) && !x.isRest);
        if (next !== undefined) nextSession = { name: next.sessionName, date };
      }
    }

    const training: TrainingState = {
      hasProgramme: day.programId !== null,
      sessionName: day.sessionName,
      exerciseCount: day.sessionName === null ? 0 : day.exercises.length,
      plannedSetCount: day.sessionName === null ? 0 : day.exercises.reduce((n, x) => n + x.targets.length, 0),
      completedToday: day.completedSessionId !== null,
      activeSessionOpen: day.activeSession !== null,
      deload: { state: day.deload.state, trigger: day.deload.trigger },
      ...trainingFromPlan(facts),
      neglected: day.neglected.map((n) => ({ muscle: n.muscle, daysSince: n.daysSince })),
      prsToday: prs
        .filter((p) => localDateOf(p.achievedAt, timeZone) === localDate)
        .map((p) => ({ prId: p.id, exerciseName: p.exerciseName, prType: p.prType as PrType, value: p.value, previous: p.previous })),
      nextSession,
    };

    const model: UserModel = {
      localDate,
      hourOfDay,
      goal: (inputs.goal?.goalType ?? 'general') as Goal,
      training,
      nutrition: {
        targets: targets === null ? null : { kcal: targets.kcal, proteinG: targets.proteinG },
        // Phase 8 ranges, never a midpoint (§31).
        eaten:
          totals === null
            ? NOTHING_EATEN
            : {
                kcalLow: Number(totals.kcalLow),
                kcalHigh: Number(totals.kcalHigh),
                proteinLow: Number(totals.proteinLow),
                proteinHigh: Number(totals.proteinHigh),
              },
        loggedSlots: loggedSlots as MealSlot[],
      },
      body: {
        weighedToday: lastWeighIn === localDate,
        daysSinceWeighIn: lastWeighIn === null ? null : Math.max(0, daysBetween(lastWeighIn, localDate)),
      },
      dismissedToday: dismissed,
    };
    return { model, timeZone, trainingDate: day.date };
  }

  /**
   * GET /today. Deterministic for the same records and hour; each action is
   * stored once per content identity (D4) and returned with its current rank.
   */
  async today(userId: string): Promise<TodayActionsResponse> {
    let now = this.now();
    let assembled = await this.model(userId, now);
    // `/training/today` reads its own clock: across local midnight its day can differ from ours. Assemble once more.
    if (assembled.trainingDate !== assembled.model.localDate) {
      now = this.now();
      assembled = await this.model(userId, now);
    }
    const result = todayActions(assembled.model);
    const ids = await this.repo.persist(
      userId,
      result.actions.map((a) => ({
        generatedFor: result.localDate,
        kind: a.kind,
        subjectKey: a.subjectKey,
        rank: a.rank,
        priority: a.priority,
        basis: a.basis,
        target: a.target,
        payload: { reason: a.reason, engineVersion: a.engineVersion, inputDigest: result.inputDigest },
        engineVersion: a.engineVersion,
        inputDigest: result.inputDigest,
        headline: a.headline,
        detail: a.detail,
        contentHash: a.contentHash,
      })),
    );
    return {
      date: result.localDate,
      generatedAt: now.toISOString(),
      engineVersion: result.engineVersion,
      actions: result.actions.map((a) => {
        const id = ids.get(a.contentHash);
        if (id === undefined) throw new Error(`TODAY: no stored row for ${a.kind}/${a.subjectKey}`);
        return {
          id,
          kind: a.kind,
          subjectKey: a.subjectKey,
          rank: a.rank,
          priority: a.priority,
          basis: a.basis,
          target: a.target,
          reason: a.reason as TodayReason,
          headline: a.headline,
          detail: a.detail,
        };
      }),
    };
  }

  /* ----------------------------------------------------------- events -- */

  /** Whether the server's own records prove `completed` for this action (D7). */
  private async completionProven(userId: string, rec: RecommendationRow, timeZone: string): Promise<boolean> {
    const evidence = COMPLETION_EVIDENCE[rec.kind];
    const day = rec.generatedFor;
    const sessionsOnDay = async (): Promise<string[]> => {
      // A window wide enough for any zone, narrowed to the local day.
      const from = new Date(`${addDays(day, -1)}T00:00:00Z`);
      const to = new Date(`${addDays(day, 2)}T00:00:00Z`);
      const rows = await this.repo.completedSessions(userId, from, to);
      return rows.filter((s) => localDateOf(s.completedAt, timeZone) === day).map((s) => s.id);
    };
    switch (evidence) {
      case 'session-completed':
        return (await sessionsOnDay()).length > 0;
      case 'session-with-exercise':
        return this.repo.sessionsHaveExercise(await sessionsOnDay(), rec.subjectKey);
      case 'session-with-muscle':
        return this.repo.sessionsWorkMuscle(await sessionsOnDay(), rec.subjectKey);
      case 'food-logged-in-slot':
        return this.repo.foodLoggedIn(userId, day, rec.subjectKey);
      case 'weight-logged':
        return this.repo.weighedOn(userId, day);
      case 'deload-accepted': {
        // "The deload is now active (accepted)": the programme's lighter week is running.
        const window = ProgressionAssembler.deloadWindow(await this.training.activeProgram(userId));
        return window !== null && this.now().getTime() < window.endsAt.getTime();
      }
      case null:
        return false;
    }
  }

  /**
   * POST /today/actions/{id}/event. 201 when stored; 200 with the stored
   * event on a replay of the client id or a repeat of an event already
   * recorded (each event once per recommendation, D7).
   */
  async recordEvent(userId: string, id: string, body: TodayEventRequest): Promise<{ created: boolean; event: TodayEventRecord }> {
    const rec = await this.repo.recommendation(userId, id);
    if (rec === null) throw new AppError('NOT_FOUND', 'No such action.');

    const replay = await this.repo.eventByClientId(userId, body.clientEventId);
    if (replay !== null) return { created: false, event: eventRecord(replay) };

    const timeZone = await this.logs.timezoneOf(userId);
    const occurredAt = new Date(body.occurredAt);
    const receivedAt = this.now();
    const timing = checkEventTiming({ generatedFor: rec.generatedFor, timeZone, createdAt: rec.createdAt, occurredAt, receivedAt });
    if (!timing.ok) {
      throw new AppError('VALIDATION_FAILED', 'This event is outside its action’s window.', [{ path: 'occurredAt', issue: timing.code }]);
    }

    const event = body.event as TodayEvent;
    const outcome = await this.repo.withEvents(rec.id, async (recorded, insert) => {
      const transition = checkTransition(rec.kind, recorded.map((r) => r.event), event);
      if (transition.outcome === 'duplicate') {
        return { created: false, row: recorded.find((r) => r.event === event)! };
      }
      if (transition.outcome === 'reject') {
        throw new AppError('VALIDATION_FAILED', `Cannot record "${event}" for this action.`, [{ path: 'event', issue: transition.code }]);
      }
      if (event === 'completed' && !(await this.completionProven(userId, rec, timeZone))) {
        throw new AppError('VALIDATION_FAILED', 'Nothing on record completes this action yet.', [{ path: 'event', issue: 'no-evidence' }]);
      }
      const row = await insert({ recommendationId: rec.id, userId, event, clientEventId: body.clientEventId, occurredAt, receivedAt });
      return row === null ? null : { created: true, row };
    });
    if (outcome !== null) return { created: outcome.created, event: eventRecord(outcome.row) };

    // The client id was stored by a concurrent request since the replay check.
    const raced = await this.repo.eventByClientId(userId, body.clientEventId);
    if (raced === null) throw new Error('TODAY: event insert conflicted but no row was found');
    return { created: false, event: eventRecord(raced) };
  }
}
