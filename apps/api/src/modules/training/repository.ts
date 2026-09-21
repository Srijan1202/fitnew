/**
 * Programme persistence. Drizzle only (§8.3); every query scoped by a
 * userId the caller obtained from a verified token.
 */
import { and, asc, eq, inArray, isNull, sql } from 'drizzle-orm';
import type { Equipment, MuscleGroup } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import {
  exerciseContraindications,
  exerciseMuscles,
  exercises,
  plannedExercises,
  plannedSets,
  programDays,
  programs,
  userLimitations,
  userProfiles,
  userGoals,
  type ExerciseRow,
  type PlannedExerciseRow,
  type PlannedSetRow,
  type ProgramDayRow,
  type ProgramRow,
  type UserGoalRow,
  type UserProfileRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

/** Everything the generator needs about one exercise, from the library. */
export interface CatalogueRow extends ExerciseRow {
  readonly primaryMuscles: MuscleGroup[];
  readonly secondaryMuscles: MuscleGroup[];
  readonly contraindications: string[];
}

export interface PlannedExerciseJoined extends PlannedExerciseRow {
  readonly slug: string;
  readonly name: string;
  readonly movementPattern: ExerciseRow['movementPattern'];
  readonly equipment: Equipment[];
  readonly difficulty: ExerciseRow['difficulty'];
  readonly isUnilateral: boolean;
  readonly primaryMuscles: MuscleGroup[];
  readonly secondaryMuscles: MuscleGroup[];
}

export interface ProgramBundle {
  readonly program: ProgramRow;
  readonly days: readonly ProgramDayRow[];
  readonly exercises: readonly PlannedExerciseJoined[];
  readonly sets: readonly PlannedSetRow[];
}

export interface NewProgram {
  readonly name: string;
  readonly splitType: ProgramRow['splitType'];
  readonly daysPerWeek: number;
  readonly source: ProgramRow['source'];
  readonly templateSlug: string | null;
  readonly rationale: string[];
  readonly shortfalls: ProgramRow['shortfalls'];
  readonly days: readonly {
    readonly dayOfWeek: number;
    readonly sessionName: string;
    readonly focus: MuscleGroup[];
    readonly isRest: boolean;
    readonly exercises: readonly NewPlannedExercise[];
  }[];
}

export interface NewPlannedSet {
  readonly setIndex: number;
  readonly repsMin: number;
  readonly repsMax: number;
  /** numeric as text, or null: the generator never invents a load. */
  readonly weightKg: string | null;
  readonly rir: number;
}

export interface NewPlannedExercise {
  /** An existing planned_exercises row to update in place (day PATCH). Absent or unknown ⇒ insert. */
  readonly keepId?: string;
  readonly exerciseId: string;
  readonly orderIndex: number;
  readonly setCount: number;
  readonly repMin: number;
  readonly repMax: number;
  readonly targetRir: number;
  readonly incrementKg: string;
  readonly reason: string | null;
  /** Exactly setCount entries. */
  readonly sets: readonly NewPlannedSet[];
}

/** In seed order (0005): the first primary is what the generator treats the movement as being for. */
export const musclesOf = (role: 'primary' | 'secondary') => sql<MuscleGroup[]>`coalesce((
  select array_agg(${exerciseMuscles.muscleGroup} order by ${exerciseMuscles.position}, ${exerciseMuscles.muscleGroup})
  from ${exerciseMuscles}
  where ${exerciseMuscles.exerciseId} = ${exercises.id} and ${exerciseMuscles.role} = ${role}
), '{}')`;

const contraindicationsOf = sql<string[]>`coalesce((
  select array_agg(${exerciseContraindications.bodyPart} order by ${exerciseContraindications.bodyPart})
  from ${exerciseContraindications}
  where ${exerciseContraindications.exerciseId} = ${exercises.id}
), '{}')`;

export class TrainingRepository {
  constructor(private readonly db: Db) {}

  /* ------------------------------------------------------------ inputs -- */

  async profileInputs(userId: string): Promise<{
    profile: UserProfileRow | null;
    goal: UserGoalRow | null;
    limitations: string[];
  }> {
    const [profile, goal, limitations] = await Promise.all([
      this.db.select().from(userProfiles).where(eq(userProfiles.userId, userId)).then((r) => r[0] ?? null),
      this.db
        .select()
        .from(userGoals)
        .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)))
        .limit(1)
        .then((r) => r[0] ?? null),
      this.db
        .select({ bodyPart: userLimitations.bodyPart })
        .from(userLimitations)
        .where(and(eq(userLimitations.userId, userId), eq(userLimitations.active, true)))
        .then((rows) => rows.map((r) => r.bodyPart)),
    ]);
    return { profile, goal, limitations };
  }

  /** The whole library, with muscles and contraindications, for the generator. */
  async catalogue(): Promise<CatalogueRow[]> {
    const cols = exercises;
    return this.db
      .select({
        id: cols.id,
        slug: cols.slug,
        name: cols.name,
        movementPattern: cols.movementPattern,
        equipment: cols.equipment,
        difficulty: cols.difficulty,
        isUnilateral: cols.isUnilateral,
        defaultIncrementKg: cols.defaultIncrementKg,
        instructions: cols.instructions,
        videoUrl: cols.videoUrl,
        createdAt: cols.createdAt,
        updatedAt: cols.updatedAt,
        primaryMuscles: musclesOf('primary'),
        secondaryMuscles: musclesOf('secondary'),
        contraindications: contraindicationsOf,
      })
      .from(exercises)
      .orderBy(asc(exercises.slug));
  }

  /** Increment and existence for a set of exercise ids (custom programmes). */
  async exercisesById(ids: readonly string[]): Promise<Map<string, ExerciseRow>> {
    if (ids.length === 0) return new Map();
    const rows = await this.db.select().from(exercises).where(inArray(exercises.id, [...ids]));
    return new Map(rows.map((r) => [r.id, r]));
  }

  /* ---------------------------------------------------------- programme -- */

  async activeProgram(userId: string): Promise<ProgramBundle | null> {
    const [program] = await this.db
      .select()
      .from(programs)
      .where(and(eq(programs.userId, userId), eq(programs.active, true), isNull(programs.deletedAt)))
      .limit(1);
    if (program === undefined) return null;
    return this.bundle(program);
  }

  async programById(userId: string, id: string): Promise<ProgramBundle | null> {
    const [program] = await this.db
      .select()
      .from(programs)
      .where(and(eq(programs.id, id), eq(programs.userId, userId), isNull(programs.deletedAt)))
      .limit(1);
    if (program === undefined) return null;
    return this.bundle(program);
  }

  private async bundle(program: ProgramRow): Promise<ProgramBundle> {
    const days = await this.db
      .select()
      .from(programDays)
      .where(eq(programDays.programId, program.id))
      .orderBy(asc(programDays.dayOfWeek));
    const dayIds = days.map((d) => d.id);
    const rows =
      dayIds.length === 0
        ? []
        : await this.db
            .select({
              id: plannedExercises.id,
              programDayId: plannedExercises.programDayId,
              exerciseId: plannedExercises.exerciseId,
              orderIndex: plannedExercises.orderIndex,
              setCount: plannedExercises.setCount,
              repMin: plannedExercises.repMin,
              repMax: plannedExercises.repMax,
              targetRir: plannedExercises.targetRir,
              incrementKg: plannedExercises.incrementKg,
              reason: plannedExercises.reason,
              slug: exercises.slug,
              name: exercises.name,
              movementPattern: exercises.movementPattern,
              equipment: exercises.equipment,
              difficulty: exercises.difficulty,
              isUnilateral: exercises.isUnilateral,
              primaryMuscles: musclesOf('primary'),
              secondaryMuscles: musclesOf('secondary'),
            })
            .from(plannedExercises)
            .innerJoin(exercises, eq(exercises.id, plannedExercises.exerciseId))
            .where(inArray(plannedExercises.programDayId, dayIds))
            .orderBy(asc(plannedExercises.programDayId), asc(plannedExercises.orderIndex));
    const exerciseIds = rows.map((r) => r.id);
    const sets =
      exerciseIds.length === 0
        ? []
        : await this.db
            .select()
            .from(plannedSets)
            .where(inArray(plannedSets.plannedExerciseId, exerciseIds))
            .orderBy(asc(plannedSets.plannedExerciseId), asc(plannedSets.setIndex));
    return { program, days, exercises: rows, sets };
  }

  /** Insert planned exercises with their sets; returns nothing, rows are re-read by `bundle`. */
  private async insertPlanned(
    tx: Parameters<Parameters<Db['transaction']>[0]>[0],
    rows: readonly (NewPlannedExercise & { programDayId: string })[],
  ): Promise<void> {
    if (rows.length === 0) return;
    const inserted = await tx
      .insert(plannedExercises)
      .values(rows.map(({ sets: _sets, keepId: _keep, ...x }) => x))
      .returning({ id: plannedExercises.id, programDayId: plannedExercises.programDayId, orderIndex: plannedExercises.orderIndex });
    const idOf = new Map(inserted.map((r) => [`${r.programDayId}:${r.orderIndex}`, r.id]));
    const setRows = rows.flatMap((x) =>
      x.sets.map((set) => ({ ...set, plannedExerciseId: idOf.get(`${x.programDayId}:${x.orderIndex}`)! })),
    );
    if (setRows.length > 0) await tx.insert(plannedSets).values(setRows);
  }

  /**
   * Replace a day's exercises while KEEPING the rows the client says it is
   * continuing (`keepId`), so a planned exercise's id — and the ids of its
   * sets, by set index — survive every auto-save. Deleting and re-inserting
   * gave every card a new id after each PATCH, which collapsed whatever the
   * user had expanded (owner review). Rows not named are deleted; rows with
   * an unknown or absent id are inserted.
   */
  private async replaceDayExercises(
    tx: Parameters<Parameters<Db['transaction']>[0]>[0],
    dayId: string,
    next: readonly NewPlannedExercise[],
  ): Promise<void> {
    const existing = await tx
      .select({ id: plannedExercises.id })
      .from(plannedExercises)
      .where(eq(plannedExercises.programDayId, dayId));
    const existingIds = new Set(existing.map((r) => r.id));
    const claimed = new Set<string>();
    const kept: (NewPlannedExercise & { keepId: string })[] = [];
    const fresh: NewPlannedExercise[] = [];
    for (const x of next) {
      // A row may be continued once; a duplicate claim becomes an insert.
      if (x.keepId !== undefined && existingIds.has(x.keepId) && !claimed.has(x.keepId)) {
        claimed.add(x.keepId);
        kept.push({ ...x, keepId: x.keepId });
      } else {
        fresh.push(x);
      }
    }
    const gone = [...existingIds].filter((id) => !claimed.has(id));
    if (gone.length > 0) await tx.delete(plannedExercises).where(inArray(plannedExercises.id, gone));

    // (day, order_index) is unique: park the kept rows out of the way first
    // so a reorder cannot collide with a row that has not moved yet.
    for (const [i, x] of kept.entries()) {
      await tx.update(plannedExercises).set({ orderIndex: -(i + 1) }).where(eq(plannedExercises.id, x.keepId));
    }
    for (const x of kept) {
      await tx
        .update(plannedExercises)
        .set({
          exerciseId: x.exerciseId,
          orderIndex: x.orderIndex,
          setCount: x.setCount,
          repMin: x.repMin,
          repMax: x.repMax,
          targetRir: x.targetRir,
          incrementKg: x.incrementKg,
          reason: x.reason,
        })
        .where(eq(plannedExercises.id, x.keepId));
      // Sets: upsert by index so set ids are stable too; drop any past the new count.
      await tx.delete(plannedSets).where(and(eq(plannedSets.plannedExerciseId, x.keepId), sql`${plannedSets.setIndex} > ${x.sets.length}`));
      if (x.sets.length > 0) {
        await tx
          .insert(plannedSets)
          .values(x.sets.map((set) => ({ ...set, plannedExerciseId: x.keepId })))
          .onConflictDoUpdate({
            target: [plannedSets.plannedExerciseId, plannedSets.setIndex],
            set: {
              repsMin: sql`excluded.reps_min`,
              repsMax: sql`excluded.reps_max`,
              weightKg: sql`excluded.weight_kg`,
              rir: sql`excluded.rir`,
            },
          });
      }
    }
    await this.insertPlanned(tx, fresh.map((x) => ({ ...x, programDayId: dayId })));
  }

  /**
   * Deactivate whatever is active and insert the new programme with its
   * days and exercises, atomically. The partial unique index guarantees a
   * concurrent second call cannot leave two active.
   */
  async replaceActive(userId: string, next: NewProgram): Promise<ProgramBundle> {
    return this.db.transaction(async (tx) => {
      await tx
        .update(programs)
        .set({ active: false, updatedAt: sql`now()` })
        .where(and(eq(programs.userId, userId), eq(programs.active, true), isNull(programs.deletedAt)));
      const [program] = await tx
        .insert(programs)
        .values({
          userId,
          name: next.name,
          splitType: next.splitType,
          daysPerWeek: next.daysPerWeek,
          source: next.source,
          templateSlug: next.templateSlug,
          rationale: next.rationale,
          shortfalls: next.shortfalls,
        })
        .returning();
      if (program === undefined) throw new Error('program insert returned no row');

      const dayRows = await tx
        .insert(programDays)
        .values(
          next.days.map((d) => ({
            programId: program.id,
            dayOfWeek: d.dayOfWeek,
            sessionName: d.sessionName,
            focus: d.focus,
            isRest: d.isRest,
          })),
        )
        .returning();
      const dayIdByDow = new Map(dayRows.map((d) => [d.dayOfWeek, d.id]));
      const exerciseRows = next.days.flatMap((d) =>
        d.exercises.map((x) => ({ ...x, programDayId: dayIdByDow.get(d.dayOfWeek)! })),
      );
      await this.insertPlanned(tx, exerciseRows);
      return program;
    }).then((program) => this.bundle(program));
  }

  /** Rename the active programme; null when there is none. */
  async rename(userId: string, name: string): Promise<ProgramBundle | null> {
    const [program] = await this.db
      .update(programs)
      .set({ name, updatedAt: sql`now()` })
      .where(and(eq(programs.userId, userId), eq(programs.active, true), isNull(programs.deletedAt)))
      .returning();
    return program === undefined ? null : this.bundle(program);
  }

  /** Edit one day of the ACTIVE programme; returns null if the day is not the user's. */
  async patchDay(
    userId: string,
    dayId: string,
    patch: { sessionName?: string; focus?: readonly MuscleGroup[]; exercises?: readonly NewPlannedExercise[] },
  ): Promise<ProgramBundle | null> {
    return this.db.transaction(async (tx) => {
      const [owned] = await tx
        .select({ dayId: programDays.id, programId: programs.id })
        .from(programDays)
        .innerJoin(programs, eq(programs.id, programDays.programId))
        .where(and(eq(programDays.id, dayId), eq(programs.userId, userId), eq(programs.active, true), isNull(programs.deletedAt)))
        .limit(1);
      if (owned === undefined) return null;

      if (patch.sessionName !== undefined) {
        await tx.update(programDays).set({ sessionName: patch.sessionName }).where(eq(programDays.id, dayId));
      }
      if (patch.focus !== undefined) {
        await tx.update(programDays).set({ focus: [...patch.focus] }).where(eq(programDays.id, dayId));
      }
      if (patch.exercises !== undefined) {
        await this.replaceDayExercises(tx, dayId, patch.exercises);
        await tx.update(programDays).set({ isRest: patch.exercises.length === 0 }).where(eq(programDays.id, dayId));
      }
      await tx.update(programs).set({ updatedAt: sql`now()` }).where(eq(programs.id, owned.programId));
      const [program] = await tx.select().from(programs).where(eq(programs.id, owned.programId));
      return program ?? null;
    }).then((program) => (program === null ? null : this.bundle(program)));
  }
}
