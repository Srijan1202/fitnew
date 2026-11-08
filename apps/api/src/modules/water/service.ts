/**
 * Beta 6.0 (F7, ADR-059): the day's water and its target. The phone sends
 * the day's total (PUT replaces it), so a tap queued offline and sent twice
 * changes nothing; the target is core's, from the latest weigh-in.
 */
import { WATER_DAYS_BACK, type WaterDay } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { waterTargetMl } from '@fitos/core/nutrition/water';

import { AppError } from '../../lib/errors.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { WaterRepository } from './repository.js';

export class WaterService {
  constructor(
    private readonly repo: WaterRepository,
    private readonly logs: FoodLogRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private async localToday(userId: string): Promise<string> {
    return localDateOf(this.now(), await this.logs.timezoneOf(userId));
  }

  /** A real calendar date, never ahead, at most [WATER_DAYS_BACK] days back. */
  private check(today: string, date: string): string {
    const parsed = new Date(`${date}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
      throw new AppError('VALIDATION_FAILED', 'That is not a calendar date.', [{ path: 'date', issue: 'not a date' }]);
    }
    if (date > today) {
      throw new AppError('VALIDATION_FAILED', 'Water cannot be logged for a day ahead.', [{ path: 'date', issue: 'in the future' }]);
    }
    if (date < addDays(today, -WATER_DAYS_BACK)) {
      throw new AppError('VALIDATION_FAILED', `Water can be changed up to ${WATER_DAYS_BACK} days back.`, [
        { path: 'date', issue: `more than ${WATER_DAYS_BACK} days ago` },
      ]);
    }
    return date;
  }

  private async wire(userId: string, date: string, ml: number): Promise<WaterDay> {
    const kg = await this.repo.weightOn(userId, date);
    return { date, ml, targetMl: waterTargetMl(kg), fromWeight: kg !== null };
  }

  async today(userId: string): Promise<WaterDay> {
    const today = await this.localToday(userId);
    const row = await this.repo.day(userId, today);
    return this.wire(userId, today, row?.ml ?? 0);
  }

  async set(userId: string, date: string, ml: number): Promise<{ created: boolean; body: WaterDay }> {
    const d = this.check(await this.localToday(userId), date);
    const { row, created } = await this.repo.set(userId, d, ml);
    return { created, body: await this.wire(userId, d, row.ml) };
  }
}
