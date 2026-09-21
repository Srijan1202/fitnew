/**
 * Read access to the global exercise library. Drizzle only (§8.3). There is
 * no write path here on purpose: rows come from the seed (`db/seed.ts`) and,
 * later, the admin (Phase 16).
 */
import { and, asc, eq, getTableColumns, ilike, inArray, sql, type SQL } from 'drizzle-orm';
import type { Equipment, MovementPattern, MuscleGroup } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import {
  exerciseAlternatives,
  exerciseContraindications,
  exerciseMuscles,
  exercises,
  type ExerciseAlternativeRow,
  type ExerciseContraindicationRow,
  type ExerciseMuscleRow,
  type ExerciseRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface ExerciseFilter {
  readonly q?: string | undefined;
  /** Equipment the user HAS. Included ⇔ every required item is in this set (plus bodyweight). */
  readonly equipment?: readonly Equipment[] | undefined;
  readonly muscle?: MuscleGroup | undefined;
  readonly pattern?: MovementPattern | undefined;
  readonly limit: number;
  readonly offset: number;
}

export interface ExerciseListRow extends ExerciseRow {
  readonly primaryMuscles: MuscleGroup[];
}

export interface ExerciseDetailRows {
  readonly exercise: ExerciseRow;
  readonly muscles: readonly ExerciseMuscleRow[];
  readonly alternatives: readonly (ExerciseAlternativeRow & {
    readonly slug: string;
    readonly name: string;
    readonly equipment: Equipment[];
  })[];
  readonly contraindications: readonly ExerciseContraindicationRow[];
}

/** Every exercise's primary muscles as one array column, for list rows. */
const primaryMusclesSql = sql<MuscleGroup[]>`coalesce((
  select array_agg(${exerciseMuscles.muscleGroup} order by ${exerciseMuscles.position}, ${exerciseMuscles.muscleGroup})
  from ${exerciseMuscles}
  where ${exerciseMuscles.exerciseId} = ${exercises.id} and ${exerciseMuscles.role} = 'primary'
), '{}')`;

export class ExerciseRepository {
  constructor(private readonly db: Db) {}

  private whereFor(f: ExerciseFilter): SQL | undefined {
    const clauses: SQL[] = [];
    if (f.q !== undefined) {
      // Trigram-indexed substring match on the name; slug catches hyphenated
      // spellings ("pull up" ~ "pull-up") without a second index.
      const needle = `%${f.q.replace(/[%_\\]/g, '\\$&')}%`;
      clauses.push(sql`(${ilike(exercises.name, needle)} or ${ilike(exercises.slug, needle.replace(/\s+/g, '-'))})`);
    }
    if (f.equipment !== undefined) {
      // Performable ⇔ required ⊆ available. Bodyweight is always available:
      // nobody has to declare owning their own body.
      const available = [...new Set<Equipment>([...f.equipment, 'bodyweight'])];
      // Each value is a bound parameter; drizzle would render a bare JS
      // array as a tuple, not a Postgres array.
      const bound = sql.join(available.map((q) => sql`${q}::equipment`), sql`, `);
      clauses.push(sql`${exercises.equipment} <@ array[${bound}]`);
    }
    if (f.pattern !== undefined) clauses.push(eq(exercises.movementPattern, f.pattern));
    if (f.muscle !== undefined) {
      clauses.push(
        sql`exists (select 1 from ${exerciseMuscles} where ${exerciseMuscles.exerciseId} = ${exercises.id} and ${exerciseMuscles.muscleGroup} = ${f.muscle}::muscle_group and ${exerciseMuscles.role} = 'primary')`,
      );
    }
    return clauses.length === 0 ? undefined : and(...clauses);
  }

  async list(f: ExerciseFilter): Promise<{ items: ExerciseListRow[]; total: number }> {
    const where = this.whereFor(f);
    const [items, counted] = await Promise.all([
      this.db
        .select({ ...getTableColumns(exercises), primaryMuscles: primaryMusclesSql })
        .from(exercises)
        .where(where)
        .orderBy(asc(exercises.name), asc(exercises.id))
        .limit(f.limit)
        .offset(f.offset),
      this.db.select({ n: sql<number>`count(*)::int` }).from(exercises).where(where),
    ]);
    return { items, total: counted[0]?.n ?? 0 };
  }

  async detail(id: string): Promise<ExerciseDetailRows | null> {
    const [exercise] = await this.db.select().from(exercises).where(eq(exercises.id, id)).limit(1);
    if (exercise === undefined) return null;

    const [muscles, alternatives, contraindications] = await Promise.all([
      this.db
        .select()
        .from(exerciseMuscles)
        .where(eq(exerciseMuscles.exerciseId, id))
        .orderBy(asc(exerciseMuscles.role), asc(exerciseMuscles.position), asc(exerciseMuscles.muscleGroup)),
      this.db
        .select({
          exerciseId: exerciseAlternatives.exerciseId,
          alternativeId: exerciseAlternatives.alternativeId,
          reason: exerciseAlternatives.reason,
          slug: exercises.slug,
          name: exercises.name,
          equipment: exercises.equipment,
        })
        .from(exerciseAlternatives)
        .innerJoin(exercises, eq(exercises.id, exerciseAlternatives.alternativeId))
        .where(eq(exerciseAlternatives.exerciseId, id))
        .orderBy(asc(exerciseAlternatives.reason), asc(exercises.name)),
      this.db
        .select()
        .from(exerciseContraindications)
        .where(eq(exerciseContraindications.exerciseId, id))
        .orderBy(asc(exerciseContraindications.bodyPart)),
    ]);
    return { exercise, muscles, alternatives, contraindications };
  }

  /** For tests and the seed: ids of the given slugs. */
  async idsBySlug(slugs: readonly string[]): Promise<Map<string, string>> {
    if (slugs.length === 0) return new Map();
    const rows = await this.db
      .select({ id: exercises.id, slug: exercises.slug })
      .from(exercises)
      .where(inArray(exercises.slug, [...slugs]));
    return new Map(rows.map((r) => [r.slug, r.id]));
  }
}
