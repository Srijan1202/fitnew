/**
 * Professional templates (Phase 4 rework): every structure the owner asked
 * for exists, and materialising any of them for any lifter yields a valid
 * programme under the same rules as generation.
 */
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import {
  EQUIPMENT,
  MUSCLE_GROUPS,
  VOLUME_LANDMARKS,
  isPerformable,
  type CatalogueExercise,
  type Equipment,
  type Experience,
  type GeneratorInput,
  type MuscleGroup,
} from '../src/training/generator.js';
import { PROGRAM_TEMPLATES, findTemplate, materializeTemplate } from '../src/training/templates.js';

interface SeedEntry {
  slug: string; name: string; movementPattern: CatalogueExercise['movementPattern']; equipment: Equipment[];
  difficulty: Experience; isUnilateral: boolean; defaultIncrementKg: number; primaryMuscles: MuscleGroup[];
  secondaryMuscles: MuscleGroup[]; contraindications: CatalogueExercise['contraindications'][number][];
}
const seed = JSON.parse(readFileSync(new URL('../../../database/seeds/exercises.json', import.meta.url), 'utf8')) as SeedEntry[];
const catalogue: readonly CatalogueExercise[] = seed.map((e) => ({ ...e, id: `id-${e.slug}` }));
const bySlug = new Map(catalogue.map((e) => [e.slug, e]));

const FULL_GYM: readonly Equipment[] = EQUIPMENT;
const LEVELS: readonly Experience[] = ['beginner', 'intermediate', 'advanced'];

function input(overrides: Partial<Omit<GeneratorInput, 'daysPerWeek'>> = {}): Omit<GeneratorInput, 'daysPerWeek'> {
  return {
    goal: 'muscle-gain', experience: 'intermediate', availableEquipment: FULL_GYM, limitations: [],
    preferredSessionMinutes: 60, mesocycleWeek: 1, catalogue, ...overrides,
  };
}

describe('the library', () => {
  it('has every requested structure, with distinct slugs and 2–6 days', () => {
    const names = PROGRAM_TEMPLATES.map((t) => t.name);
    for (const wanted of [
      'Push / Pull / Legs', 'Bro Split', 'Upper / Lower', 'Full Body', 'Push / Pull',
      'Two Muscle Groups Per Day', '5-Day Bodybuilding Split', '3-Day Full Body', '4-Day Upper / Lower', '6-Day Push / Pull / Legs',
    ]) {
      expect(names, wanted).toContain(wanted);
    }
    expect(new Set(PROGRAM_TEMPLATES.map((t) => t.slug)).size).toBe(PROGRAM_TEMPLATES.length);
    for (const t of PROGRAM_TEMPLATES) {
      expect(t.daysPerWeek).toBeGreaterThanOrEqual(2);
      expect(t.daysPerWeek).toBeLessThanOrEqual(6);
      expect(t.sessions.length).toBe(t.daysPerWeek);
      expect(t.approxMinutes).toBeGreaterThan(0);
      expect(t.summary.length).toBeGreaterThan(20);
    }
  });

  it('makes no superiority claims', () => {
    const text = PROGRAM_TEMPLATES.map((t) => `${t.name} ${t.summary}`).join(' ').toLowerCase();
    for (const word of ['best', 'optimal', 'superior', 'scientifically', 'proven', 'ultimate']) {
      expect(text, word).not.toContain(word);
    }
  });

  it('every session owns at least one muscle and names what it must train directly', () => {
    for (const t of PROGRAM_TEMPLATES) for (const s of t.sessions) {
      expect(s.muscles.length, `${t.slug} ${s.name}`).toBeGreaterThan(0);
      expect(s.directCoverage.length, `${t.slug} ${s.name}`).toBeGreaterThan(0);
      for (const m of s.directCoverage) expect(s.muscles, `${t.slug} ${s.name} ${m}`).toContain(m);
    }
  });

  it('findTemplate resolves every slug and nothing else', () => {
    for (const t of PROGRAM_TEMPLATES) expect(findTemplate(t.slug)).toBe(t);
    expect(findTemplate('nope')).toBeUndefined();
  });
});

describe('materialising a template', () => {
  const cases = PROGRAM_TEMPLATES.flatMap((t) => LEVELS.map((l) => [t.slug, l] as const));

  it.each(cases)('%s for a %s: a valid week under the generator rules', (slug, level) => {
    const t = findTemplate(slug)!;
    const p = materializeTemplate(t, input({ experience: level }));
    expect(p.splitType).toBe(slug);
    expect(p.daysPerWeek).toBe(t.daysPerWeek);
    expect(p.days.length).toBe(7);
    const sessions = p.days.filter((d) => !d.isRest);
    expect(sessions.map((s) => s.sessionName)).toEqual(t.sessions.map((s) => s.name));
    for (const d of sessions) {
      expect(d.exercises.length, `${slug} ${d.sessionName}`).toBeGreaterThanOrEqual(3);
      expect(d.estimatedMinutes).toBeLessThanOrEqual(60 * 1.15);
      for (const x of d.exercises) {
        expect(x.reason.length).toBeGreaterThan(10);
        expect(bySlug.get(x.slug)!.primaryMuscles.some((m) => d.focus.includes(m)), `${slug} ${d.sessionName} ${x.slug}`).toBe(true);
      }
      expect(new Set(d.exercises.map((x) => x.slug)).size).toBe(d.exercises.length);
    }
    for (const m of MUSCLE_GROUPS) expect(p.weeklyVolume[m], m).toBeLessThanOrEqual(VOLUME_LANDMARKS[m].mrv);
    expect(p.rationale[0]).toContain(t.name);
  });

  it('direct coverage holds for every template session when a performable exercise exists', () => {
    for (const t of PROGRAM_TEMPLATES) {
      const p = materializeTemplate(t, input());
      const sessions = p.days.filter((d) => !d.isRest);
      sessions.forEach((d, i) => {
        const template = t.sessions[i]!;
        const direct = new Set(d.exercises.flatMap((x) => bySlug.get(x.slug)!.primaryMuscles));
        for (const m of template.directCoverage) {
          const exists = catalogue.some((e) => e.primaryMuscles.includes(m) && !template.excluded.includes(e.movementPattern));
          if (exists) expect(direct.has(m), `${t.slug} ${d.sessionName} ${m}`).toBe(true);
        }
      });
    }
  });

  it('a bro-split chest day is chest work, a back day is back work', () => {
    const p = materializeTemplate(findTemplate('bro-split')!, input());
    const chest = p.days.find((d) => d.sessionName === 'Chest')!;
    for (const x of chest.exercises) expect(bySlug.get(x.slug)!.primaryMuscles, x.slug).toContain('chest');
    expect(chest.exercises.length).toBeGreaterThanOrEqual(3);
    const back = p.days.find((d) => d.sessionName === 'Back')!;
    const patterns = new Set(back.exercises.map((x) => bySlug.get(x.slug)!.movementPattern));
    expect(patterns.has('horizontal-pull')).toBe(true);
    expect(patterns.has('vertical-pull')).toBe(true);
  });

  it.each([[['dumbbell']], [['resistance-band']], [[]]] as const)('equipment %j is respected for every template', (kit) => {
    for (const t of PROGRAM_TEMPLATES) {
      const p = materializeTemplate(t, input({ availableEquipment: kit as readonly Equipment[] }));
      for (const d of p.days) for (const x of d.exercises) {
        expect(isPerformable(bySlug.get(x.slug)!, kit as readonly Equipment[]), `${t.slug} ${x.slug}`).toBe(true);
      }
    }
  });

  it('bodyweight-only keeps the honest biceps shortfall on templates that own biceps', () => {
    const p = materializeTemplate(findTemplate('bro-split')!, input({ availableEquipment: [] }));
    expect(p.shortfalls.find((s) => s.muscle === 'biceps')?.reason).toBe('no-performable-exercise');
  });

  it('limitations exclude contraindicated lifts on templates too', () => {
    for (const t of PROGRAM_TEMPLATES) {
      const p = materializeTemplate(t, input({ limitations: ['knee'] }));
      for (const d of p.days) for (const x of d.exercises) expect(bySlug.get(x.slug)!.contraindications, `${t.slug} ${x.slug}`).not.toContain('knee');
    }
  });

  it('is deterministic', () => {
    const a = materializeTemplate(findTemplate('two-muscle')!, input());
    const b = materializeTemplate(findTemplate('two-muscle')!, input({ catalogue: [...catalogue].reverse() }));
    expect(b).toEqual(a);
  });
});
