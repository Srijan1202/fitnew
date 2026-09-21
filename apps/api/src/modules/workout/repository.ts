/**
 * Session persistence (Phase 5). Drizzle only (§8.3); every query scoped
 * by a userId the caller obtained from a verified token.
 *
 * Idempotency is the database's: client ids are unique indexes and every
 * client-keyed insert is `ON CONFLICT DO NOTHING` followed by a re-read,
 * so a replayed request (offline queue, §33) is a no-op rather than a
 * read-then-write race.
 */
import { and, asc, desc, eq, inArray, isNull, lt, sql } from 'drizzle-orm';
import type { Equipment, MuscleGroup, SessionStatus, SetType } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import {
  exercisePrs,
  exercises,
  programs,
  sessionExercises,
  setLogs,
  users,
  workoutSessions,
  type SessionExerciseRow,
  type SetLogRow,
  type WorkoutSessionRow,
} from '../../db/schema.js';
import { musclesOf } from '../training/repository.js';

type Db = DatabaseHandle['db'];

/** A session exercise with its catalogue row. */
export interface SessionExerciseJoined extends SessionExerciseRow {
  readonly slug: string;
  readonly name: string;
  readonly movementPattern: string;
  readonly equipment: Equipment[];
  readonly difficulty: string;
  readonly defaultIncrementKg: string;
  readonly primaryMuscles: MuscleGroup[];
  readonly secondaryMuscles: MuscleGroup[];
}

export interface SessionBundle {
  readonly session: WorkoutSessionRow;
  /** Live (not removed) exercises in order. */
  readonly exercises: readonly SessionExerciseJoined[];
  /** Live (not deleted) sets, ordered by exercise then index. */
  readonly sets: readonly SetLogRow[];
  readonly prs: readonly { setLogId: string; prType: string; value: string; previous: string; reason: string; exerciseId: string }[];
}

export interface NewSession {
  readonly clientSessionId: string;
  readonly programId: string | null;
  readonly programDayId: string | null;
  readonly name: string;
  readonly startedAt: Date;
}

export interface NewSessionExercise {
  readonly clientExerciseId: string;
  readonly exerciseId: string;
  readonly plannedExerciseId: string | null;
  readonly orderIndex: number;
  readonly supersetGroup: number | null;
}

export interface NewSetLog {
  readonly clientSetId: string;
  readonly sessionExerciseId: string;
  readonly plannedSetId: string | null;
  readonly setIndex: number;
  readonly setType: SetType;
  readonly weightKg: string | null;
  readonly reps: number;
  readonly rir: number | null;
  readonly loggedAt: Date;
}

/** A completed session's working sets for one exercise, most recent first. */
export interface PriorWork {
  readonly sessionId: string;
  readonly completedAt: Date;
  readonly exerciseId: string;
  readonly sets: readonly SetLogRow[];
}

export class UniqueViolation extends Error {
  constructor(readonly constraint: string) {
    super(`unique violation: ${constraint}`);
  }
}

function asUnique(error: unknown): UniqueViolation | null {
  const e = error as { code?: string; constraint_name?: string; constraint?: string } | null;
  if (e !== null && typeof e === 'object' && e.code === '23505') {
    return new UniqueViolation(e.constraint_name ?? e.constraint ?? 'unknown');
  }
  return null;
}

export class WorkoutRepository {
  constructor(private readonly db: Db) {}

  async userTimezone(userId: string): Promise<string> {
    const [u] = await this.db.select({ tz: users.timezone }).from(users).where(eq(users.id, userId)).limit(1);
    return u?.tz ?? 'Asia/Kolkata';
  }

  /* ------------------------------------------------------------ reads -- */

  private async bundle(session: WorkoutSessionRow): Promise<SessionBundle> {
    const exerciseRows = await this.db
      .select({
        id: sessionExercises.id,
        sessionId: sessionExercises.sessionId,
        exerciseId: sessionExercises.exerciseId,
        plannedExerciseId: sessionExercises.plannedExerciseId,
        orderIndex: sessionExercises.orderIndex,
        supersetGroup: sessionExercises.supersetGroup,
        clientExerciseId: sessionExercises.clientExerciseId,
        removedAt: sessionExercises.removedAt,
        slug: exercises.slug,
        name: exercises.name,
        movementPattern: exercises.movementPattern,
        equipment: exercises.equipment,
        difficulty: exercises.difficulty,
        defaultIncrementKg: exercises.defaultIncrementKg,
        primaryMuscles: musclesOf('primary'),
        secondaryMuscles: musclesOf('secondary'),
      })
      .from(sessionExercises)
      .innerJoin(exercises, eq(exercises.id, sessionExercises.exerciseId))
      .where(and(eq(sessionExercises.sessionId, session.id), isNull(sessionExercises.removedAt)))
      .orderBy(asc(sessionExercises.orderIndex));
    const ids = exerciseRows.map((x) => x.id);
    const sets =
      ids.length === 0
        ? []
        : await this.db
            .select()
            .from(setLogs)
            .where(and(inArray(setLogs.sessionExerciseId, ids), isNull(setLogs.deletedAt)))
            .orderBy(asc(setLogs.sessionExerciseId), asc(setLogs.setIndex), asc(setLogs.loggedAt));
    const setIds = sets.map((s) => s.id);
    const prs =
      setIds.length === 0
        ? []
        : await this.db
            .select({
              setLogId: exercisePrs.setLogId,
              prType: exercisePrs.prType,
              value: exercisePrs.value,
              previous: exercisePrs.previous,
              reason: exercisePrs.reason,
              exerciseId: exercisePrs.exerciseId,
            })
            .from(exercisePrs)
            .where(inArray(exercisePrs.setLogId, setIds));
    return { session, exercises: exerciseRows as SessionExerciseJoined[], sets, prs };
  }

  async byId(userId: string, id: string): Promise<SessionBundle | null> {
    const [s] = await this.db
      .select()
      .from(workoutSessions)
      .where(and(eq(workoutSessions.id, id), eq(workoutSessions.userId, userId), isNull(workoutSessions.deletedAt)))
      .limit(1);
    return s === undefined ? null : this.bundle(s);
  }

  async byClientId(userId: string, clientSessionId: string): Promise<SessionBundle | null> {
    const [s] = await this.db
      .select()
      .from(workoutSessions)
      .where(and(eq(workoutSessions.clientSessionId, clientSessionId), eq(workoutSessions.userId, userId), isNull(workoutSessions.deletedAt)))
      .limit(1);
    return s === undefined ? null : this.bundle(s);
  }

  async active(userId: string): Promise<SessionBundle | null> {
    const [s] = await this.db
      .select()
      .from(workoutSessions)
      .where(and(eq(workoutSessions.userId, userId), eq(workoutSessions.status, 'active'), isNull(workoutSessions.deletedAt)))
      .limit(1);
    return s === undefined ? null : this.bundle(s);
  }

  /** History rows with aggregates, newest first, `before` exclusive. */
  async list(userId: string, opts: { before?: Date; limit: number; status?: SessionStatus }) {
    const where = and(
      eq(workoutSessions.userId, userId),
      isNull(workoutSessions.deletedAt),
      opts.status !== undefined ? eq(workoutSessions.status, opts.status) : sql`${workoutSessions.status} <> 'active'`,
      opts.before !== undefined ? lt(workoutSessions.startedAt, opts.before) : undefined,
    );
    return this.db
      .select({
        id: workoutSessions.id,
        status: workoutSessions.status,
        name: workoutSessions.name,
        startedAt: workoutSessions.startedAt,
        completedAt: workoutSessions.completedAt,
        durationSeconds: workoutSessions.durationSeconds,
        // Raw table names: drizzle leaves a single-table select's columns
        // unqualified, and "id" is ambiguous inside these joined subqueries.
        exerciseCount: sql<number>`(select count(*)::int from session_exercises se where se.session_id = workout_sessions.id and se.removed_at is null)`,
        workingSets: sql<number>`(select count(*)::int from set_logs sl join session_exercises se on se.id = sl.session_exercise_id
          where se.session_id = workout_sessions.id and se.removed_at is null and sl.deleted_at is null and sl.set_type = 'working')`,
        tonnageKg: sql<string>`(select coalesce(sum(sl.weight_kg * sl.reps), 0)::text from set_logs sl join session_exercises se on se.id = sl.session_exercise_id
          where se.session_id = workout_sessions.id and se.removed_at is null and sl.deleted_at is null and sl.set_type <> 'warmup')`,
        prCount: sql<number>`(select count(*)::int from exercise_prs p join set_logs sl on sl.id = p.set_log_id join session_exercises se on se.id = sl.session_exercise_id
          where se.session_id = workout_sessions.id)`,
      })
      .from(workoutSessions)
      .where(where)
      .orderBy(desc(workoutSessions.startedAt))
      .limit(opts.limit);
  }

  /**
   * Working sets of every COMPLETED session of this user for the given
   * exercises, grouped per (session, exercise), newest session first.
   * Records need all of history; "last time" needs the first entry.
   */
  async priorWork(userId: string, exerciseIds: readonly string[], excludeSessionId?: string): Promise<PriorWork[]> {
    if (exerciseIds.length === 0) return [];
    const rows = await this.db
      .select({
        sessionId: workoutSessions.id,
        completedAt: workoutSessions.completedAt,
        exerciseId: sessionExercises.exerciseId,
        set: setLogs,
      })
      .from(setLogs)
      .innerJoin(sessionExercises, eq(sessionExercises.id, setLogs.sessionExerciseId))
      .innerJoin(workoutSessions, eq(workoutSessions.id, sessionExercises.sessionId))
      .where(
        and(
          eq(workoutSessions.userId, userId),
          eq(workoutSessions.status, 'completed'),
          isNull(workoutSessions.deletedAt),
          isNull(sessionExercises.removedAt),
          isNull(setLogs.deletedAt),
          eq(setLogs.setType, 'working'),
          inArray(sessionExercises.exerciseId, [...exerciseIds]),
          excludeSessionId !== undefined ? sql`${workoutSessions.id} <> ${excludeSessionId}` : undefined,
        ),
      )
      .orderBy(desc(workoutSessions.completedAt), asc(setLogs.setIndex));
    const grouped = new Map<string, PriorWork & { sets: SetLogRow[] }>();
    for (const r of rows) {
      const key = `${r.sessionId}:${r.exerciseId}`;
      let g = grouped.get(key);
      if (g === undefined) {
        g = { sessionId: r.sessionId, completedAt: r.completedAt ?? new Date(0), exerciseId: r.exerciseId, sets: [] };
        grouped.set(key, g);
      }
      g.sets.push(r.set);
    }
    return [...grouped.values()];
  }

  /** `completed_at` of every completed session of a programme (for the mesocycle week). */
  async completedAtOfProgram(programId: string): Promise<Date[]> {
    const rows = await this.db
      .select({ at: workoutSessions.completedAt })
      .from(workoutSessions)
      .where(and(eq(workoutSessions.programId, programId), eq(workoutSessions.status, 'completed'), isNull(workoutSessions.deletedAt)));
    return rows.map((r) => r.at).filter((d): d is Date => d !== null);
  }

  /* ----------------------------------------------------------- writes -- */

  /**
   * Create the session with its seeded exercises. Returns the bundle, and
   * whether it was created now (false ⇒ an earlier call with this client id
   * already made it — the replay case).
   */
  async create(userId: string, next: NewSession, seeded: readonly NewSessionExercise[]): Promise<{ bundle: SessionBundle; created: boolean }> {
    const existing = await this.byClientId(userId, next.clientSessionId);
    if (existing !== null) return { bundle: existing, created: false };
    try {
      await this.db.transaction(async (tx) => {
        const [row] = await tx
          .insert(workoutSessions)
          .values({ userId, ...next })
          .onConflictDoNothing({ target: workoutSessions.clientSessionId })
          .returning({ id: workoutSessions.id });
        if (row === undefined) return; // a concurrent replay won; re-read below
        if (seeded.length > 0) {
          await tx.insert(sessionExercises).values(seeded.map((x) => ({ ...x, sessionId: row.id })));
        }
      });
    } catch (error) {
      const unique = asUnique(error);
      if (unique !== null) throw unique;
      throw error;
    }
    const bundle = await this.byClientId(userId, next.clientSessionId);
    if (bundle === null) throw new Error('session vanished after insert');
    return { bundle, created: true };
  }

  /** Insert sets; already-present client ids are skipped. Returns the live rows for all given client ids. */
  async insertSets(rows: readonly NewSetLog[]): Promise<SetLogRow[]> {
    if (rows.length > 0) {
      await this.db.transaction(async (tx) => {
        // One at a time: a batch may legitimately contain a replay next to a
        // new set, and DO NOTHING on the client id must not hide a genuine
        // position clash on another row.
        for (const r of rows) {
          await tx.insert(setLogs).values(r).onConflictDoNothing({ target: setLogs.clientSetId });
        }
      });
    }
    return this.db
      .select()
      .from(setLogs)
      .where(inArray(setLogs.clientSetId, rows.map((r) => r.clientSetId)))
      .orderBy(asc(setLogs.setIndex));
  }

  async updateSet(setId: string, patch: { setType?: SetType; weightKg?: string | null; reps?: number; rir?: number | null }): Promise<void> {
    await this.db.update(setLogs).set(patch).where(eq(setLogs.id, setId));
  }

  async softDeleteSet(setId: string): Promise<void> {
    await this.db.update(setLogs).set({ deletedAt: sql`now()` }).where(and(eq(setLogs.id, setId), isNull(setLogs.deletedAt)));
  }

  async addExercise(sessionId: string, x: NewSessionExercise): Promise<void> {
    await this.db
      .insert(sessionExercises)
      .values({ ...x, sessionId })
      .onConflictDoNothing({ target: sessionExercises.clientExerciseId });
  }

  async updateExercise(
    id: string,
    patch: { orderIndex?: number; supersetGroup?: number | null; exerciseId?: string; removed?: true },
  ): Promise<void> {
    const { removed, ...rest } = patch;
    const values = { ...rest, ...(removed === true ? { removedAt: sql`now()` } : {}) };
    if (Object.keys(values).length === 0) return;
    await this.db.update(sessionExercises).set(values).where(eq(sessionExercises.id, id));
  }

  async reorder(sessionId: string, orderedIds: readonly string[]): Promise<void> {
    await this.db.transaction(async (tx) => {
      for (const [i, id] of orderedIds.entries()) {
        await tx.update(sessionExercises).set({ orderIndex: i }).where(and(eq(sessionExercises.id, id), eq(sessionExercises.sessionId, sessionId)));
      }
    });
  }

  async finish(
    sessionId: string,
    patch: { status: 'completed' | 'abandoned'; completedAt: Date; durationSeconds: number; notes: string | null },
  ): Promise<void> {
    await this.db
      .update(workoutSessions)
      .set({ ...patch, updatedAt: sql`now()` })
      .where(and(eq(workoutSessions.id, sessionId), eq(workoutSessions.status, 'active')));
  }

  /** Records for a completed session, in one transaction with the is_pr flags. */
  async recordPrs(
    userId: string,
    achievedAt: Date,
    rows: readonly { exerciseId: string; prType: 'weight' | 'reps' | '1rm_est' | 'volume'; value: number; previous: number; reason: string; setLogId: string }[],
  ): Promise<void> {
    if (rows.length === 0) return;
    await this.db.transaction(async (tx) => {
      await tx
        .insert(exercisePrs)
        .values(rows.map((r) => ({ userId, exerciseId: r.exerciseId, prType: r.prType, value: r.value.toFixed(2), previous: r.previous.toFixed(2), reason: r.reason, achievedAt, setLogId: r.setLogId })))
        .onConflictDoNothing({ target: [exercisePrs.setLogId, exercisePrs.prType] });
      await tx.update(setLogs).set({ isPr: true }).where(inArray(setLogs.id, [...new Set(rows.map((r) => r.setLogId))]));
    });
  }

  async setMesocycleWeek(programId: string, week: number): Promise<void> {
    await this.db.update(programs).set({ mesocycleWeek: week, updatedAt: sql`now()` }).where(eq(programs.id, programId));
  }

  /** Used by tests and the summary: the raw exercise row for an id the user may add mid-session. */
  async exerciseExists(exerciseId: string): Promise<boolean> {
    const [x] = await this.db.select({ id: exercises.id }).from(exercises).where(eq(exercises.id, exerciseId)).limit(1);
    return x !== undefined;
  }
}
