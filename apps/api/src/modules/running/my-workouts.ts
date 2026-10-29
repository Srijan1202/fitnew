/**
 * Beta 4.4 (E28): the sessions a runner built, kept with the account. The
 * phone keeps its own copy (it needs no connection to run one) and sends
 * each change here; a new phone, or a reinstall, reads them back. Addressed
 * by the phone's id, so a resent PUT changes nothing. Drizzle only; every
 * query is scoped to one user.
 */
import { and, count, desc, eq, sql } from 'drizzle-orm';
import { MAX_MY_WORKOUTS, type MyWorkout, type MyWorkoutList, type RunWorkout } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import { runningWorkouts } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';

type Db = DatabaseHandle['db'];
type Row = typeof runningWorkouts.$inferSelect;

const out = (r: Row): MyWorkout => ({
  id: r.clientId,
  name: r.name,
  steps: r.steps as MyWorkout['steps'],
  updatedAt: r.updatedAt.toISOString(),
});

export class MyWorkoutsService {
  constructor(private readonly db: Db) {}

  async list(userId: string): Promise<MyWorkoutList> {
    const rows = await this.db
      .select()
      .from(runningWorkouts)
      .where(eq(runningWorkouts.userId, userId))
      .orderBy(desc(runningWorkouts.updatedAt), desc(runningWorkouts.clientId))
      .limit(MAX_MY_WORKOUTS);
    return { workouts: rows.map(out) };
  }

  /** Created or replaced; a new one past [MAX_MY_WORKOUTS] is 409. */
  async put(userId: string, id: string, w: RunWorkout): Promise<{ created: boolean; body: MyWorkout }> {
    return this.db.transaction(async (tx) => {
      const [existing] = await tx
        .select({ id: runningWorkouts.clientId })
        .from(runningWorkouts)
        .where(and(eq(runningWorkouts.userId, userId), eq(runningWorkouts.clientId, id)))
        .limit(1);
      if (existing === undefined) {
        const [n] = await tx.select({ n: count() }).from(runningWorkouts).where(eq(runningWorkouts.userId, userId));
        if ((n?.n ?? 0) >= MAX_MY_WORKOUTS) {
          throw new AppError('CONFLICT', `You can keep ${MAX_MY_WORKOUTS} sessions. Delete one to add another.`);
        }
      }
      const [row] = await tx
        .insert(runningWorkouts)
        .values({ userId, clientId: id, name: w.name, steps: [...w.steps] })
        .onConflictDoUpdate({
          target: [runningWorkouts.userId, runningWorkouts.clientId],
          set: { name: w.name, steps: [...w.steps], updatedAt: sql`now()` },
        })
        .returning();
      return { created: existing === undefined, body: out(row!) };
    });
  }

  /** Deletes it; deleting one that is gone already is fine (a resent DELETE). */
  async remove(userId: string, id: string): Promise<void> {
    await this.db.delete(runningWorkouts).where(and(eq(runningWorkouts.userId, userId), eq(runningWorkouts.clientId, id)));
  }
}
