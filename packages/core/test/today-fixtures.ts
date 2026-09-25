/**
 * Phase 11 TODAY fixtures: a base `UserModel`, a section-wise override
 * helper, and the 11 approved personas (MASTER-SPEC §26.2, owner D11) as
 * frozen user models. `low-readiness` waits for Phase 13 and is not faked.
 */
import type { UserModel } from '../src/recommend/engine.js';

type Over = {
  readonly [K in keyof UserModel]?: UserModel[K] extends readonly unknown[] ? UserModel[K] : UserModel[K] extends object ? Partial<UserModel[K]> : UserModel[K];
};

/** A training day at lunch time, protein behind, weighed today. */
export const BASE: UserModel = {
  localDate: '2026-09-24',
  hourOfDay: 13,
  goal: 'muscle-gain',
  training: {
    hasProgramme: true,
    sessionName: 'Pull — Back / Biceps',
    exerciseCount: 6,
    plannedSetCount: 17,
    completedToday: false,
    activeSessionOpen: false,
    deload: { state: 'none', trigger: null },
    increaseLoad: [],
    limitationSwaps: [],
    neglected: [],
    prsToday: [],
    nextSession: { name: 'Legs — Quads / Glutes', date: '2026-09-25' },
  },
  nutrition: {
    targets: { kcal: 2400, proteinG: 150 },
    eaten: { kcalLow: 650, kcalHigh: 820, proteinLow: 30, proteinHigh: 42 },
    loggedSlots: ['breakfast'],
    adjustment: null,
  },
  body: { weighedToday: true, daysSinceWeighIn: 0 },
  dismissedToday: [],
};

/** Override whole sections shallowly: `model({ training: { sessionName: null } })`. */
export function model(over: Over = {}, base: UserModel = BASE): UserModel {
  return {
    ...base,
    ...over,
    training: { ...base.training, ...(over.training ?? {}) },
    nutrition: { ...base.nutrition, ...(over.nutrition ?? {}) },
    body: { ...base.body, ...(over.body ?? {}) },
  } as UserModel;
}

const ID = {
  bench: '11111111-1111-4111-8111-111111111111',
  squat: '22222222-2222-4222-8222-222222222222',
  legPress: '33333333-3333-4333-8333-333333333333',
  lunge: '44444444-4444-4444-8444-444444444444',
  rdl: '55555555-5555-4555-8555-555555555555',
  pr1: '66666666-6666-4666-8666-666666666666',
  pr2: '77777777-7777-4777-8777-777777777777',
};
export const IDS = ID;

export const PERSONAS: Readonly<Record<string, UserModel>> = {
  // A new lifter's first block: session ahead, protein behind at lunch, a weigh-in due.
  'beginner-muscle-gain': model({
    goal: 'muscle-gain',
    hourOfDay: 13,
    training: { sessionName: 'Full Body A', exerciseCount: 6, plannedSetCount: 18 },
    nutrition: { targets: { kcal: 2600, proteinG: 130 }, eaten: { kcalLow: 450, kcalHigh: 600, proteinLow: 18, proteinHigh: 26 }, loggedSlots: ['breakfast'] },
    body: { weighedToday: false, daysSinceWeighIn: 3 },
  }),
  // Evening before dinner: session ahead with a load increase, protein on track, calories left.
  'intermediate-fat-loss': model({
    goal: 'fat-loss',
    hourOfDay: 18,
    training: {
      sessionName: 'Upper B', exerciseCount: 7, plannedSetCount: 21,
      increaseLoad: [{ exerciseId: ID.bench, exerciseName: 'Barbell Bench Press', weightKg: 62.5, repTarget: '6–8' }],
    },
    nutrition: { targets: { kcal: 1900, proteinG: 150 }, eaten: { kcalLow: 1100, kcalHigh: 1350, proteinLow: 115, proteinHigh: 130 }, loggedSlots: ['breakfast', 'lunch', 'snacks'] },
  }),
  // A deload offered on a heavy day: it outranks everything; a neglected muscle too.
  'advanced-strength': model({
    goal: 'strength',
    hourOfDay: 7,
    training: {
      sessionName: 'Heavy Lower', exerciseCount: 5, plannedSetCount: 16,
      deload: { state: 'offered', trigger: 'fatigue' },
      neglected: [{ muscle: 'hamstrings', daysSince: 7 }],
    },
    nutrition: { targets: { kcal: 3000, proteinG: 160 }, eaten: { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0 }, loggedSlots: [] },
  }),
  // Session done with two records; dinner left with protein just short.
  recomposition: model({
    goal: 'recomposition',
    hourOfDay: 20,
    training: {
      sessionName: 'Push A', completedToday: true,
      neglected: [{ muscle: 'calves', daysSince: null }],
      prsToday: [
        { prId: ID.pr1, exerciseName: 'Barbell Bench Press', prType: 'weight', value: 80, previous: 77.5 },
        { prId: ID.pr2, exerciseName: 'Overhead Press', prType: 'reps', value: 9, previous: 8 },
      ],
    },
    nutrition: { targets: { kcal: 2200, proteinG: 160 }, eaten: { kcalLow: 1500, kcalHigh: 1800, proteinLow: 100, proteinHigh: 118 }, loggedSlots: ['breakfast', 'lunch', 'snacks'] },
  }),
  // Eats at home (no mess): a rest day with protein behind at lunch.
  'non-vit-home': model({
    goal: 'general',
    hourOfDay: 12,
    training: { sessionName: null, exerciseCount: 0, plannedSetCount: 0, nextSession: { name: 'Lower A', date: '2026-09-25' } },
    nutrition: { targets: { kcal: 2300, proteinG: 120 }, eaten: { kcalLow: 400, kcalHigh: 520, proteinLow: 14, proteinHigh: 20 }, loggedSlots: ['breakfast'] },
    body: { weighedToday: false, daysSinceWeighIn: 1 },
  }),
  // A rest day: targets, the next session, a walk; a meal left; a weigh-in due.
  'rest-day': model({
    goal: 'muscle-gain',
    hourOfDay: 16,
    training: { sessionName: null, exerciseCount: 0, plannedSetCount: 0, nextSession: { name: 'Push A', date: '2026-09-25' } },
    nutrition: { targets: { kcal: 2800, proteinG: 140 }, eaten: { kcalLow: 1500, kcalHigh: 1750, proteinLow: 110, proteinHigh: 125 }, loggedSlots: ['breakfast', 'lunch'] },
    body: { weighedToday: false, daysSinceWeighIn: 4 },
  }),
  // A deload offered on a rest day: the deload shows; the rest day does not (§16.1).
  'deload-due': model({
    goal: 'muscle-gain',
    hourOfDay: 9,
    training: {
      sessionName: null, exerciseCount: 0, plannedSetCount: 0,
      deload: { state: 'offered', trigger: 'mrv' },
    },
    nutrition: { targets: { kcal: 2500, proteinG: 140 }, eaten: { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0 }, loggedSlots: [] },
  }),
  // 21:00, well under calories and protein: the last eat action before the 22:00 cut-off.
  'calorie-deficit': model({
    goal: 'fat-loss',
    hourOfDay: 21,
    training: { sessionName: 'Upper A', completedToday: true },
    nutrition: { targets: { kcal: 2000, proteinG: 140 }, eaten: { kcalLow: 900, kcalHigh: 1150, proteinLow: 60, proteinHigh: 78 }, loggedSlots: ['breakfast', 'lunch'] },
  }),
  // Over calories with protein met: nothing to eat; a weigh-in due.
  'calorie-surplus': model({
    goal: 'muscle-gain',
    hourOfDay: 19,
    training: { sessionName: 'Legs', completedToday: true },
    nutrition: { targets: { kcal: 2600, proteinG: 140 }, eaten: { kcalLow: 2700, kcalHigh: 3100, proteinLow: 150, proteinHigh: 170 }, loggedSlots: ['breakfast', 'lunch', 'snacks'] },
    body: { weighedToday: false, daysSinceWeighIn: 2 },
  }),
  // Just onboarded: targets, no programme, nothing logged, the onboarding weight today.
  'first-day-no-data': model({
    goal: 'general',
    hourOfDay: 10,
    training: {
      hasProgramme: false, sessionName: null, exerciseCount: 0, plannedSetCount: 0, nextSession: null,
    },
    nutrition: { targets: { kcal: 2200, proteinG: 110 }, eaten: { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0 }, loggedSlots: [] },
    body: { weighedToday: true, daysSinceWeighIn: 0 },
  }),
  // A knee limitation: one planned lift has a safer swap (it fires), one has none (it does not).
  'injured-limitation': model({
    goal: 'muscle-gain',
    hourOfDay: 17,
    training: {
      sessionName: 'Lower A', exerciseCount: 6, plannedSetCount: 20,
      limitationSwaps: [
        { exerciseId: ID.squat, exerciseName: 'Barbell Back Squat', bodyParts: ['knee'], alternativeId: ID.legPress, alternativeName: 'Leg Press' },
        { exerciseId: ID.lunge, exerciseName: 'Walking Lunge', bodyParts: ['knee'], alternativeId: null, alternativeName: null },
      ],
      increaseLoad: [{ exerciseId: ID.rdl, exerciseName: 'Romanian Deadlift', weightKg: 70, repTarget: '8–10' }],
    },
    nutrition: { targets: { kcal: 2700, proteinG: 140 }, eaten: { kcalLow: 1200, kcalHigh: 1450, proteinLow: 95, proteinHigh: 112 }, loggedSlots: ['breakfast', 'lunch'] },
  }),
};
