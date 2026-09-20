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
  programDays,
  programs,
  userLimitations,
  userProfiles,
  userGoals,
  type ExerciseRow,
  type PlannedExerciseRow,
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
}

export interface NewProgram {
  readonly name: string;
  readonly splitType: ProgramRow['splitType'];
  readonly daysPerWeek: number;
  readonly source: ProgramRow['source'];
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

export interface NewPlannedExercise {
  readonly exerciseId: string;
  readonly orderIndex: number;
  readonly setCount: number;
  readonly repMin: number;
  readonly repMax: number;
  readonly targetRir: number;
  readonly incrementKg: string;
  readonly reason: string | null;
}

const musclesOf = (role: 'primary' | 'secondary') => sql<MuscleGroup[]>`coalesce((
  select array_agg(${exerciseMuscles.muscleGroup} order by ${exerciseMuscles.muscleGroup})
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
    return { program, days, exercises: rows };
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
      if (exerciseRows.length > 0) await tx.insert(plannedExercises).values(exerciseRows);
      return program;
    }).then((program) => this.bundle(program));
  }

  /** Edit one day of the ACTIVE programme; returns null if the day is not the user's. */
  async patchDay(
    userId: string,
    dayId: string,
    patch: { sessionName?: string; exercises?: readonly NewPlannedExercise[] },
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
      if (patch.exercises !== undefined) {
        await tx.delete(plannedExercises).where(eq(plannedExercises.programDayId, dayId));
        if (patch.exercises.length > 0) {
          await tx.insert(plannedExercises).values(patch.exercises.map((x) => ({ ...x, programDayId: dayId })));
        }
        await tx.update(programDays).set({ isRest: patch.exercises.length === 0 }).where(eq(programDays.id, dayId));
      }
      await tx.update(programs).set({ updatedAt: sql`now()` }).where(eq(programs.id, owned.programId));
      const [program] = await tx.select().from(programs).where(eq(programs.id, owned.programId));
      return program ?? null;
    }).then((program) => (program === null ? null : this.bundle(program)));
  }
}
