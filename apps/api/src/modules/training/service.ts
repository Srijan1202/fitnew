/**
 * Programmes: the bridge between the profile and packages/core's generator
 * and template library, and the custom builder. This is the ONLY caller of
 * `generateProgram` / `materializeTemplate` (§7.3, §30). Rows → contract
 * shapes here; no training rules live here.
 */
import {
  MINUTES_PER_WORKING_SET,
  MUSCLE_GROUPS,
  SECONDARY_CONTRIBUTION,
  generateProgram,
  trainingDays,
  type CatalogueExercise,
  type GeneratedProgram,
  type GeneratorInput,
  type MuscleGroup,
} from '@fitos/core/training/generator';
import {
  PROGRAM_TEMPLATES,
  findTemplate,
  materializeTemplate,
  type ProgramTemplate as CoreTemplate,
} from '@fitos/core/training/templates';
import type {
  CustomExercise,
  GenerateProgramRequest,
  PatchProgramDayRequest,
  PlannedExercise,
  PlannedSet,
  Program,
  ProgramDay,
  ProgramTemplate,
  PutProgramRequest,
  TemplatePreview,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { CatalogueRow, NewPlannedExercise, NewProgram, ProgramBundle, TrainingRepository } from './repository.js';

export const DEFAULT_SESSION_MINUTES = 60;

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
      sets: bundle.sets
        .filter((s) => s.plannedExerciseId === x.id)
        .map(
          (s): PlannedSet => ({
            setIndex: s.setIndex,
            repsMin: s.repsMin,
            repsMax: s.repsMax,
            weightKg: s.weightKg === null ? null : Number(s.weightKg),
            rir: s.rir,
          }),
        ),
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
    templateSlug: p.templateSlug,
    mesocycleWeek: p.mesocycleWeek,
    active: p.active,
    createdAt: p.createdAt.toISOString(),
    days: [...bundle.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).map((d) => dayFrom(bundle, d.id)),
    weeklyVolume: volume,
    rationale: p.rationale,
    shortfalls: p.shortfalls as Program['shortfalls'],
  };
}

/* ------------------------------------------------- generator → new rows -- */

/** Uniform sets from the prescription; no weight unless the user gave one — the generator never invents a load (§12.4). */
function uniformSets(setCount: number, repMin: number, repMax: number, rir: number, weightKg: string | null = null) {
  return Array.from({ length: setCount }, (_, i) => ({ setIndex: i + 1, repsMin: repMin, repsMax: repMax, weightKg, rir }));
}

function newProgramFrom(
  generated: GeneratedProgram,
  meta: Pick<NewProgram, 'name' | 'splitType' | 'source' | 'templateSlug'>,
): NewProgram {
  return {
    ...meta,
    daysPerWeek: generated.daysPerWeek,
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
        sets: uniformSets(x.setCount, x.repMin, x.repMax, x.targetRir),
      })),
    })),
  };
}

function templateFrom(t: CoreTemplate): ProgramTemplate {
  const weekdays = trainingDays(t.daysPerWeek);
  return {
    slug: t.slug,
    name: t.name,
    daysPerWeek: t.daysPerWeek,
    level: t.level,
    approxMinutes: t.approxMinutes,
    summary: t.summary,
    days: t.sessions.map((s, i) => ({ dayOfWeek: weekdays[i]!, sessionName: s.name, muscles: [...s.muscles] })),
  };
}

/* -------------------------------------------------------------- service -- */

interface GeneratorContext {
  readonly input: Omit<GeneratorInput, 'daysPerWeek'>;
  readonly daysPerWeek: number;
}

export class TrainingService {
  constructor(private readonly repo: TrainingRepository) {}

  async getProgram(userId: string): Promise<Program> {
    const bundle = await this.repo.activeProgram(userId);
    if (bundle === null) {
      throw new AppError('NOT_FOUND', 'No active programme. Generate one, pick a professional structure, or build your own.');
    }
    return programFrom(bundle);
  }

  /**
   * Everything the engine needs from the profile. Missing facts are a 409
   * that names them — the engine is never fed a guess.
   */
  private async context(userId: string, overrides: GenerateProgramRequest): Promise<GeneratorContext> {
    const { profile, goal, limitations } = await this.repo.profileInputs(userId);
    const missing: string[] = [];
    if (goal === null) missing.push('goal');
    if (profile?.experienceLevel === null || profile?.experienceLevel === undefined) missing.push('experienceLevel');
    const daysPerWeek = overrides.daysPerWeek ?? profile?.trainingDaysPerWeek ?? null;
    if (daysPerWeek === null) missing.push('trainingDaysPerWeek');
    if (missing.length > 0) {
      throw new AppError(
        'CONFLICT',
        'Finish onboarding before building a programme.',
        missing.map((path) => ({ path, issue: 'required' })),
      );
    }
    const catalogue = await this.repo.catalogue();
    return {
      // 1 day/week is answerable in onboarding but the split table starts at 2 (§12.2).
      daysPerWeek: Math.min(6, Math.max(2, daysPerWeek as number)),
      input: {
        goal: goal!.goalType,
        experience: profile!.experienceLevel!,
        availableEquipment: profile!.equipment,
        limitations: limitations as GeneratorInput['limitations'],
        preferredSessionMinutes: overrides.preferredSessionMinutes ?? profile!.preferredSessionMinutes ?? DEFAULT_SESSION_MINUTES,
        mesocycleWeek: 1,
        catalogue: catalogue.map(toCatalogueExercise),
      },
    };
  }

  /** Generate from the profile (§10.1); replaces the active programme. */
  async generate(userId: string, request: GenerateProgramRequest): Promise<Program> {
    const { input, daysPerWeek } = await this.context(userId, request);
    const generated = generateProgram({ ...input, daysPerWeek });
    const next = newProgramFrom(generated, {
      name: `${splitName(generated.splitType)} · ${daysPerWeek} days`,
      splitType: generated.splitType as NewProgram['splitType'],
      source: 'generated',
      templateSlug: null,
    });
    return programFrom(await this.repo.replaceActive(userId, next));
  }

  /* ----------------------------------------------------------- templates -- */

  listTemplates(): ProgramTemplate[] {
    return PROGRAM_TEMPLATES.map(templateFrom);
  }

  /** The template with exercises for THIS user; nothing is stored. */
  async previewTemplate(userId: string, slug: string, request: GenerateProgramRequest): Promise<TemplatePreview> {
    const template = findTemplate(slug);
    if (template === undefined) throw new AppError('NOT_FOUND', 'No such template.');
    const { input } = await this.context(userId, request);
    const generated = materializeTemplate(template, input);
    const byId = new Map(input.catalogue.map((c) => [c.id, c]));
    return {
      template: templateFrom(template),
      days: generated.days.map((d) => ({
        dayOfWeek: d.dayOfWeek,
        sessionName: d.sessionName,
        focus: [...d.focus],
        isRest: d.isRest,
        estimatedMinutes: d.estimatedMinutes,
        exercises: d.exercises.map((x) => {
          const ex = byId.get(x.exerciseId)!;
          return {
            exerciseId: x.exerciseId,
            slug: x.slug,
            name: x.name,
            movementPattern: ex.movementPattern,
            equipment: [...ex.equipment],
            difficulty: ex.difficulty,
            isUnilateral: ex.isUnilateral,
            primaryMuscles: [...ex.primaryMuscles],
            orderIndex: x.orderIndex,
            setCount: x.setCount,
            repMin: x.repMin,
            repMax: x.repMax,
            targetRir: x.targetRir,
            incrementKg: x.incrementKg,
            reason: x.reason,
            sets: uniformSets(x.setCount, x.repMin, x.repMax, x.targetRir).map((s) => ({ ...s, weightKg: null })),
          };
        }),
      })),
      weeklyVolume: generated.weeklyVolume,
      rationale: [...generated.rationale],
      shortfalls: generated.shortfalls.map((s) => ({ ...s })),
    };
  }

  /** Apply a template: the same materialisation, persisted as the active programme. */
  async applyTemplate(userId: string, slug: string, request: GenerateProgramRequest): Promise<Program> {
    const template = findTemplate(slug);
    if (template === undefined) throw new AppError('NOT_FOUND', 'No such template.');
    const { input } = await this.context(userId, request);
    const generated = materializeTemplate(template, input);
    const next = newProgramFrom(generated, {
      name: template.name,
      splitType: template.slug as NewProgram['splitType'],
      source: 'template',
      templateSlug: template.slug,
    });
    return programFrom(await this.repo.replaceActive(userId, next));
  }

  /* -------------------------------------------------------------- custom -- */

  /** Replace the active programme with the user's own. */
  async putCustom(userId: string, body: PutProgramRequest): Promise<Program> {
    const known = await this.knownExercises(body.days.flatMap((d) => d.exercises));
    const trainingDows = new Set(body.days.map((d) => d.dayOfWeek));
    const next: NewProgram = {
      name: body.name,
      splitType: 'custom',
      daysPerWeek: body.days.length,
      source: 'custom',
      templateSlug: null,
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
          focus: day.focus === undefined ? [] : [...day.focus],
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
      const known = await this.knownExercises(body.exercises);
      exercises = toPlanned(body.exercises, known);
    }
    const bundle = await this.repo.patchDay(userId, dayId, {
      ...(body.sessionName !== undefined ? { sessionName: body.sessionName } : {}),
      ...(body.focus !== undefined ? { focus: body.focus } : {}),
      ...(exercises !== undefined ? { exercises } : {}),
    });
    if (bundle === null) throw new AppError('NOT_FOUND', 'No such day on your active programme.');
    return programFrom(bundle);
  }

  async rename(userId: string, name: string): Promise<Program> {
    const bundle = await this.repo.rename(userId, name);
    if (bundle === null) throw new AppError('NOT_FOUND', 'No active programme.');
    return programFrom(bundle);
  }

  private async knownExercises(list: readonly CustomExercise[]): Promise<KnownExercises> {
    const ids = [...new Set(list.map((x) => x.exerciseId))];
    const known = await this.repo.exercisesById(ids);
    const unknown = ids.filter((id) => !known.has(id));
    if (unknown.length > 0) {
      throw new AppError(
        'VALIDATION_FAILED',
        'Unknown exercise.',
        unknown.map((id) => ({ path: `exerciseId:${id}`, issue: 'no such exercise' })),
      );
    }
    return known;
  }
}

/* -------------------------------------------------------------- helpers -- */

type KnownExercises = Map<string, { defaultIncrementKg: string }>;

function toCatalogueExercise(e: CatalogueRow): CatalogueExercise {
  return {
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
  };
}

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
    sets:
      x.sets !== undefined
        ? x.sets.map((s, i) => ({
            setIndex: i + 1,
            repsMin: s.repsMin,
            repsMax: s.repsMax,
            weightKg: s.weightKg === null ? null : s.weightKg.toFixed(2),
            rir: s.rir,
          }))
        : uniformSets(
            x.setCount,
            x.repMin,
            x.repMax,
            x.targetRir,
            x.startingWeightKg === undefined ? null : x.startingWeightKg.toFixed(2),
          ),
  }));
}

function splitName(t: string): string {
  return t
    .split('-')
    .map((w) => (w === 'ppl' ? 'PPL' : w.charAt(0).toUpperCase() + w.slice(1)))
    .join(' / ');
}
