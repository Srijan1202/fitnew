/**
 * Programmes: the bridge between the profile and packages/core's generator,
 * and the custom builder. This is the ONLY caller of `generateProgram`
 * (§7.3, §30). Rows → contract shapes here; no training rules live here.
 */
import {
  MINUTES_PER_WORKING_SET,
  MUSCLE_GROUPS,
  SECONDARY_CONTRIBUTION,
  generateProgram,
  type CatalogueExercise,
  type GeneratorInput,
  type MuscleGroup,
} from '@fitos/core/training/generator';
import type {
  CustomExercise,
  GenerateProgramRequest,
  PatchProgramDayRequest,
  PlannedExercise,
  Program,
  ProgramDay,
  PutProgramRequest,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { NewPlannedExercise, NewProgram, ProgramBundle, TrainingRepository } from './repository.js';

export const DEFAULT_SESSION_MINUTES = 60;
export const DEFAULT_DAYS_PER_WEEK = 3;

/* ---------------------------------------------------------- rows → wire -- */

function dayFrom(bundle: ProgramBundle, dayId: string): ProgramDay {
  const day = bundle.days.find((d) => d.id === dayId)!;
  const exercises: PlannedExercise[] = bundle.exercises
    .filter((x) => x.programDayId === dayId)
    .map((x) => ({
      id: x.id,
      exerciseId: x.exerciseId,
      slug: x.slug,
      name: x.name,
      movementPattern: x.movementPattern,
      equipment: x.equipment,
      difficulty: x.difficulty,
      isUnilateral: x.isUnilateral,
      primaryMuscles: x.primaryMuscles,
      orderIndex: x.orderIndex,
      setCount: x.setCount,
      repMin: x.repMin,
      repMax: x.repMax,
      targetRir: x.targetRir,
      incrementKg: Number(x.incrementKg),
      reason: x.reason,
    }));
  const sets = exercises.reduce((s, x) => s + x.setCount, 0);
  // A custom or edited day stores no focus; it is the union of what its
  // exercises train, derived here so an edit can never leave it stale.
  const focus =
    day.focus.length > 0 || day.isRest
      ? day.focus
      : MUSCLE_GROUPS.filter((m) => exercises.some((x) => x.primaryMuscles.includes(m)));
  return {
    id: day.id,
    dayOfWeek: day.dayOfWeek,
    sessionName: day.sessionName,
    focus,
    isRest: day.isRest,
    estimatedMinutes: Math.round(sets * MINUTES_PER_WORKING_SET),
    exercises,
  };
}

export function programFrom(bundle: ProgramBundle): Program {
  const volume = Object.fromEntries(MUSCLE_GROUPS.map((m) => [m, 0])) as Record<MuscleGroup, number>;
  for (const x of bundle.exercises) {
    for (const m of x.primaryMuscles) volume[m] += x.setCount;
    for (const m of x.secondaryMuscles) volume[m] += x.setCount * SECONDARY_CONTRIBUTION;
  }
  const p = bundle.program;
  return {
    id: p.id,
    name: p.name,
    splitType: p.splitType,
    daysPerWeek: p.daysPerWeek,
    source: p.source,
    mesocycleWeek: p.mesocycleWeek,
    active: p.active,
    createdAt: p.createdAt.toISOString(),
    days: [...bundle.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).map((d) => dayFrom(bundle, d.id)),
    weeklyVolume: volume,
    rationale: p.rationale,
    shortfalls: p.shortfalls as Program['shortfalls'],
  };
}

/* -------------------------------------------------------------- service -- */

export class TrainingService {
  constructor(private readonly repo: TrainingRepository) {}

  async getProgram(userId: string): Promise<Program> {
    const bundle = await this.repo.activeProgram(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'No active programme. Generate one or build your own.');
    return programFrom(bundle);
  }

  /**
   * Generate from the profile (§10.1). Missing profile facts are a 409 that
   * names them — the generator is never fed a guess.
   */
  async generate(userId: string, request: GenerateProgramRequest): Promise<Program> {
    const { profile, goal, limitations } = await this.repo.profileInputs(userId);
    const missing: string[] = [];
    if (goal === null) missing.push('goal');
    if (profile?.experienceLevel === null || profile?.experienceLevel === undefined) missing.push('experienceLevel');
    const daysPerWeek = request.daysPerWeek ?? profile?.trainingDaysPerWeek ?? null;
    if (daysPerWeek === null) missing.push('trainingDaysPerWeek');
    if (missing.length > 0) {
      throw new AppError(
        'CONFLICT',
        'Finish onboarding before generating a programme.',
        missing.map((path) => ({ path, issue: 'required' })),
      );
    }
    // 1 day/week is answerable in onboarding but the split table starts at 2 (§12.2).
    const days = Math.min(6, Math.max(2, daysPerWeek as number));

    const catalogue = await this.repo.catalogue();
    const input: GeneratorInput = {
      goal: goal!.goalType,
      experience: profile!.experienceLevel!,
      daysPerWeek: days,
      availableEquipment: profile!.equipment,
      limitations: limitations as GeneratorInput['limitations'],
      preferredSessionMinutes: request.preferredSessionMinutes ?? profile!.preferredSessionMinutes ?? DEFAULT_SESSION_MINUTES,
      mesocycleWeek: 1,
      catalogue: catalogue.map(
        (e): CatalogueExercise => ({
          id: e.id,
          slug: e.slug,
          name: e.name,
          movementPattern: e.movementPattern,
          equipment: e.equipment,
          difficulty: e.difficulty,
          isUnilateral: e.isUnilateral,
          defaultIncrementKg: Number(e.defaultIncrementKg),
          primaryMuscles: e.primaryMuscles,
          secondaryMuscles: e.secondaryMuscles,
          contraindications: e.contraindications as CatalogueExercise['contraindications'],
        }),
      ),
    };
    const generated = generateProgram(input);

    const next: NewProgram = {
      name: `${splitName(generated.splitType)} · ${days} days`,
      splitType: generated.splitType,
      daysPerWeek: days,
      source: 'generated',
      rationale: [...generated.rationale],
      shortfalls: generated.shortfalls.map((s) => ({ ...s })),
      days: generated.days.map((d) => ({
        dayOfWeek: d.dayOfWeek,
        sessionName: d.sessionName,
        focus: [...d.focus],
        isRest: d.isRest,
        exercises: d.exercises.map((x) => ({
          exerciseId: x.exerciseId,
          orderIndex: x.orderIndex,
          setCount: x.setCount,
          repMin: x.repMin,
          repMax: x.repMax,
          targetRir: x.targetRir,
          incrementKg: x.incrementKg.toFixed(2),
          reason: x.reason,
        })),
      })),
    };
    return programFrom(await this.repo.replaceActive(userId, next));
  }

  /** Replace the active programme with the user's own. */
  async putCustom(userId: string, body: PutProgramRequest): Promise<Program> {
    const ids = [...new Set(body.days.flatMap((d) => d.exercises.map((x) => x.exerciseId)))];
    const known = await this.repo.exercisesById(ids);
    const unknown = ids.filter((id) => !known.has(id));
    if (unknown.length > 0) {
      throw new AppError(
        'VALIDATION_FAILED',
        'Unknown exercise.',
        unknown.map((id) => ({ path: `exerciseId:${id}`, issue: 'no such exercise' })),
      );
    }
    const trainingDows = new Set(body.days.map((d) => d.dayOfWeek));
    const next: NewProgram = {
      name: body.name,
      splitType: 'custom',
      daysPerWeek: body.days.length,
      source: 'custom',
      rationale: [],
      shortfalls: [],
      days: [1, 2, 3, 4, 5, 6, 7].map((dow) => {
        const day = body.days.find((d) => d.dayOfWeek === dow);
        if (day === undefined || !trainingDows.has(dow)) {
          return { dayOfWeek: dow, sessionName: 'Rest', focus: [], isRest: true, exercises: [] };
        }
        return {
          dayOfWeek: dow,
          sessionName: day.sessionName,
          focus: [],
          isRest: false,
          exercises: toPlanned(day.exercises, known),
        };
      }),
    };
    return programFrom(await this.repo.replaceActive(userId, next));
  }

  async patchDay(userId: string, dayId: string, body: PatchProgramDayRequest): Promise<Program> {
    let exercises: NewPlannedExercise[] | undefined;
    if (body.exercises !== undefined) {
      const ids = [...new Set(body.exercises.map((x) => x.exerciseId))];
      const known = await this.repo.exercisesById(ids);
      const unknown = ids.filter((id) => !known.has(id));
      if (unknown.length > 0) {
        throw new AppError(
          'VALIDATION_FAILED',
          'Unknown exercise.',
          unknown.map((id) => ({ path: `exerciseId:${id}`, issue: 'no such exercise' })),
        );
      }
      exercises = toPlanned(body.exercises, known);
    }
    const bundle = await this.repo.patchDay(userId, dayId, {
      ...(body.sessionName !== undefined ? { sessionName: body.sessionName } : {}),
      ...(exercises !== undefined ? { exercises } : {}),
    });
    if (bundle === null) throw new AppError('NOT_FOUND', 'No such day on your active programme.');
    return programFrom(bundle);
  }
}

/* -------------------------------------------------------------- helpers -- */

type KnownExercises = Map<string, { defaultIncrementKg: string }>;

function toPlanned(list: readonly CustomExercise[], known: KnownExercises): NewPlannedExercise[] {
  return list.map((x, orderIndex) => ({
    exerciseId: x.exerciseId,
    orderIndex,
    setCount: x.setCount,
    repMin: x.repMin,
    repMax: x.repMax,
    targetRir: x.targetRir,
    incrementKg: (x.incrementKg ?? Number(known.get(x.exerciseId)!.defaultIncrementKg)).toFixed(2),
    // The user chose it; there is no generator reason to attach.
    reason: null,
  }));
}

function splitName(t: string): string {
  return t
    .split('-')
    .map((w) => (w === 'ppl' ? 'PPL' : w.charAt(0).toUpperCase() + w.slice(1)))
    .join(' / ');
}
