/**
 * Exercise library: rows → contract shapes. No rules live here beyond the
 * mapping; the performability rule is a SQL predicate in the repository and
 * is documented on `exerciseListQuerySchema`.
 */
import type {
  ExerciseDetail,
  ExerciseListQuery,
  ExerciseListResponse,
  ExerciseSummary,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { ExerciseDetailRows, ExerciseListRow, ExerciseRepository } from './repository.js';

export function summaryFrom(row: ExerciseListRow): ExerciseSummary {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    movementPattern: row.movementPattern,
    equipment: row.equipment,
    difficulty: row.difficulty,
    isUnilateral: row.isUnilateral,
    primaryMuscles: row.primaryMuscles,
  };
}

export function detailFrom(rows: ExerciseDetailRows): ExerciseDetail {
  const { exercise, muscles, alternatives, contraindications } = rows;
  return {
    ...summaryFrom({
      ...exercise,
      primaryMuscles: muscles.filter((m) => m.role === 'primary').map((m) => m.muscleGroup),
    }),
    defaultIncrementKg: Number(exercise.defaultIncrementKg),
    instructions: exercise.instructions,
    videoUrl: exercise.videoUrl,
    muscles: muscles.map((m) => ({
      muscleGroup: m.muscleGroup,
      role: m.role,
      contribution: Number(m.contribution),
    })),
    alternatives: alternatives.map((a) => ({
      id: a.alternativeId,
      slug: a.slug,
      name: a.name,
      reason: a.reason,
      equipment: a.equipment,
    })),
    contraindications: contraindications.map((c) => c.bodyPart),
  };
}

export class ExerciseService {
  constructor(private readonly repo: ExerciseRepository) {}

  async list(query: ExerciseListQuery): Promise<ExerciseListResponse> {
    const { items, total } = await this.repo.list(query);
    return { items: items.map(summaryFrom), total, limit: query.limit, offset: query.offset };
  }

  async detail(id: string): Promise<ExerciseDetail> {
    const rows = await this.repo.detail(id);
    if (rows === null) throw new AppError('NOT_FOUND', 'No exercise with that id.');
    return detailFrom(rows);
  }
}
