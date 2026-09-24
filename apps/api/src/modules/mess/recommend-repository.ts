/**
 * The caller's own history a mess recommendation needs (Phase 10). Drizzle
 * only; every query is scoped to one user.
 */
import { and, eq, gte, isNotNull, isNull, lte } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { foodLogItems, foodLogs, workoutSessions } from '../../db/schema.js';

type Db = DatabaseHandle['db'];
type Slot = 'breakfast' | 'lunch' | 'snacks' | 'dinner';

export class RecommendRepository {
  constructor(private readonly db: Db) {}

  /** The meals with at least one live log on `localDate`. */
  async loggedSlots(userId: string, localDate: string): Promise<Slot[]> {
    const rows = await this.db
      .selectDistinct({ slot: foodLogs.mealSlot })
      .from(foodLogs)
      .where(and(eq(foodLogs.userId, userId), eq(foodLogs.localDate, localDate), isNull(foodLogs.deletedAt)));
    return rows.map((r) => r.slot);
  }

  /** Per mess dish slug, the distinct local days in [from, to] it was logged (live logs). */
  async varietyDays(userId: string, from: string, to: string): Promise<Record<string, number>> {
    const rows = await this.db
      .selectDistinct({ slug: foodLogItems.messDishSlug, day: foodLogs.localDate })
      .from(foodLogItems)
      .innerJoin(foodLogs, eq(foodLogs.id, foodLogItems.foodLogId))
      .where(
        and(
          eq(foodLogs.userId, userId),
          gte(foodLogs.localDate, from),
          lte(foodLogs.localDate, to),
          isNull(foodLogs.deletedAt),
          isNotNull(foodLogItems.messDishSlug),
        ),
      );
    const days: Record<string, number> = {};
    for (const r of rows) if (r.slug !== null) days[r.slug] = (days[r.slug] ?? 0) + 1;
    return days;
  }

  /** When this user's workouts completed at or after `since` (live sessions). */
  async completedSince(userId: string, since: Date): Promise<Date[]> {
    const rows = await this.db
      .select({ completedAt: workoutSessions.completedAt })
      .from(workoutSessions)
      .where(
        and(
          eq(workoutSessions.userId, userId),
          eq(workoutSessions.status, 'completed'),
          isNull(workoutSessions.deletedAt),
          gte(workoutSessions.completedAt, since),
        ),
      );
    return rows.flatMap((r) => (r.completedAt === null ? [] : [r.completedAt]));
  }
}
