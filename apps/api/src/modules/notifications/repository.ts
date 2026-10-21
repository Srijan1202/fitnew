/**
 * Phase 15 — the facts the notification planner reads, and the ledger it
 * writes (ADR-021). Reads are bounded to the last few weeks; every query is
 * scoped by user.
 */
import { and, eq, gt, gte, inArray, isNull, notInArray, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  bodyMetrics,
  dailyNutrition,
  foodLogs,
  notifications,
  pushTokens,
  recoveryLogs,
  userPreferences,
  users,
  workoutSessions,
  type NotificationRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface PlannedRow {
  readonly kind: NotificationRow['kind'];
  readonly localDate: string;
  readonly scheduledFor: Date;
  readonly variant: string;
  readonly title: string;
  readonly body: string;
}

export class NotificationRepository {
  constructor(private readonly db: Db) {}

  async storedSettings(userId: string): Promise<unknown> {
    const [row] = await this.db
      .select({ s: userPreferences.notificationSettings })
      .from(userPreferences)
      .where(eq(userPreferences.userId, userId))
      .limit(1);
    return row?.s ?? {};
  }

  async saveSettings(userId: string, settings: unknown): Promise<void> {
    await this.db
      .insert(userPreferences)
      .values({ userId, notificationSettings: settings })
      .onConflictDoUpdate({
        target: userPreferences.userId,
        set: { notificationSettings: settings, updatedAt: sql`now()` },
      });
  }

  async displayName(userId: string): Promise<string | null> {
    const [row] = await this.db.select({ n: users.displayName }).from(users).where(eq(users.id, userId)).limit(1);
    return row?.n ?? null;
  }

  async sessionsSince(userId: string, since: Date): Promise<{ startedAt: Date; completedAt: Date | null }[]> {
    return this.db
      .select({
        startedAt: workoutSessions.startedAt,
        completedAt: workoutSessions.completedAt,
      })
      .from(workoutSessions)
      .where(and(eq(workoutSessions.userId, userId), gte(workoutSessions.startedAt, since)));
  }

  async foodLogsSince(
    userId: string,
    since: Date,
  ): Promise<
    {
      at: Date;
      slot: 'breakfast' | 'lunch' | 'snacks' | 'dinner';
      localDate: string;
    }[]
  > {
    return this.db
      .select({
        at: foodLogs.loggedAt,
        slot: foodLogs.mealSlot,
        localDate: foodLogs.localDate,
      })
      .from(foodLogs)
      .where(and(eq(foodLogs.userId, userId), gte(foodLogs.loggedAt, since), isNull(foodLogs.deletedAt)));
  }

  async weighInsSince(userId: string, sinceDate: string): Promise<{ at: Date; localDate: string }[]> {
    return this.db
      .select({ at: bodyMetrics.createdAt, localDate: bodyMetrics.measuredOn })
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), gte(bodyMetrics.measuredOn, sinceDate), isNull(bodyMetrics.deletedAt)));
  }

  async checkInsSince(userId: string, sinceDate: string): Promise<{ at: Date; localDate: string }[]> {
    return this.db
      .select({ at: recoveryLogs.createdAt, localDate: recoveryLogs.loggedOn })
      .from(recoveryLogs)
      .where(and(eq(recoveryLogs.userId, userId), gte(recoveryLogs.loggedOn, sinceDate)));
  }

  async proteinDays(userId: string, sinceDate: string): Promise<{ localDate: string; proteinHigh: number }[]> {
    const rows = await this.db
      .select({
        localDate: dailyNutrition.localDate,
        proteinHigh: dailyNutrition.proteinHigh,
      })
      .from(dailyNutrition)
      .where(and(eq(dailyNutrition.userId, userId), gte(dailyNutrition.localDate, sinceDate)));
    return rows.map((r) => ({
      localDate: r.localDate,
      proteinHigh: Number(r.proteinHigh),
    }));
  }

  async history(userId: string, sinceDate: string): Promise<NotificationRow[]> {
    return this.db
      .select()
      .from(notifications)
      .where(and(eq(notifications.userId, userId), gte(notifications.localDate, sinceDate)));
  }

  /**
   * The phone's reports. Replay-safe and forward-only: planned → delivered →
   * opened; planned → cancelled. Unknown ids and other users' ids are ignored.
   */
  async applyEvents(
    userId: string,
    events: readonly {
      id: string;
      event: 'delivered' | 'opened' | 'cancelled';
      at: Date;
    }[],
  ): Promise<void> {
    for (const e of events) {
      const mine = and(eq(notifications.id, e.id), eq(notifications.userId, userId));
      if (e.event === 'delivered') {
        await this.db
          .update(notifications)
          .set({ status: 'delivered', sentAt: e.at, updatedAt: sql`now()` })
          .where(and(mine, eq(notifications.status, 'planned')));
      } else if (e.event === 'opened') {
        await this.db
          .update(notifications)
          .set({
            status: 'opened',
            openedAt: e.at,
            sentAt: sql`coalesce(${notifications.sentAt}, ${e.at.toISOString()}::timestamptz)`,
            updatedAt: sql`now()`,
          })
          .where(and(mine, inArray(notifications.status, ['planned', 'delivered'])));
      } else {
        await this.db
          .update(notifications)
          .set({
            status: 'cancelled',
            cancelledAt: e.at,
            updatedAt: sql`now()`,
          })
          .where(and(mine, eq(notifications.status, 'planned')));
      }
    }
  }

  /**
   * Replace the future part of the plan: the new items are written onto the
   * same row for the same user, kind and day (so ids are stable while the
   * plan holds), then planned rows still ahead that the plan dropped are
   * deleted. Rows the phone has reported on are never touched.
   */
  async replacePlan(userId: string, now: Date, items: readonly PlannedRow[]): Promise<NotificationRow[]> {
    return this.db.transaction(async (tx) => {
      const kept =
        items.length === 0
          ? []
          : await tx
              .insert(notifications)
              .values(items.map((i) => ({ ...i, userId })))
              .onConflictDoUpdate({
                target: [notifications.userId, notifications.kind, notifications.localDate],
                set: {
                  scheduledFor: sql`excluded.scheduled_for`,
                  variant: sql`excluded.variant`,
                  title: sql`excluded.title`,
                  body: sql`excluded.body`,
                  updatedAt: sql`now()`,
                },
                setWhere: eq(notifications.status, 'planned'),
              })
              .returning();
      // Planned rows still ahead that the new plan no longer has.
      const stale = and(eq(notifications.userId, userId), eq(notifications.status, 'planned'), gt(notifications.scheduledFor, now));
      await tx.delete(notifications).where(
        kept.length === 0
          ? stale
          : and(
              stale,
              notInArray(
                notifications.id,
                kept.map((k) => k.id),
              ),
            ),
      );
      return kept;
    });
  }

  async saveToken(userId: string, token: string, platform: 'android'): Promise<void> {
    await this.db
      .insert(pushTokens)
      .values({ userId, token, platform })
      .onConflictDoUpdate({
        target: pushTokens.token,
        set: { userId, platform, updatedAt: sql`now()` },
      });
  }
}
