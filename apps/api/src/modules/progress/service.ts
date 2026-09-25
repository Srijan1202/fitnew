/**
 * Progress (Phase 12, MASTER-SPEC §17, §13.2; ADR-018). Gathers the user's
 * own rows in their stored timezone and hands them to core; every number is
 * computed on read (§9.4) and nothing derived is stored. Weight entered here
 * never recalculates the nutrition targets (owner D5) — the targets follow
 * the trend through TODAY's calorie-adjust action instead.
 */
import {
  PROGRESS_DAYS_BACK,
  type LogMeasurementRequest,
  type LogMeasurementResponse,
  type LogWeightRequest,
  type LogWeightResponse,
  type ProgressSummary,
  type ProgressWindow,
} from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { adherence, bestLifts, consistency, measurementProgress, weightProgress, windowStart } from '@fitos/core/progress/summary';

import { AppError } from '../../lib/errors.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { ProgressRepository } from './repository.js';

/** A day of slack either side of the local window, for any zone; the local date decides. */
const DAY_MS = 86_400_000;

export class ProgressService {
  constructor(
    private readonly repo: ProgressRepository,
    private readonly logs: FoodLogRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async summary(userId: string, window: ProgressWindow): Promise<ProgressSummary> {
    const tz = await this.logs.timezoneOf(userId);
    const today = localDateOf(this.now(), tz);
    const from = windowStart(today, window);
    const lo = new Date(Date.parse(`${from}T00:00:00Z`) - DAY_MS);
    const hi = new Date(Date.parse(`${today}T00:00:00Z`) + 2 * DAY_MS);
    const inWindow = (at: Date): string | null => {
      const d = localDateOf(at, tz);
      return d >= from && d <= today ? d : null;
    };

    const [weights, measurements, days, targets, completed, planned, prs, sets] = await Promise.all([
      this.repo.weights(userId),
      this.repo.measurements(userId),
      this.repo.nutritionDays(userId, from, today),
      this.repo.targets(userId),
      this.repo.completedAt(userId, lo, hi),
      this.repo.plannedDays(userId),
      this.repo.prs(userId, lo, hi),
      this.repo.workingSets(userId, lo, hi),
    ]);

    const weight = weightProgress(weights, today, window);
    return {
      window,
      today,
      from,
      weight: {
        points: weight.points.map((p) => ({ date: p.date, rawKg: p.rawKg, trendKg: p.trendKg })),
        currentTrendKg: weight.currentTrendKg,
        weeklyChangeKg: weight.weeklyChangeKg,
        daysOfData: weight.daysOfData,
        isReliable: weight.isReliable,
        windowChangeKg: weight.windowChangeKg,
        windowChangeDays: weight.windowChangeDays,
      },
      measurements: measurementProgress(measurements, today, window).map((m) => ({
        site: m.site,
        latest: { ...m.latest },
        changeCm: m.changeCm,
        changeDays: m.changeDays,
      })),
      prs: prs.flatMap((p) => {
        const on = inWindow(p.achievedAt);
        return on === null
          ? []
          : [{ id: p.id, exerciseId: p.exerciseId, exerciseName: p.exerciseName, prType: p.prType, value: p.value, previous: p.previous, reason: p.reason, achievedOn: on }];
      }),
      bestLifts: bestLifts(
        sets.flatMap((s) => {
          const on = inWindow(s.completedAt);
          return on === null ? [] : [{ exerciseId: s.exerciseId, exerciseName: s.exerciseName, date: on, weightKg: s.weightKg, reps: s.reps }];
        }),
      ).map((b) => ({ ...b })),
      adherence: adherence(days, targets, today, window),
      consistency: (() => {
        const c = consistency(
          completed.flatMap((at) => {
            const on = inWindow(at);
            return on === null ? [] : [on];
          }),
          planned,
          today,
          window,
        );
        return { weeks: c.weeks.map((w) => ({ ...w })), completed: c.completed, planned: c.planned, percent: c.percent };
      })(),
    };
  }

  /**
   * The local date a reading belongs to: the given one, or today. A real
   * calendar date, never in the future, at most 30 days back (owner D5).
   */
  private async dateFor(userId: string, date: string | undefined): Promise<string> {
    const tz = await this.logs.timezoneOf(userId);
    const today = localDateOf(this.now(), tz);
    const d = date ?? today;
    const parsed = new Date(`${d}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== d) {
      throw new AppError('VALIDATION_FAILED', 'That is not a calendar date.', [{ path: 'date', issue: 'not a date' }]);
    }
    if (d > today) {
      throw new AppError('VALIDATION_FAILED', 'Readings cannot be dated in the future.', [{ path: 'date', issue: 'in the future' }]);
    }
    if (d < addDays(today, -PROGRESS_DAYS_BACK)) {
      throw new AppError('VALIDATION_FAILED', `Readings can be dated up to ${PROGRESS_DAYS_BACK} days back.`, [
        { path: 'date', issue: `more than ${PROGRESS_DAYS_BACK} days ago` },
      ]);
    }
    return d;
  }

  async logWeight(userId: string, req: LogWeightRequest): Promise<{ created: boolean; body: LogWeightResponse }> {
    const date = await this.dateFor(userId, req.date);
    const { row, created } = await this.repo.upsertWeight(userId, date, req.weightKg);
    return { created, body: { weight: { date: row.measuredOn, weightKg: Number(row.weightKg), source: row.source } } };
  }

  async logMeasurement(userId: string, req: LogMeasurementRequest): Promise<{ created: boolean; body: LogMeasurementResponse }> {
    const date = await this.dateFor(userId, req.date);
    const { row, created } = await this.repo.upsertMeasurement(userId, date, req.site, req.valueCm);
    return { created, body: { measurement: { date: row.measuredOn, site: row.site, valueCm: Number(row.valueCm) } } };
  }
}
