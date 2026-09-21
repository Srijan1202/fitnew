/**
 * Programme generator (§12.2, §12.3, §31 Phase 4). Runs against the REAL
 * exercise seed — the same 151 rows the API serves — so a seed edit that
 * breaks generation fails here, not on a user.
 */
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import type { Goal } from '../src/nutrition/targets.js';
import {
  BODY_PARTS,
  EQUIPMENT,
  EXERCISE_COUNT_TARGET_MAX,
  FULL,
  GOAL_PARAMS,
  LG,
  LO,
  PL,
  PU,
  UP,
  MUSCLE_GROUPS,
  PATTERN_ORDER,
  VOLUME_LANDMARKS,
  generateProgram,
  isPerformable,
  selectSplit,
  weeklyTarget,
  type CatalogueExercise,
  type Equipment,
  type Experience,
  type GeneratedProgram,
  type GeneratorInput,
  type MuscleGroup,
  type SessionTemplate,
} from '../src/training/generator.js';

interface SeedEntry {
  slug: string;
  name: string;
  movementPattern: CatalogueExercise['movementPattern'];
  equipment: Equipment[];
  difficulty: Experience;
  isUnilateral: boolean;
  defaultIncrementKg: number;
  primaryMuscles: MuscleGroup[];
  secondaryMuscles: MuscleGroup[];
  contraindications: CatalogueExercise['contraindications'][number][];
}

const seed = JSON.parse(
  readFileSync(new URL('../../../database/seeds/exercises.json', import.meta.url), 'utf8'),
) as SeedEntry[];

const catalogue: readonly CatalogueExercise[] = seed.map((e) => ({
  id: `id-${e.slug}`,
  slug: e.slug,
  name: e.name,
  movementPattern: e.movementPattern,
  equipment: e.equipment,
  difficulty: e.difficulty,
  isUnilateral: e.isUnilateral,
  defaultIncrementKg: e.defaultIncrementKg,
  primaryMuscles: e.primaryMuscles,
  secondaryMuscles: e.secondaryMuscles,
  contraindications: e.contraindications,
}));

const GOALS: readonly Goal[] = ['muscle-gain', 'fat-loss', 'recomposition', 'strength', 'general', 'maintenance'];
const LEVELS: readonly Experience[] = ['beginner', 'intermediate', 'advanced'];
const DAYS = [2, 3, 4, 5, 6] as const;
const FULL_GYM: readonly Equipment[] = EQUIPMENT;

function input(overrides: Partial<GeneratorInput> = {}): GeneratorInput {
  return {
    goal: 'muscle-gain',
    experience: 'intermediate',
    daysPerWeek: 4,
    availableEquipment: FULL_GYM,
    limitations: [],
    preferredSessionMinutes: 60,
    mesocycleWeek: 1,
    catalogue,
    ...overrides,
  };
}

const bySlug = new Map(catalogue.map((e) => [e.slug, e]));
const isCompound = (slug: string): boolean =>
  ['squat', 'hinge', 'lunge', 'horizontal-push', 'vertical-push', 'horizontal-pull', 'vertical-pull'].includes(
    bySlug.get(slug)!.movementPattern,
  );

/** Weekly sets per muscle recomputed from the output, independent of the generator's own tally. */
function recount(p: GeneratedProgram): Record<MuscleGroup, number> {
  const v = Object.fromEntries(MUSCLE_GROUPS.map((m) => [m, 0])) as Record<MuscleGroup, number>;
  for (const d of p.days) {
    for (const x of d.exercises) {
      const ex = bySlug.get(x.slug)!;
      for (const m of ex.primaryMuscles) v[m] += x.setCount;
      for (const m of ex.secondaryMuscles) v[m] += x.setCount * 0.5;
    }
  }
  return v;
}

/* ----------------------------------------------------------- §12.2 table -- */

describe('split selection is the §12.2 table', () => {
  it.each([
    [2, 'beginner', 'full-body'], [2, 'intermediate', 'full-body'], [2, 'advanced', 'full-body'],
    [3, 'beginner', 'full-body'], [3, 'intermediate', 'full-body'], [3, 'advanced', 'push-pull-legs'],
    [4, 'beginner', 'upper-lower'], [4, 'intermediate', 'upper-lower'], [4, 'advanced', 'upper-lower'],
    [5, 'beginner', 'upper-lower-full'], [5, 'intermediate', 'ppl-upper-lower'], [5, 'advanced', 'ppl-upper-lower'],
    [6, 'beginner', 'upper-lower'], [6, 'intermediate', 'push-pull-legs'], [6, 'advanced', 'push-pull-legs'],
  ] as const)('%i days × %s → %s', (days, level, split) => {
    const s = selectSplit(days, level);
    expect(s.type).toBe(split);
    expect(s.sessions.length).toBe(days);
  });

  it('rejects days outside 2–6', () => {
    expect(() => selectSplit(1, 'beginner')).toThrow(RangeError);
    expect(() => selectSplit(7, 'advanced')).toThrow(RangeError);
  });
});

/* ----------------------------------------------------------- §12.3 ramp -- */

describe('weekly volume targets', () => {
  it('start at MEV and ramp ~10%/week toward MAV-high for progressing goals, never past it', () => {
    expect(weeklyTarget('chest', 'muscle-gain', 1)).toBe(VOLUME_LANDMARKS.chest.mev);
    expect(weeklyTarget('chest', 'muscle-gain', 2)).toBe(11);
    expect(weeklyTarget('chest', 'muscle-gain', 3)).toBe(12);
    expect(weeklyTarget('chest', 'muscle-gain', 40)).toBe(VOLUME_LANDMARKS.chest.mavHigh);
  });

  it('holds at MEV for fat loss and general, between MV and MEV for maintenance', () => {
    for (const w of [1, 5, 9]) {
      expect(weeklyTarget('back', 'fat-loss', w)).toBe(VOLUME_LANDMARKS.back.mev);
      expect(weeklyTarget('back', 'general', w)).toBe(VOLUME_LANDMARKS.back.mev);
      expect(weeklyTarget('back', 'maintenance', w)).toBe(8);
    }
  });

  it('never prescribes above MRV for any goal, week or muscle', () => {
    for (const g of GOALS) for (const m of MUSCLE_GROUPS) for (const w of [1, 6, 12, 52]) {
      expect(weeklyTarget(m, g, w), `${g} ${m} w${w}`).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mrv);
      expect(weeklyTarget(m, g, w)).toBeGreaterThanOrEqual(VOLUME_LANDMARKS[m].mv);
    }
  });
});

/* -------------------------------------------- every combination is valid -- */

describe('every (days × experience × goal) combination produces a valid programme', () => {
  const combos = DAYS.flatMap((d) => LEVELS.flatMap((l) => GOALS.map((g) => [d, l, g] as const)));

  it.each(combos)('%i days, %s, %s', (days, level, goal) => {
    const p = generateProgram(input({ daysPerWeek: days, experience: level, goal }));
    const params = GOAL_PARAMS[goal];

    // A full week, the right number of sessions, on the right days.
    expect(p.days.length).toBe(7);
    expect(p.days.map((d) => d.dayOfWeek)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    const sessions = p.days.filter((d) => !d.isRest);
    expect(sessions.length).toBe(days);
    expect(p.splitType).toBe(selectSplit(days, level).type);

    for (const d of sessions) {
      expect(d.exercises.length, `${d.sessionName} has exercises`).toBeGreaterThanOrEqual(3);
      expect(d.focus.length).toBeGreaterThan(0);
      // Compound-first ordering (§12.2).
      let seenIsolation = false;
      for (const x of d.exercises) {
        if (isCompound(x.slug)) expect(seenIsolation, `${d.sessionName}: ${x.slug} after an isolation`).toBe(false);
        else seenIsolation = true;
        // Goal parameters (§12.1) on every exercise, and a reason.
        expect(x.repMin).toBe(params.repMin);
        expect(x.repMax).toBe(params.repMax);
        expect(x.targetRir).toBe(params.targetRir[level]);
        expect(x.setCount).toBeGreaterThanOrEqual(2);
        expect(x.reason.length).toBeGreaterThan(10);
        expect(x.incrementKg).toBe(bySlug.get(x.slug)!.defaultIncrementKg);
        // Every exercise trains something this session owns.
        expect(bySlug.get(x.slug)!.primaryMuscles.some((m) => d.focus.includes(m)), x.slug).toBe(true);
      }
      expect(d.exercises.map((x) => x.orderIndex)).toEqual(d.exercises.map((_, i) => i));
      // No exercise twice in one session.
      expect(new Set(d.exercises.map((x) => x.slug)).size).toBe(d.exercises.length);
      // Duration: never more than +15% over preference.
      expect(d.estimatedMinutes, `${d.sessionName} minutes`).toBeLessThanOrEqual(60 * 1.15);
    }

    // Volume never above MRV, and the generator's tally matches an independent recount.
    const v = recount(p);
    for (const m of MUSCLE_GROUPS) {
      expect(v[m], m).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mrv);
      expect(p.weeklyVolume[m]).toBeCloseTo(v[m], 5);
    }
    // Every shortfall is explained; every muscle either meets MEV or is listed.
    for (const m of MUSCLE_GROUPS) {
      const floor = Math.min(p.weeklyTargets[m], VOLUME_LANDMARKS[m].mev);
      if (v[m] < floor) {
        const s = p.shortfalls.find((x) => x.muscle === m);
        expect(s, `${m} below MEV must be reported`).toBeDefined();
        expect(s!.detail.length).toBeGreaterThan(20);
      }
    }
    expect(p.rationale.length).toBeGreaterThanOrEqual(2);
  });

  it('is deterministic: the same input yields the same programme', () => {
    const a = generateProgram(input({ daysPerWeek: 5, experience: 'advanced', goal: 'recomposition' }));
    const b = generateProgram(input({ daysPerWeek: 5, experience: 'advanced', goal: 'recomposition' }));
    expect(b).toEqual(a);
    // Catalogue order must not matter either.
    const c = generateProgram(input({ daysPerWeek: 5, experience: 'advanced', goal: 'recomposition', catalogue: [...catalogue].reverse() }));
    expect(c).toEqual(a);
  });
});

/* --------------------------------------------------- volume lands MEV–MAV -- */

describe('volume lands within MEV–MAV when time allows', () => {
  it.each(LEVELS.flatMap((l) => [4, 5, 6].map((d) => [d, l] as const)))(
    'full gym, 75-minute sessions, %i days, %s, muscle gain: every muscle in [MEV, MAV-high]',
    (days, level) => {
      const p = generateProgram(input({ daysPerWeek: days, experience: level, goal: 'muscle-gain', preferredSessionMinutes: 75 }));
      const v = recount(p);
      for (const m of MUSCLE_GROUPS) {
        expect(v[m], `${m} ≥ MEV`).toBeGreaterThanOrEqual(VOLUME_LANDMARKS[m].mev);
        expect(v[m], `${m} ≤ MAV-high`).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mavHigh);
      }
      expect(p.shortfalls).toEqual([]);
    },
  );

  it('two 60-minute days cannot reach MEV everywhere, and says which muscles and why', () => {
    const p = generateProgram(input({ daysPerWeek: 2, experience: 'beginner', goal: 'muscle-gain' }));
    expect(p.shortfalls.length).toBeGreaterThan(0);
    for (const s of p.shortfalls) {
      expect(s.reason).toBe('session-time');
      expect(s.plannedSets).toBeLessThan(s.targetSets);
      expect(s.detail).toMatch(/add a day or minutes/);
    }
    // But nothing is ever over the time ceiling to compensate.
    for (const d of p.days.filter((x) => !x.isRest)) expect(d.estimatedMinutes).toBeLessThanOrEqual(69);
  });

  it('week 4 of a muscle-gain block plans more than week 1', () => {
    const w1 = generateProgram(input({ daysPerWeek: 5, goal: 'muscle-gain', preferredSessionMinutes: 90, mesocycleWeek: 1 }));
    const w4 = generateProgram(input({ daysPerWeek: 5, goal: 'muscle-gain', preferredSessionMinutes: 90, mesocycleWeek: 4 }));
    const total = (p: GeneratedProgram): number => Object.values(recount(p)).reduce((a, b) => a + b, 0);
    expect(total(w4)).toBeGreaterThan(total(w1));
    for (const m of MUSCLE_GROUPS) expect(w4.weeklyTargets[m]).toBeGreaterThanOrEqual(w1.weeklyTargets[m]);
  });
});

/* ------------------------------------------------------------- duration -- */

describe('session duration fits the preference', () => {
  it.each([45, 60])('progressing goal, full gym, 4 days: every session within ±15%% of %i minutes', (minutes) => {
    const p = generateProgram(input({ daysPerWeek: 4, goal: 'muscle-gain', preferredSessionMinutes: minutes }));
    for (const d of p.days.filter((x) => !x.isRest)) {
      expect(d.estimatedMinutes, `${d.sessionName}`).toBeGreaterThanOrEqual(minutes * 0.85);
      expect(d.estimatedMinutes, `${d.sessionName}`).toBeLessThanOrEqual(minutes * 1.15);
    }
  });

  it.each([75, 120])('more time (%i min) than week-1 volume can use is not filled past MAV-low, and the rationale says so', (minutes) => {
    const p = generateProgram(input({ daysPerWeek: 4, goal: 'muscle-gain', preferredSessionMinutes: minutes }));
    const v = recount(p);
    // Primaries stop at MAV-low; secondaries from the big lifts (abs and
    // back from squats/deadlifts) spill a little past it, never past MAV-high.
    for (const m of MUSCLE_GROUPS) {
      expect(v[m], m).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mavLow + 4);
      expect(v[m], m).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mavHigh);
    }
    for (const d of p.days.filter((x) => !x.isRest)) expect(d.estimatedMinutes).toBeLessThanOrEqual(minutes * 1.15);
    expect(p.rationale.join(' ')).toMatch(/capped at the low end of MAV/);
  });

  it('goals held at MEV are not padded to fill time, and the rationale says so', () => {
    const p = generateProgram(input({ daysPerWeek: 6, goal: 'fat-loss', preferredSessionMinutes: 90 }));
    const short = p.days.filter((d) => !d.isRest && d.estimatedMinutes < 90 * 0.85);
    expect(short.length).toBeGreaterThan(0);
    expect(p.rationale.join(' ')).toMatch(/held at MEV/);
    const v = recount(p);
    for (const m of MUSCLE_GROUPS) expect(v[m]).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mavHigh);
  });

  it('estimated minutes are 3.5 per working set', () => {
    const p = generateProgram(input());
    for (const d of p.days.filter((x) => !x.isRest)) {
      const sets = d.exercises.reduce((s, x) => s + x.setCount, 0);
      expect(d.estimatedMinutes).toBe(Math.round(sets * 3.5));
    }
  });
});

/* ---------------------------------------------------- equipment respected -- */

describe('equipment constraints are respected', () => {
  it.each([
    [['dumbbell']], [['barbell']], [['resistance-band']], [['machine', 'cable']], [['kettlebell']], [[]],
  ] as const)('with %j every planned exercise is performable', (kit) => {
    const available = kit as readonly Equipment[];
    for (const days of DAYS) {
      const p = generateProgram(input({ daysPerWeek: days, availableEquipment: available }));
      for (const d of p.days) for (const x of d.exercises) {
        expect(isPerformable(bySlug.get(x.slug)!, available), `${x.slug} with ${kit.join('+') || 'nothing'}`).toBe(true);
      }
    }
  });

  it('bodyweight only: biceps has no performable primary exercise, is reported as such, and still gets secondary work', () => {
    // Owner decision 2026-09-21: the seed keeps this gap; the generator handles it.
    const p = generateProgram(input({ daysPerWeek: 3, availableEquipment: [] }));
    const biceps = p.shortfalls.find((s) => s.muscle === 'biceps');
    expect(biceps).toBeDefined();
    expect(biceps!.reason).toBe('no-performable-exercise');
    expect(biceps!.detail).toMatch(/bodyweight only/);
    expect(biceps!.plannedSets).toBe(recount(p).biceps);
    for (const d of p.days) for (const x of d.exercises) expect(bySlug.get(x.slug)!.equipment).toEqual(['bodyweight']);
  });

  it('adding a pull-up bar closes the biceps gap', () => {
    const p = generateProgram(input({ daysPerWeek: 3, availableEquipment: ['pull-up-bar'] }));
    expect(p.shortfalls.find((s) => s.muscle === 'biceps')?.reason).not.toBe('no-performable-exercise');
    expect(p.days.some((d) => d.exercises.some((x) => x.slug === 'chin-up' || x.slug === 'pull-up'))).toBe(true);
  });
});

/* --------------------------------------------- limitations exclude lifts -- */

describe('limitations exclude contraindicated exercises', () => {
  it.each(BODY_PARTS.map((b) => [b] as const))('%s: no planned exercise is contraindicated for it', (part) => {
    for (const days of DAYS) {
      const p = generateProgram(input({ daysPerWeek: days, limitations: [part] }));
      for (const d of p.days) for (const x of d.exercises) {
        expect(bySlug.get(x.slug)!.contraindications, `${x.slug} with ${part}`).not.toContain(part);
      }
    }
  });

  it('a knee limitation drops the squat-pattern barbell lifts and says how many were excluded', () => {
    const p = generateProgram(input({ daysPerWeek: 4, limitations: ['knee'] }));
    const slugs = p.days.flatMap((d) => d.exercises.map((x) => x.slug));
    expect(slugs).not.toContain('barbell-back-squat');
    expect(slugs).not.toContain('leg-press');
    expect(p.rationale.join(' ')).toMatch(/excluded for your knee limitation/);
  });

  it('when a limitation removes every exercise for a muscle, the shortfall names the limitation, not time', () => {
    // Every calf raise in the seed is contraindicated for the ankle.
    const p = generateProgram(input({ daysPerWeek: 4, limitations: ['ankle'], preferredSessionMinutes: 90 }));
    const calves = p.shortfalls.find((s) => s.muscle === 'calves');
    expect(calves).toBeDefined();
    expect(calves!.reason).toBe('limitation');
    expect(calves!.detail).toMatch(/ankle/);
  });
});

/* ------------------------------------------------------------ programme -- */

describe('programme shape', () => {
  it('PPL twice a week does not repeat the first push day verbatim', () => {
    const p = generateProgram(input({ daysPerWeek: 6, experience: 'advanced' }));
    const pushes = p.days.filter((d) => d.sessionName === 'Push');
    expect(pushes.length).toBe(2);
    const a = pushes[0]!.exercises.map((x) => x.slug);
    const b = pushes[1]!.exercises.map((x) => x.slug);
    expect(a).not.toEqual(b);
  });

  it('beginners never get advanced lifts, and no more than seven exercises a session', () => {
    for (const days of DAYS) {
      const p = generateProgram(input({ daysPerWeek: days, experience: 'beginner' }));
      for (const d of p.days) {
        expect(d.exercises.length).toBeLessThanOrEqual(7);
        for (const x of d.exercises) expect(bySlug.get(x.slug)!.difficulty, x.slug).not.toBe('advanced');
      }
    }
  });

  it('pattern order constant covers every pattern exactly once', () => {
    expect([...PATTERN_ORDER].sort()).toEqual([...new Set(PATTERN_ORDER)].sort());
    expect(PATTERN_ORDER.length).toBe(15);
  });
});

/* --------------------------------------------- direct coverage and count -- */

const TEMPLATES: Readonly<Record<string, SessionTemplate>> = {
  'Full Body': FULL, Upper: UP, Lower: LO, Push: PU, Pull: PL, Legs: LG,
};

/** Is there ANY performable, allowed exercise with `m` as a primary mover? */
function poolHasPrimary(m: MuscleGroup, kit: readonly Equipment[], limitations: readonly string[], template: SessionTemplate): boolean {
  return catalogue.some(
    (e) =>
      e.primaryMuscles.includes(m) &&
      isPerformable(e, kit) &&
      !e.contraindications.some((c) => limitations.includes(c)) &&
      !template.excluded.includes(e.movementPattern),
  );
}

describe('direct muscle coverage (owner decision 2026-09-21)', () => {
  const combos = DAYS.flatMap((d) => LEVELS.flatMap((l) => GOALS.map((g) => [d, l, g] as const)));

  it.each(combos)('%i days, %s, %s: every muscle a session owns gets a PRIMARY exercise when one is performable', (days, level, goal) => {
    const p = generateProgram(input({ daysPerWeek: days, experience: level, goal }));
    for (const d of p.days.filter((x) => !x.isRest)) {
      const template = TEMPLATES[d.sessionName]!;
      const direct = new Set(d.exercises.flatMap((x) => bySlug.get(x.slug)!.primaryMuscles));
      for (const m of template.directCoverage) {
        if (!poolHasPrimary(m, FULL_GYM, [], template)) continue;
        expect(direct.has(m), `${d.sessionName}: ${m} has no direct exercise`).toBe(true);
      }
    }
  });

  it('pull days have a horizontal pull, a vertical pull, rear-delt work and a curl', () => {
    for (const [days, level] of [[6, 'intermediate'], [6, 'advanced'], [5, 'advanced'], [3, 'advanced']] as const) {
      const p = generateProgram(input({ daysPerWeek: days, experience: level }));
      for (const d of p.days.filter((x) => x.sessionName === 'Pull')) {
        const patterns = new Set(d.exercises.map((x) => bySlug.get(x.slug)!.movementPattern));
        expect(patterns.has('horizontal-pull'), `${days}d ${level} pull: horizontal`).toBe(true);
        expect(patterns.has('vertical-pull'), `${days}d ${level} pull: vertical`).toBe(true);
        const rearDelt = d.exercises.some((x) => {
          const e = bySlug.get(x.slug)!;
          return e.primaryMuscles.includes('shoulders') && e.secondaryMuscles.includes('back');
        });
        expect(rearDelt, `${days}d ${level} pull: rear delts`).toBe(true);
        expect(d.exercises.some((x) => bySlug.get(x.slug)!.primaryMuscles.includes('biceps')), 'curl').toBe(true);
      }
    }
  });

  it('push days train chest, shoulders and triceps directly; leg days quads, hamstrings, glutes and calves', () => {
    const p = generateProgram(input({ daysPerWeek: 6, experience: 'intermediate' }));
    for (const d of p.days.filter((x) => x.sessionName === 'Push')) {
      const direct = new Set(d.exercises.flatMap((x) => bySlug.get(x.slug)!.primaryMuscles));
      for (const m of ['chest', 'shoulders', 'triceps'] as const) expect(direct.has(m), m).toBe(true);
    }
    for (const d of p.days.filter((x) => x.sessionName === 'Legs')) {
      const direct = new Set(d.exercises.flatMap((x) => bySlug.get(x.slug)!.primaryMuscles));
      for (const m of ['quads', 'hamstrings', 'glutes', 'calves'] as const) expect(direct.has(m), m).toBe(true);
    }
  });

  it('coverage never invents an exercise: bodyweight-only biceps is still a shortfall, not a fake curl', () => {
    const p = generateProgram(input({ daysPerWeek: 4, availableEquipment: [] }));
    for (const d of p.days) for (const x of d.exercises) expect(bySlug.get(x.slug)!.equipment).toEqual(['bodyweight']);
    expect(p.shortfalls.find((s) => s.muscle === 'biceps')?.reason).toBe('no-performable-exercise');
  });

  it('coverage respects limitations: an ankle limitation leaves calves uncovered and says so', () => {
    const p = generateProgram(input({ daysPerWeek: 4, limitations: ['ankle'] }));
    for (const d of p.days) for (const x of d.exercises) expect(bySlug.get(x.slug)!.contraindications).not.toContain('ankle');
    expect(p.shortfalls.find((s) => s.muscle === 'calves')?.reason).toBe('limitation');
  });

  it('coverage survives time fitting: at 45 minutes the direct work is kept and sets are trimmed instead', () => {
    const p = generateProgram(input({ daysPerWeek: 4, experience: 'advanced', preferredSessionMinutes: 45 }));
    for (const d of p.days.filter((x) => !x.isRest)) {
      expect(d.estimatedMinutes).toBeLessThanOrEqual(45 * 1.15);
      const direct = new Set(d.exercises.flatMap((x) => bySlug.get(x.slug)!.primaryMuscles));
      for (const m of TEMPLATES[d.sessionName]!.directCoverage) expect(direct.has(m), `${d.sessionName} ${m}`).toBe(true);
    }
  });
});

describe('exercise count (owner decision 2026-09-21: >= min(5, floor(minutes/12)) when volume and time allow)', () => {
  it('no session in the 60-minute matrix stops at three exercises', () => {
    for (const days of DAYS) for (const level of LEVELS) for (const goal of GOALS) {
      const p = generateProgram(input({ daysPerWeek: days, experience: level, goal }));
      for (const d of p.days.filter((x) => !x.isRest)) {
        expect(d.exercises.length, `${days}d ${level} ${goal} ${d.sessionName}`).toBeGreaterThanOrEqual(4);
      }
    }
  });

  it('at 60 minutes every session reaches the count target, or every muscle it owns is already at its MAV-low share', () => {
    // "When volume allows": a session may stop short of five movements only
    // if adding one would push a muscle past its share of MAV-low — i.e.
    // the only thing left to add would be junk volume.
    const target = Math.min(EXERCISE_COUNT_TARGET_MAX, Math.floor(60 / 12));
    let short = 0;
    for (const days of DAYS) for (const level of LEVELS) for (const goal of GOALS) {
      const p = generateProgram(input({ daysPerWeek: days, experience: level, goal }));
      const sessions = p.days.filter((x) => !x.isRest);
      for (const d of sessions) {
        if (d.exercises.length >= target) continue;
        short += 1;
        const covering = (m: MuscleGroup): number => sessions.filter((s) => s.focus.includes(m)).length;
        const here = Object.fromEntries(MUSCLE_GROUPS.map((m) => [m, 0])) as Record<MuscleGroup, number>;
        for (const x of d.exercises) {
          const e = bySlug.get(x.slug)!;
          for (const m of e.primaryMuscles) here[m] += x.setCount;
          for (const m of e.secondaryMuscles) here[m] += x.setCount * 0.5;
        }
        // Either this session's share of MAV-low is met, or the WEEK already
        // reached MAV-low for the muscle (the weekly cap bound first).
        const weekly = recount(p);
        const capped = d.focus.every(
          (m) => here[m] + 1e-9 >= VOLUME_LANDMARKS[m].mavLow / covering(m) - 0.5 || weekly[m] >= VOLUME_LANDMARKS[m].mavLow,
        );
        const heldGoal = GOAL_PARAMS[goal].volumeBias !== 'mev-to-mav';
        expect(
          capped || heldGoal,
          `${days}d ${level} ${goal} ${d.sessionName}: ${d.exercises.length} exercises with room left`,
        ).toBe(true);
      }
    }
    // And it is not the common case.
    expect(short).toBeLessThan(DAYS.length * LEVELS.length * GOALS.length * 2);
  });

  it('six-day PPL is capped by week-1 volume, not by the count target, and the rationale says so', () => {
    // 10 chest sets a week over two push days cannot honestly become five
    // movements each without junk volume; the day is shorter and explained.
    const p = generateProgram(input({ daysPerWeek: 6, experience: 'intermediate', goal: 'muscle-gain' }));
    for (const d of p.days.filter((x) => !x.isRest)) expect(d.exercises.length).toBeGreaterThanOrEqual(4);
    const v = recount(p);
    for (const m of MUSCLE_GROUPS) expect(v[m], m).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mavHigh);
    expect(p.rationale.join(' ')).toMatch(/capped at the low end of MAV/);
  });

  it('a short session preference lowers the count target rather than the time ceiling', () => {
    const p = generateProgram(input({ daysPerWeek: 4, preferredSessionMinutes: 30 }));
    for (const d of p.days.filter((x) => !x.isRest)) {
      expect(d.estimatedMinutes).toBeLessThanOrEqual(30 * 1.15);
      expect(d.exercises.length).toBeGreaterThanOrEqual(2);
    }
  });

  it('count never exceeds the level cap: beginners <= 7, others <= 8', () => {
    for (const level of LEVELS) for (const days of DAYS) {
      const p = generateProgram(input({ daysPerWeek: days, experience: level, preferredSessionMinutes: 90 }));
      for (const d of p.days) expect(d.exercises.length).toBeLessThanOrEqual(level === 'beginner' ? 7 : 8);
    }
  });
});
