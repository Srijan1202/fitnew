/**
 * Recovery (Phase 13, MASTER-SPEC §18, §10.1; ADR-019): the daily check-in
 * and today's readiness. Readiness is core's, computed on read from the
 * user's own records in their stored timezone; nothing derived is stored.
 * Nothing here changes the plan — the bands only choose what TODAY and the
 * deload offer suggest.
 */
import { READINESS_RUNNING_FROM_BUILD, RECOVERY_DAYS_BACK, type LogRecoveryRequest, type LogRecoveryResponse, type RecoveryLog, type RecoveryToday } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';

import type { RecoveryLogRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { ReadinessAssembler } from './readiness.js';
import type { RecoveryRepository } from './repository.js';

export function toWire(row: RecoveryLogRow): RecoveryLog {
  return {
    date: row.loggedOn,
    sleepHours: row.sleepHours === null ? null : Number(row.sleepHours),
    sleepQuality: row.sleepQuality,
    soreness: row.soreness,
    energy: row.energy,
    stress: row.stress,
    source: row.source,
  };
}

export class RecoveryService {
  constructor(
    private readonly repo: RecoveryRepository,
    private readonly readiness: ReadinessAssembler,
    private readonly logs: FoodLogRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /**
   * Beta 4.1: `appBuild` is the phone's build (the X-FITOS-Build header); a
   * build before running load reads the five Phase 13 parts only, so the
   * sixth is left out for it (the score is the same for everyone).
   */
  async today(userId: string, appBuild: number | null = null): Promise<RecoveryToday> {
    const tz = await this.logs.timezoneOf(userId);
    const today = localDateOf(this.now(), tz);
    const [rows, assessed] = await Promise.all([this.repo.checkIns(userId, today, today), this.readiness.assess(userId, today, tz)]);
    const log = rows[0];
    const r = assessed.readiness;
    return {
      date: today,
      log: log === undefined ? null : toWire(log),
      readiness:
        r === null
          ? null
          : {
              score: r.score,
              band: r.band,
              advice: r.advice,
              components: r.components
                .filter((c) => c.key !== 'running' || (appBuild !== null && appBuild >= READINESS_RUNNING_FROM_BUILD))
                .map((c) => ({ key: c.key, penalty: c.penalty, max: c.max, available: c.available })),
              lowDays: assessed.lowDays,
            },
    };
  }

  /**
   * The local date a check-in belongs to: the given one, or today. A real
   * calendar date, never ahead, at most 7 days back (readiness looks no
   * further — owner D2).
   */
  private dateFor(today: string, date: string | undefined): string {
    const d = date ?? today;
    const parsed = new Date(`${d}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== d) {
      throw new AppError('VALIDATION_FAILED', 'That is not a calendar date.', [{ path: 'date', issue: 'not a date' }]);
    }
    if (d > today) {
      throw new AppError('VALIDATION_FAILED', 'A check-in cannot be dated in the future.', [{ path: 'date', issue: 'in the future' }]);
    }
    if (d < addDays(today, -RECOVERY_DAYS_BACK)) {
      throw new AppError('VALIDATION_FAILED', `A check-in can be dated up to ${RECOVERY_DAYS_BACK} days back.`, [
        { path: 'date', issue: `more than ${RECOVERY_DAYS_BACK} days ago` },
      ]);
    }
    return d;
  }

  /** Upsert the day's check-in: it is REPLACED by what is sent (owner D2). */
  async log(userId: string, req: LogRecoveryRequest): Promise<{ created: boolean; body: LogRecoveryResponse }> {
    const tz = await this.logs.timezoneOf(userId);
    const date = this.dateFor(localDateOf(this.now(), tz), req.date);
    const values = {
      // One decimal is kept (numeric(3,1)).
      sleepHours: req.sleepHours === undefined || req.sleepHours === null ? null : Math.round(req.sleepHours * 10) / 10,
      sleepQuality: req.sleepQuality ?? null,
      soreness: req.soreness ?? null,
      energy: req.energy ?? null,
      stress: req.stress ?? null,
    };
    if (Object.values(values).every((v) => v === null)) {
      throw new AppError('VALIDATION_FAILED', 'Answer at least one question.', [{ path: '', issue: 'at least one value' }]);
    }
    const { row, created } = await this.repo.upsert(userId, date, values);
    return { created, body: { log: toWire(row) } };
  }
}
