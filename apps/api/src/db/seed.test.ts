/**
 * Seed integrity (§31 Phase 3): the JSON file itself, no database. These
 * are the rules the generator (Phase 4) and substitution (§12.6) rely on;
 * a seed edit that breaks one fails here before it reaches a migration.
 */
import { describe, expect, it } from 'vitest';
import { COMPOUND_PATTERNS, MOVEMENT_PATTERNS, MUSCLE_GROUPS, EQUIPMENT } from '@fitos/contracts';

import { readExerciseSeed } from './seed.js';

const seed = readExerciseSeed();
const bySlug = new Map(seed.map((e) => [e.slug, e]));

describe('exercises.json', () => {
  it('has at least 120 exercises (acceptance) with unique slugs', () => {
    expect(seed.length).toBeGreaterThanOrEqual(120);
    expect(bySlug.size).toBe(seed.length);
  });

  it('every exercise has ≥1 primary muscle and ≥1 equipment', () => {
    for (const e of seed) {
      expect(e.primaryMuscles.length, e.slug).toBeGreaterThan(0);
      expect(e.equipment.length, e.slug).toBeGreaterThan(0);
    }
  });

  it('no muscle is both primary and secondary for the same exercise', () => {
    for (const e of seed) {
      const both = e.primaryMuscles.filter((m) => e.secondaryMuscles.includes(m));
      expect(both, e.slug).toEqual([]);
      expect(new Set(e.primaryMuscles).size).toBe(e.primaryMuscles.length);
      expect(new Set(e.secondaryMuscles).size).toBe(e.secondaryMuscles.length);
    }
  });

  it('every alternative references an existing, different exercise', () => {
    for (const e of seed) {
      for (const a of e.alternatives) {
        expect(bySlug.has(a.slug), `${e.slug} -> ${a.slug}`).toBe(true);
        expect(a.slug).not.toBe(e.slug);
      }
      const keys = e.alternatives.map((a) => `${a.slug}:${a.reason}`);
      expect(new Set(keys).size, e.slug).toBe(keys.length);
    }
  });

  it('every alternative shares the movement pattern and a primary muscle (§12.6)', () => {
    for (const e of seed) {
      for (const a of e.alternatives) {
        const other = bySlug.get(a.slug)!;
        expect(other.movementPattern, `${e.slug} -> ${a.slug}`).toBe(e.movementPattern);
        const shared = e.primaryMuscles.filter((m) => other.primaryMuscles.includes(m));
        expect(shared.length, `${e.slug} -> ${a.slug}`).toBeGreaterThan(0);
      }
    }
  });

  it('equipment and preference alternatives are symmetric; injury links are one-way', () => {
    for (const e of seed) {
      for (const a of e.alternatives) {
        const back = bySlug.get(a.slug)!.alternatives.some((b) => b.slug === e.slug && b.reason === a.reason);
        if (a.reason === 'injury') {
          // Pointing back "avoid this, do that" from the gentler exercise
          // would send an injured user to the harder one.
          expect(back, `${e.slug} <-> ${a.slug} (injury)`).toBe(false);
        } else {
          expect(back, `${e.slug} <-> ${a.slug} (${a.reason})`).toBe(true);
        }
      }
    }
  });

  it('an equipment alternative needs different equipment, otherwise it is not one', () => {
    for (const e of seed) {
      for (const a of e.alternatives.filter((x) => x.reason === 'equipment')) {
        const other = bySlug.get(a.slug)!;
        expect([...other.equipment].sort(), `${e.slug} -> ${a.slug}`).not.toEqual([...e.equipment].sort());
      }
    }
  });

  it('every exercise has at least one alternative, so substitution always has somewhere to go', () => {
    for (const e of seed) expect(e.alternatives.length, e.slug).toBeGreaterThan(0);
  });

  it('every muscle group and every movement pattern is covered by at least three exercises', () => {
    for (const m of MUSCLE_GROUPS) {
      const n = seed.filter((e) => e.primaryMuscles.includes(m)).length;
      expect(n, m).toBeGreaterThanOrEqual(3);
    }
    for (const p of MOVEMENT_PATTERNS) {
      const n = seed.filter((e) => e.movementPattern === p).length;
      expect(n, p).toBeGreaterThanOrEqual(3);
    }
  });

  it('every muscle group is reachable with the common hostel kits', () => {
    // A generator that cannot find an exercise for a muscle cannot build a
    // programme (Phase 4). Bodyweight alone genuinely cannot train biceps as
    // a primary mover — a chin-up needs a bar — so that one gap is stated
    // here rather than hidden; the generator must handle it.
    const reachable = (kit: readonly string[], m: string): boolean =>
      seed.some((e) => e.primaryMuscles.includes(m as never) && e.equipment.every((q) => kit.includes(q)));
    for (const m of MUSCLE_GROUPS) {
      expect(reachable(['bodyweight'], m), `${m} with bodyweight`).toBe(m !== 'biceps');
      expect(reachable(['bodyweight', 'pull-up-bar'], m), `${m} with bodyweight+bar`).toBe(true);
      expect(reachable(['bodyweight', 'dumbbell'], m), `${m} with dumbbells`).toBe(true);
      expect(reachable(['bodyweight', 'resistance-band'], m), `${m} with bands`).toBe(true);
    }
  });

  it('every equipment type has at least one exercise', () => {
    for (const q of EQUIPMENT) {
      expect(seed.some((e) => e.equipment.includes(q)), q).toBe(true);
    }
  });

  it('increments follow §12.4: 5 kg on the main barbell lower lifts, ≥2.5 kg on barbell compounds', () => {
    for (const slug of ['barbell-back-squat', 'conventional-deadlift', 'sumo-deadlift', 'romanian-deadlift', 'hip-thrust']) {
      expect(bySlug.get(slug)!.defaultIncrementKg, slug).toBe(5);
    }
    // The inverted row uses a racked bar but is loaded by bodyweight; it progresses by reps.
    const bodyweightOnABar = new Set(['inverted-row']);
    for (const e of seed) {
      if (bodyweightOnABar.has(e.slug)) {
        expect(e.defaultIncrementKg, e.slug).toBe(1);
      } else if (COMPOUND_PATTERNS.includes(e.movementPattern) && e.equipment.includes('barbell')) {
        expect(e.defaultIncrementKg, e.slug).toBeGreaterThanOrEqual(2.5);
      }
      if (e.equipment.includes('bodyweight') && e.equipment.length === 1) {
        expect(e.defaultIncrementKg, e.slug).toBe(1); // reps, not load, progress bodyweight work
      }
    }
  });

  it('unilateral exercises say so in their instructions (switch sides / one leg / one arm)', () => {
    for (const e of seed.filter((x) => x.isUnilateral)) {
      const text = e.instructions.join(' ').toLowerCase();
      expect(
        /switch|one leg|one arm|one foot|one hand|single|other side|before switching|alternat|each side|opposite/.test(text),
        e.slug,
      ).toBe(true);
    }
  });
});
