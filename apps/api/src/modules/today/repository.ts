/**
 * TODAY persistence and the few facts only this module reads (Phase 11,
 * ADR-017). Drizzle only; every query is scoped to one user.
 */
import { and, asc, eq, gte, inArray, isNull, lte, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  bodyMetrics,
  exerciseContraindications,
  exerciseMuscles,
  exercisePrs,
  exercises,
  foodLogs,
  recommendationEvents,
  recommendations,
  sessionExercises,
  workoutSessions,
  type RecommendationEventRow,
  type RecommendationRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface NewRecommendation {
  readonly generatedFor: string;
  readonly kind: RecommendationRow['kind'];
  readonly subjectKey: string;
  readonly rank: number;
  readonly priority: number;
  readonly basis: RecommendationRow['basis'];
  readonly target: RecommendationRow['target'];
  readonly payload: unknown;
  readonly engineVersion: string;
  readonly inputDigest: string;
  readonly headline: string;
  readonly detail: string;
  readonly contentHash: string;
}

export interface NewRecommendationEvent {
  readonly recommendationId: string;
  readonly userId: string;
  readonly event: RecommendationEventRow['event'];
  readonly clientEventId: string;
  readonly occurredAt: Date;
  readonly receivedAt: Date;
}

export class TodayRepository {
  constructor(private readonly db: Db) {}

  /* ----------------------------------------------------------- facts -- */

  /** For each exercise, the body parts that contraindicate it (`exercise_contraindications`). */
  async contraindications(exerciseIds: readonly string[]): Promise<Map<string, string[]>> {
    const out = new Map<string, string[]>();
    if (exerciseIds.length === 0) return out;
    const rows = await this.db
      .select({ exerciseId: exerciseContraindications.exerciseId, bodyPart: exerciseContraindications.bodyPart })
      .from(exerciseContraindications)
      .where(inArray(exerciseContraindications.exerciseId, [...exerciseIds]));
    for (const r of rows) out.set(r.exerciseId, [...(out.get(r.exerciseId) ?? []), r.bodyPart]);
    return out;
  }

  /** Records achieved at or after `since`, earliest first (the caller keeps its local day). */
  async prsSince(userId: string, since: Date): Promise<{ id: string; exerciseName: string; prType: string; value: number; previous: number; achievedAt: Date }[]> {
    const rows = await this.db
      .select({
        id: exercisePrs.id,
        exerciseName: exercises.name,
        prType: exercisePrs.prType,
        value: exercisePrs.value,
        previous: exercisePrs.previous,
        achievedAt: exercisePrs.achievedAt,
      })
      .from(exercisePrs)
      .innerJoin(exercises, eq(exercises.id, exercisePrs.exerciseId))
      .where(and(eq(exercisePrs.userId, userId), gte(exercisePrs.achievedAt, since)))
      .orderBy(asc(exercisePrs.achievedAt), asc(exercisePrs.id));
    return rows.map((r) => ({ ...r, value: Number(r.value), previous: Number(r.previous) }));
  }

  /** The latest live weight reading's date, or null. */
  async latestWeighIn(userId: string): Promise<string | null> {
    const [row] = await this.db
      .select({ measuredOn: bodyMetrics.measuredOn })
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), isNull(bodyMetrics.deletedAt)))
      .orderBy(sql`${bodyMetrics.measuredOn} desc`)
      .limit(1);
    return row?.measuredOn ?? null;
  }

  /** (kind, subject) the user dismissed on `localDate` (D7: hidden for the rest of that day). */
  async dismissedOn(userId: string, localDate: string): Promise<{ kind: RecommendationRow['kind']; subjectKey: string }[]> {
    return this.db
      .selectDistinct({ kind: recommendations.kind, subjectKey: recommendations.subjectKey })
      .from(recommendationEvents)
      .innerJoin(recommendations, eq(recommendations.id, recommendationEvents.recommendationId))
      .where(
        and(
          eq(recommendationEvents.userId, userId),
          eq(recommendationEvents.event, 'dismissed'),
          eq(recommendations.generatedFor, localDate),
        ),
      );
  }

  /* ------------------------------------------------- recommendations -- */

  /**
   * Inserts each action unless its identity (user, day, kind, subject,
   * content hash) exists — rows are immutable (D4) — and returns the id of
   * every identity, new or existing, keyed by content hash.
   */
  async persist(userId: string, rows: readonly NewRecommendation[]): Promise<Map<string, string>> {
    if (rows.length === 0) return new Map();
    await this.db
      .insert(recommendations)
      .values(rows.map((r) => ({ userId, ...r })))
      .onConflictDoNothing({
        target: [recommendations.userId, recommendations.generatedFor, recommendations.kind, recommendations.subjectKey, recommendations.contentHash],
      });
    const found = await this.db
      .select({ id: recommendations.id, kind: recommendations.kind, subjectKey: recommendations.subjectKey, contentHash: recommendations.contentHash })
      .from(recommendations)
      .where(
        and(
          eq(recommendations.userId, userId),
          eq(recommendations.generatedFor, rows[0]!.generatedFor),
          inArray(recommendations.contentHash, rows.map((r) => r.contentHash)),
        ),
      );
    const out = new Map<string, string>();
    for (const r of rows) {
      const hit = found.find((f) => f.kind === r.kind && f.subjectKey === r.subjectKey && f.contentHash === r.contentHash);
      if (hit !== undefined) out.set(r.contentHash, hit.id);
    }
    return out;
  }

  /** The caller's own recommendation, or null (another user's is indistinguishable from none: D12). */
  async recommendation(userId: string, id: string): Promise<RecommendationRow | null> {
    const [row] = await this.db
      .select()
      .from(recommendations)
      .where(and(eq(recommendations.id, id), eq(recommendations.userId, userId)))
      .limit(1);
    return row ?? null;
  }

  /* ----------------------------------------------------------- events -- */

  async eventByClientId(userId: string, clientEventId: string): Promise<RecommendationEventRow | null> {
    const [row] = await this.db
      .select()
      .from(recommendationEvents)
      .where(and(eq(recommendationEvents.userId, userId), eq(recommendationEvents.clientEventId, clientEventId)))
      .limit(1);
    return row ?? null;
  }

  /**
   * Runs `fn` with the recommendation's events while holding its row lock,
   * so two events for one recommendation are decided one after the other
   * (`accepted` and `dismissed` can never both pass the transition check).
   * `insert` returns null when the (user, client id) already exists.
   */
  async withEvents<T>(
    recommendationId: string,
    fn: (recorded: readonly RecommendationEventRow[], insert: (row: NewRecommendationEvent) => Promise<RecommendationEventRow | null>) => Promise<T>,
  ): Promise<T> {
    return this.db.transaction(async (tx) => {
      await tx.select({ id: recommendations.id }).from(recommendations).where(eq(recommendations.id, recommendationId)).for('update');
      const recorded = await tx.select().from(recommendationEvents).where(eq(recommendationEvents.recommendationId, recommendationId));
      return fn(recorded, async (row) => {
        const [inserted] = await tx.insert(recommendationEvents).values(row).onConflictDoNothing().returning();
        return inserted ?? null;
      });
    });
  }

  /* --------------------------------------------- completion evidence -- */

  /** Sessions completed between two instants (the caller keeps its local day). */
  async completedSessions(userId: string, from: Date, to: Date): Promise<{ id: string; completedAt: Date }[]> {
    const rows = await this.db
      .select({ id: workoutSessions.id, completedAt: workoutSessions.completedAt })
      .from(workoutSessions)
      .where(
        and(
          eq(workoutSessions.userId, userId),
          eq(workoutSessions.status, 'completed'),
          isNull(workoutSessions.deletedAt),
          gte(workoutSessions.completedAt, from),
          lte(workoutSessions.completedAt, to),
        ),
      );
    return rows.flatMap((r) => (r.completedAt === null ? [] : [{ id: r.id, completedAt: r.completedAt }]));
  }

  /** Whether any of these sessions contains the exercise. */
  async sessionsHaveExercise(sessionIds: readonly string[], exerciseId: string): Promise<boolean> {
    if (sessionIds.length === 0) return false;
    const [row] = await this.db
      .select({ id: sessionExercises.id })
      .from(sessionExercises)
      .where(and(inArray(sessionExercises.sessionId, [...sessionIds]), eq(sessionExercises.exerciseId, exerciseId)))
      .limit(1);
    return row !== undefined;
  }

  /** Whether any of these sessions contains an exercise with the muscle as a primary. */
  async sessionsWorkMuscle(sessionIds: readonly string[], muscle: string): Promise<boolean> {
    if (sessionIds.length === 0) return false;
    const [row] = await this.db
      .select({ id: sessionExercises.id })
      .from(sessionExercises)
      .innerJoin(exerciseMuscles, eq(exerciseMuscles.exerciseId, sessionExercises.exerciseId))
      .where(
        and(
          inArray(sessionExercises.sessionId, [...sessionIds]),
          eq(exerciseMuscles.role, 'primary'),
          sql`${exerciseMuscles.muscleGroup}::text = ${muscle}`,
        ),
      )
      .limit(1);
    return row !== undefined;
  }

  /** Whether a live food log exists in that meal on that local date. */
  async foodLoggedIn(userId: string, localDate: string, slot: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: foodLogs.id })
      .from(foodLogs)
      .where(and(eq(foodLogs.userId, userId), eq(foodLogs.localDate, localDate), sql`${foodLogs.mealSlot}::text = ${slot}`, isNull(foodLogs.deletedAt)))
      .limit(1);
    return row !== undefined;
  }

  /** Whether a live weight reading is dated that local date. */
  async weighedOn(userId: string, localDate: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: bodyMetrics.id })
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), eq(bodyMetrics.measuredOn, localDate), isNull(bodyMetrics.deletedAt)))
      .limit(1);
    return row !== undefined;
  }
}
