/**
 * Phase 14 cost control (§19.3, ADR-020 D3/D4): every model call is a row in
 * `ai_usage`; the hourly limits per purpose and the daily token budget are
 * counted from it, so they survive a restart and hold across instances.
 * The kill switch is checked first, before anything else.
 */
import { and, count, eq, gte, sql } from 'drizzle-orm';

import type { AiRoute } from '@fitos/core/ai/guard';

import type { DatabaseHandle } from '../../db/client.js';
import { aiUsage } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { AiConfig } from '../../plugins/ai.js';

type Db = DatabaseHandle['db'];

export type AiOutcome = 'ok' | 'discarded' | 'failed';

export class AiUsageRepository {
  constructor(private readonly db: Db) {}

  async callsSince(userId: string, route: AiRoute, since: Date): Promise<number> {
    const [row] = await this.db
      .select({ n: count() })
      .from(aiUsage)
      .where(and(eq(aiUsage.userId, userId), eq(aiUsage.route, route), gte(aiUsage.createdAt, since)));
    return Number(row?.n ?? 0);
  }

  async tokensSince(userId: string, since: Date): Promise<number> {
    const [row] = await this.db
      .select({ n: sql<string>`coalesce(sum(${aiUsage.inputTokens} + ${aiUsage.outputTokens}), 0)` })
      .from(aiUsage)
      .where(and(eq(aiUsage.userId, userId), gte(aiUsage.createdAt, since)));
    return Number(row?.n ?? 0);
  }

  async record(row: {
    userId: string;
    route: AiRoute;
    model: string;
    inputTokens: number;
    outputTokens: number;
    outcome: AiOutcome;
  }): Promise<void> {
    await this.db.insert(aiUsage).values({
      ...row,
      inputTokens: Math.max(0, Math.round(row.inputTokens)),
      outputTokens: Math.max(0, Math.round(row.outputTokens)),
    });
  }
}

const HOUR_MS = 3_600_000;

export class AiBudget {
  constructor(
    private readonly repo: AiUsageRepository,
    private readonly config: AiConfig,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** The kill switch (§19.3): every AI route answers this when AI is off. */
  assertEnabled(): void {
    if (!this.config.enabled) {
      throw new AppError('UPSTREAM_UNAVAILABLE', 'FITOS AI is switched off on this server. Everything else works as usual.', [
        { path: 'ai', issue: 'disabled' },
      ]);
    }
  }

  /** Off, over this purpose's hourly limit, or over the daily token budget → refused before any model call. */
  async check(userId: string, route: AiRoute): Promise<void> {
    this.assertEnabled();
    const now = this.now().getTime();
    const [calls, tokens] = await Promise.all([
      this.repo.callsSince(userId, route, new Date(now - HOUR_MS)),
      this.repo.tokensSince(userId, new Date(now - 24 * HOUR_MS)),
    ]);
    const limit = this.config.perHour[route];
    if (calls >= limit) {
      throw new AppError('RATE_LIMITED', `You have used this ${limit} times in the last hour. Try again a little later.`, [
        { path: 'ai', issue: `hourly limit (${route})` },
      ]);
    }
    if (tokens >= this.config.dailyTokens) {
      throw new AppError('RATE_LIMITED', "Today's FITOS AI allowance is used up. It resets over the next day.", [
        { path: 'ai', issue: 'daily token budget' },
      ]);
    }
  }

  async record(
    userId: string,
    route: AiRoute,
    model: string,
    usage: { inputTokens: number; outputTokens: number } | undefined,
    outcome: AiOutcome,
  ): Promise<void> {
    await this.repo.record({
      userId,
      route,
      model,
      inputTokens: usage?.inputTokens ?? 0,
      outputTokens: usage?.outputTokens ?? 0,
      outcome,
    });
  }
}
