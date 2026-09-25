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
import { adjustTargets, type Goal } from '@fitos/core/nutrition/targets';
import { summariseTrend } from '@fitos/core/nutrition/trend';
import type { MealSlot } from '@fitos/core/mess/types';
import { todayActions, todayClock, type PrType, type TrainingState, type UserModel } from '@fitos/core/recommend/engine';
import { CLOCK_SKEW_MS, COMPLETION_EVIDENCE, checkEventTiming, checkTransition, type TodayEvent } from '@fitos/core/recommend/events';
import { calorieAdjustmentFrom, trainingFromPlan, type PlannedExerciseFacts } from '@fitos/core/recommend/model';

import type { RecommendationEventRow, RecommendationRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { RecommendRepository } from '../mess/recommend-repository.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { TrainingRepository } from '../training/repository.js';
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

    const [day, inputs, program, targets, totals, loggedSlots, lastWeighIn, prs, dismissed, weights, lastAdjustment] = await Promise.all([
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
      this.repo.weights(userId),
      this.repo.lastAdjustmentOn(userId),
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
        // Phase 12: the §13.2 policy, decided by core from the trend (never a single reading).
        adjustment: calorieAdjustmentFrom({
          goal: (inputs.goal?.goalType ?? 'general') as Goal,
          weights: weights.filter((w) => w.date <= localDate),
          targetKcal: targets === null ? null : targets.kcal,
          daysSinceLastAdjustment: lastAdjustment === null ? null : daysBetween(lastAdjustment, localDate),
        }),
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
  private async completionProven(
    userId: string,
    rec: RecommendationRow,
    recorded: readonly RecommendationEventRow[],
    completedAt: Date,
    timeZone: string,
  ): Promise<boolean> {
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
      case 'target-adjusted':
        // Phase 12: the target row this action's acceptance created (it is
        // written with the accepted event, so it lies between the action and
        // the completion).
        return this.repo.adjustedBetween(userId, rec.createdAt, new Date(completedAt.getTime() + CLOCK_SKEW_MS));
      case 'deload-accepted': {
        // "Deload accepted": THIS action was accepted, then the offer was activated,
        // then `completed` was reported. Activation is Phase 6's
        // `POST /training/deload/accept` (it sets `programs.deload_started_at`);
        // migration 0014 keeps every activation in `deload_activations`, so the
        // evidence survives the week closing (P3: a completed event may arrive up
        // to 7 days late). The activation must fall after this action existed, no
        // earlier than its `accepted` event and no later than the `completed`
        // event itself (both phone time, hence the 5-minute skew) — so an older
        // week, or one activated after the fact, never counts.
        const accepted = recorded.find((r) => r.event === 'accepted');
        if (accepted === undefined) return false;
        const from = new Date(Math.max(rec.createdAt.getTime(), accepted.occurredAt.getTime() - CLOCK_SKEW_MS));
        const to = new Date(completedAt.getTime() + CLOCK_SKEW_MS);
        return from.getTime() <= to.getTime() && this.repo.deloadActivatedBetween(userId, from, to);
      }
      case null:
        return false;
    }
  }

  /**
   * Phase 12: the target row an accepted calorie-adjust action creates, from
   * the action's own values and the §13.1 rules (`adjustTargets`). If the
   * target has changed since the action was made, nothing is applied (409):
   * the suggestion no longer describes the user's target.
   */
  private async adjustmentRow(
    userId: string,
    rec: RecommendationRow,
    timeZone: string,
    at: Date,
  ): Promise<Parameters<TodayRepository['insertTargetRow']>[1]> {
    const values = (rec.payload as { reason: { values: { currentKcal: number; newKcal: number; deltaKcal: number } } }).reason.values;
    const today = localDateOf(at, timeZone);
    const current = await this.logs.targetsOn(userId, today);
    if (current === null || current.kcal !== values.currentKcal) {
      throw new AppError('CONFLICT', 'Your calorie target has changed since this suggestion.', [{ path: 'event', issue: 'target-changed' }]);
    }
    const trend = summariseTrend(await this.repo.weights(userId));
    const weightKg = trend.currentTrendKg ?? 0;
    const next = adjustTargets({ proteinG: current.proteinG }, values.newKcal, weightKg);
    const sign = values.deltaKcal > 0 ? '+' : '−';
    return {
      userId,
      effectiveFrom: today,
      kcal: next.kcal,
      proteinG: next.proteinG,
      carbG: next.carbG,
      fatG: next.fatG,
      fiberG: next.fiberG,
      bmr: current.bmr,
      tdeeEstimate: current.tdeeEstimate,
      rationale: [
        ...current.rationale,
        `Adjusted ${sign}${Math.abs(values.deltaKcal)} kcal on ${today}: the weight trend was off pace for your goal, and you accepted the change.`,
      ],
      reason: 'calorie-adjust',
    };
  }

  /**
   * A stored event with the request's client id: an exact replay (same
   * action, event and instant) returns it; anything else is a collision —
   * never an unrelated event passed off as a replay.
   */
  private replayOf(prior: RecommendationEventRow, id: string, event: TodayEvent, occurredAt: Date): TodayEventRecord {
    const mismatches: { path: string; issue: string }[] = [];
    if (prior.recommendationId !== id) mismatches.push({ path: 'clientEventId', issue: 'different-action' });
    if (prior.event !== event) mismatches.push({ path: 'clientEventId', issue: 'different-event' });
    if (prior.occurredAt.getTime() !== occurredAt.getTime()) mismatches.push({ path: 'clientEventId', issue: 'different-occurred-at' });
    if (mismatches.length > 0) {
      throw new AppError('CONFLICT', 'This clientEventId was already used for a different event.', mismatches);
    }
    return eventRecord(prior);
  }

  /**
   * POST /today/actions/{id}/event, in this order:
   *   1. client-id replay → 200 (exact) or 409 (collision) — before any other
   *      check, so an exact replay stays idempotent after the timing window;
   *   2. the caller's own action → else 404;
   *   3. P3 timing for the new event → 422;
   *   4. the Q2 transition (a repeat of a recorded event → 200 with it) → 422;
   *   5. completion evidence → 422;
   *   6. insert → 201.
   */
  async recordEvent(userId: string, id: string, body: TodayEventRequest): Promise<{ created: boolean; event: TodayEventRecord }> {
    const event = body.event as TodayEvent;
    const occurredAt = new Date(body.occurredAt);

    const prior = await this.repo.eventByClientId(userId, body.clientEventId);
    if (prior !== null) return { created: false, event: this.replayOf(prior, id, event, occurredAt) };

    const rec = await this.repo.recommendation(userId, id);
    if (rec === null) throw new AppError('NOT_FOUND', 'No such action.');

    const timeZone = await this.logs.timezoneOf(userId);
    const receivedAt = this.now();
    const timing = checkEventTiming({ generatedFor: rec.generatedFor, timeZone, createdAt: rec.createdAt, occurredAt, receivedAt });
    if (!timing.ok) {
      throw new AppError('VALIDATION_FAILED', 'This event is outside its action’s window.', [{ path: 'occurredAt', issue: timing.code }]);
    }

    const outcome = await this.repo.withEvents(rec.id, async (recorded, insert, tx) => {
      const transition = checkTransition(rec.kind, recorded.map((r) => r.event), event);
      if (transition.outcome === 'duplicate') {
        return { created: false, row: recorded.find((r) => r.event === event)! };
      }
      if (transition.outcome === 'reject') {
        throw new AppError('VALIDATION_FAILED', `Cannot record "${event}" for this action.`, [{ path: 'event', issue: transition.code }]);
      }
      if (event === 'completed' && !(await this.completionProven(userId, rec, recorded, occurredAt, timeZone))) {
        throw new AppError('VALIDATION_FAILED', 'Nothing on record completes this action yet.', [{ path: 'event', issue: 'no-evidence' }]);
      }
      // Phase 12: accepting a calorie-adjust action applies it — a NEW target
      // row (history; the current row never changes). Checked before the
      // event is stored, written only once it is.
      const adjustment = event === 'accepted' && rec.kind === 'calorie-adjust' ? await this.adjustmentRow(userId, rec, timeZone, receivedAt) : null;
      const row = await insert({ recommendationId: rec.id, userId, event, clientEventId: body.clientEventId, occurredAt, receivedAt });
      if (row !== null && adjustment !== null) await this.repo.insertTargetRow(tx, adjustment);
      return row === null ? null : { created: true, row };
    });
    if (outcome !== null) return { created: outcome.created, event: eventRecord(outcome.row) };

    // A concurrent request stored this client id after step 1: the same replay-or-collision rule.
    const raced = await this.repo.eventByClientId(userId, body.clientEventId);
    if (raced === null) throw new Error('TODAY: event insert conflicted but no row was found');
    return { created: false, event: this.replayOf(raced, id, event, occurredAt) };
  }
}
