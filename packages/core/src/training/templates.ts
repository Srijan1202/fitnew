/**
 * Professional programme templates (Phase 4 rework, owner decision
 * 2026-09-21): recognisable training structures people already know, as
 * DATA — days, session names, the muscles each session owns, the patterns
 * it must contain. No exercise lists: exercises are chosen deterministically
 * against the lifter's equipment, limitations and level by the same engine
 * that generates plans, so every constraint and every shortfall behaves
 * exactly as it does for a generated programme.
 *
 * None of these is claimed to be better than another. They are structures.
 */
import {
  FULL,
  LG,
  LO,
  PL,
  PU,
  UP,
  buildProgram,
  type Experience,
  type GeneratedProgram,
  type GeneratorInput,
  type MovementPattern,
  type MuscleGroup,
  type SessionTemplate,
} from './generator.js';

export interface ProgramTemplate {
  readonly slug: string;
  readonly name: string;
  readonly daysPerWeek: number;
  /** Who it is usually run by. `any` when the structure suits every level. */
  readonly level: Experience | 'any';
  /** Typical session length the structure is run at. */
  readonly approxMinutes: number;
  /** One neutral sentence: what it is, not why it is good. */
  readonly summary: string;
  readonly sessions: readonly SessionTemplate[];
}

/* ------------------------------------------------------- session pieces -- */

const session = (
  name: string,
  muscles: readonly MuscleGroup[],
  required: readonly MovementPattern[],
  directCoverage: readonly MuscleGroup[],
  excluded: readonly MovementPattern[] = [],
): SessionTemplate => ({ name, muscles, required, excluded, directCoverage });

/** Bro-split style single-focus days. */
const CHEST = session('Chest', ['chest'], ['horizontal-push'], ['chest'], ['horizontal-pull', 'vertical-pull']);
const BACK = session('Back', ['back'], ['horizontal-pull', 'vertical-pull'], ['back'], ['horizontal-push', 'vertical-push', 'core', 'carry']);
const SHOULDERS = session('Shoulders', ['shoulders'], ['vertical-push'], ['shoulders']);
const ARMS = session('Arms', ['biceps', 'triceps'], [], ['biceps', 'triceps']);
const CHEST_TRI = session('Chest & Triceps', ['chest', 'triceps'], ['horizontal-push'], ['chest', 'triceps'], ['horizontal-pull', 'vertical-pull', 'elbow-flexion']);
const BACK_BI = session('Back & Biceps', ['back', 'biceps'], ['horizontal-pull', 'vertical-pull'], ['back', 'biceps'], ['horizontal-push', 'vertical-push', 'elbow-extension', 'core', 'carry']);
const QUADS_HAMS = session('Quads & Hamstrings', ['quads', 'hamstrings'], ['squat', 'hinge'], ['quads', 'hamstrings']);
const SHOULDERS_ABS = session('Shoulders & Abs', ['shoulders', 'abs'], ['vertical-push'], ['shoulders', 'abs']);
// A glute day hinges and bridges; squats and lunges are quad-first and belong to the quad day.
const GLUTES_CALVES = session('Glutes & Calves', ['glutes', 'calves'], ['hinge'], ['glutes', 'calves'], ['squat', 'lunge']);

/** Push / pull in the two-day sense: legs split by push (quads) and pull (hinge). */
const PUSH_LEGS = session(
  'Push',
  ['chest', 'shoulders', 'triceps', 'quads', 'calves'],
  ['horizontal-push', 'vertical-push', 'squat'],
  ['chest', 'shoulders', 'triceps', 'quads', 'calves'],
  ['horizontal-pull', 'vertical-pull', 'elbow-flexion', 'hinge'],
);
const PULL_LEGS: SessionTemplate = {
  name: 'Pull',
  muscles: ['back', 'biceps', 'hamstrings', 'glutes', 'shoulders'],
  required: ['horizontal-pull', 'vertical-pull', 'hinge'],
  excluded: ['horizontal-push', 'vertical-push', 'elbow-extension', 'squat', 'chest-isolation'],
  directCoverage: ['back', 'biceps', 'hamstrings', 'glutes'],
  coverageHint: { shoulders: (ex) => ex.secondaryMuscles.includes('back') },
};

/* ------------------------------------------------------------- library -- */

export const PROGRAM_TEMPLATES: readonly ProgramTemplate[] = [
  {
    slug: 'push-pull-legs',
    name: 'Push / Pull / Legs',
    daysPerWeek: 3,
    level: 'any',
    approxMinutes: 60,
    summary: 'Three sessions: pressing, pulling, then legs. Each muscle group once a week.',
    sessions: [PU, PL, LG],
  },
  {
    slug: 'bro-split',
    name: 'Bro Split',
    daysPerWeek: 5,
    level: 'intermediate',
    approxMinutes: 50,
    summary: 'One body part per day — chest, back, shoulders, legs, arms — each trained once a week with several movements.',
    sessions: [CHEST, BACK, SHOULDERS, LG, ARMS],
  },
  {
    slug: 'upper-lower-6',
    name: 'Upper / Lower',
    daysPerWeek: 6,
    level: 'advanced',
    approxMinutes: 60,
    summary: 'Upper and lower body on alternating days, three times each per week.',
    sessions: [UP, LO, UP, LO, UP, LO],
  },
  {
    slug: 'full-body-2',
    name: 'Full Body',
    daysPerWeek: 2,
    level: 'beginner',
    approxMinutes: 60,
    summary: 'The whole body in each of two sessions, spaced across the week.',
    sessions: [FULL, FULL],
  },
  {
    slug: 'push-pull',
    name: 'Push / Pull',
    daysPerWeek: 4,
    level: 'any',
    approxMinutes: 60,
    summary: 'Two-way split: pushing movements with quads, pulling movements with hamstrings and glutes; each twice a week.',
    sessions: [PUSH_LEGS, PULL_LEGS, PUSH_LEGS, PULL_LEGS],
  },
  {
    slug: 'two-muscle',
    name: 'Two Muscle Groups Per Day',
    daysPerWeek: 5,
    level: 'intermediate',
    approxMinutes: 55,
    summary: 'Pairs across five days: chest & triceps, back & biceps, quads & hamstrings, shoulders & abs, glutes & calves.',
    sessions: [CHEST_TRI, BACK_BI, QUADS_HAMS, SHOULDERS_ABS, GLUTES_CALVES],
  },
  {
    slug: 'bodybuilding-5',
    name: '5-Day Bodybuilding Split',
    daysPerWeek: 5,
    level: 'intermediate',
    approxMinutes: 60,
    summary: 'Push, pull and legs, then an upper and a lower day, so every muscle is trained twice a week.',
    sessions: [PU, PL, LG, UP, LO],
  },
  {
    slug: 'full-body-3',
    name: '3-Day Full Body',
    daysPerWeek: 3,
    level: 'any',
    approxMinutes: 60,
    summary: 'The whole body three times a week, with the big lifts in every session.',
    sessions: [FULL, FULL, FULL],
  },
  {
    slug: 'upper-lower-4',
    name: '4-Day Upper / Lower',
    daysPerWeek: 4,
    level: 'any',
    approxMinutes: 60,
    summary: 'Upper body twice, lower body twice, with a rest day in the middle of the week.',
    sessions: [UP, LO, UP, LO],
  },
  {
    slug: 'push-pull-legs-6',
    name: '6-Day Push / Pull / Legs',
    daysPerWeek: 6,
    level: 'advanced',
    approxMinutes: 60,
    summary: 'Push, pull and legs run twice through the week; one rest day.',
    sessions: [PU, PL, LG, PU, PL, LG],
  },
];

export function findTemplate(slug: string): ProgramTemplate | undefined {
  return PROGRAM_TEMPLATES.find((t) => t.slug === slug);
}

/**
 * The template with real exercises for THIS lifter. Same engine as
 * generation: equipment, limitations, level, volume targets, time fitting,
 * direct coverage and shortfalls all apply. Deterministic.
 */
export function materializeTemplate(
  template: ProgramTemplate,
  input: Omit<GeneratorInput, 'daysPerWeek'>,
): GeneratedProgram {
  return buildProgram(
    {
      splitType: template.slug,
      sessions: template.sessions,
      opening: `${template.name}: ${template.daysPerWeek} days/week — ${template.summary}`,
    },
    input,
  );
}
