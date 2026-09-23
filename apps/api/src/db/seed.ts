/**
 * Seed runner for the global reference data in database/seeds/ (§29): the
 * exercise library (Phase 3) and the food library (Phase 7, food-seed/load.ts).
 *
 * Exercises (Phase 3): the JSON is validated against the contract schema
 * first — a bad entry fails the whole run before a single row is touched —
 * then applied in ONE transaction, idempotent by slug: rows are upserted,
 * and the join tables for each seeded exercise are replaced wholesale so a
 * muscle, alternative or contraindication removed from the file is removed
 * from the database. Exercises not in the file are left alone (the admin
 * may have added them, Phase 16).
 *
 * Like migrations, this is a job run before a release, never on server boot.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { inArray, sql } from 'drizzle-orm';
import {
  PRIMARY_CONTRIBUTION,
  SECONDARY_CONTRIBUTION,
  exerciseSeedFileSchema,
  type ExerciseSeed,
} from '@fitos/contracts';

import { createDatabase } from './client.js';
import { seedFoods } from './food-seed/load.js';
import {
  exerciseAlternatives,
  exerciseContraindications,
  exerciseMuscles,
  exercises,
} from './schema.js';

/** database/seeds at the repo root (§29), resolved from this file. */
export const SEEDS_DIR = fileURLToPath(new URL('../../../../database/seeds/', import.meta.url));

export function readExerciseSeed(path = `${SEEDS_DIR}exercises.json`): readonly ExerciseSeed[] {
  const raw = JSON.parse(readFileSync(path, 'utf8')) as unknown;
  return exerciseSeedFileSchema.parse(raw);
}

export interface SeedResult {
  readonly exercises: number;
  readonly muscles: number;
  readonly alternatives: number;
  readonly contraindications: number;
}

export async function seedExercises(
  connectionString: string,
  entries: readonly ExerciseSeed[] = readExerciseSeed(),
): Promise<SeedResult> {
  const { db, client } = createDatabase(connectionString);
  try {
    return await db.transaction(async (tx) => {
      // 1. Upsert every exercise by slug. `updated_at` moves only on a
      //    real change of the row's own columns.
      const upserted = await tx
        .insert(exercises)
        .values(
          entries.map((e) => ({
            slug: e.slug,
            name: e.name,
            movementPattern: e.movementPattern,
            equipment: [...e.equipment],
            difficulty: e.difficulty,
            isUnilateral: e.isUnilateral,
            defaultIncrementKg: e.defaultIncrementKg.toFixed(2),
            instructions: [...e.instructions],
            videoUrl: e.videoUrl,
          })),
        )
        .onConflictDoUpdate({
          target: exercises.slug,
          set: {
            name: sql`excluded.name`,
            movementPattern: sql`excluded.movement_pattern`,
            equipment: sql`excluded.equipment`,
            difficulty: sql`excluded.difficulty`,
            isUnilateral: sql`excluded.is_unilateral`,
            defaultIncrementKg: sql`excluded.default_increment_kg`,
            instructions: sql`excluded.instructions`,
            videoUrl: sql`excluded.video_url`,
            updatedAt: sql`case when (${exercises.name}, ${exercises.movementPattern}, ${exercises.equipment}, ${exercises.difficulty}, ${exercises.isUnilateral}, ${exercises.defaultIncrementKg}, ${exercises.instructions}, ${exercises.videoUrl}) is distinct from (excluded.name, excluded.movement_pattern, excluded.equipment, excluded.difficulty, excluded.is_unilateral, excluded.default_increment_kg, excluded.instructions, excluded.video_url) then now() else ${exercises.updatedAt} end`,
          },
        })
        .returning({ id: exercises.id, slug: exercises.slug });

      const idBySlug = new Map(upserted.map((r) => [r.slug, r.id]));
      const ids = [...idBySlug.values()];

      // 2. Replace the join rows of every seeded exercise wholesale.
      await tx.delete(exerciseMuscles).where(inArray(exerciseMuscles.exerciseId, ids));
      await tx.delete(exerciseAlternatives).where(inArray(exerciseAlternatives.exerciseId, ids));
      await tx.delete(exerciseContraindications).where(inArray(exerciseContraindications.exerciseId, ids));

      const idOf = (slug: string): string => {
        const id = idBySlug.get(slug);
        if (id === undefined) throw new Error(`seed references unknown slug "${slug}"`);
        return id;
      };

      // `position` keeps the seed's order: the first primary is the muscle
      // the movement is FOR, and the generator reads it that way.
      const muscleRows = entries.flatMap((e) => [
        ...e.primaryMuscles.map((m, position) => ({
          exerciseId: idOf(e.slug),
          muscleGroup: m,
          role: 'primary' as const,
          contribution: PRIMARY_CONTRIBUTION.toFixed(2),
          position,
        })),
        ...e.secondaryMuscles.map((m, position) => ({
          exerciseId: idOf(e.slug),
          muscleGroup: m,
          role: 'secondary' as const,
          contribution: SECONDARY_CONTRIBUTION.toFixed(2),
          position,
        })),
      ]);
      const alternativeRows = entries.flatMap((e) =>
        e.alternatives.map((a) => ({
          exerciseId: idOf(e.slug),
          alternativeId: idOf(a.slug),
          reason: a.reason,
        })),
      );
      const contraRows = entries.flatMap((e) =>
        e.contraindications.map((bodyPart) => ({ exerciseId: idOf(e.slug), bodyPart })),
      );

      if (muscleRows.length > 0) await tx.insert(exerciseMuscles).values(muscleRows);
      if (alternativeRows.length > 0) await tx.insert(exerciseAlternatives).values(alternativeRows);
      if (contraRows.length > 0) await tx.insert(exerciseContraindications).values(contraRows);

      return {
        exercises: upserted.length,
        muscles: muscleRows.length,
        alternatives: alternativeRows.length,
        contraindications: contraRows.length,
      };
    });
  } finally {
    await client.end({ timeout: 5 });
  }
}

/* ------------------------------------------------------------------ CLI -- */

const isDirectRun =
  process.argv[1] !== undefined && import.meta.url === new URL(`file://${process.argv[1]}`).href;

if (isDirectRun) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined || url === '') {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  seedExercises(url)
    .then(async (r) => {
      console.log(
        `seeded ${r.exercises} exercises, ${r.muscles} muscle rows, ${r.alternatives} alternatives, ${r.contraindications} contraindications`,
      );
      // Phase 7 — the food library, from database/seeds/foods.json.
      const f = await seedFoods(url);
      console.log(`seeded ${f.foods} foods, ${f.nutritionRows} nutrition rows, ${f.aliases} aliases`);
    })
    .catch((error: unknown) => {
      console.error(error);
      process.exit(1);
    });
}
