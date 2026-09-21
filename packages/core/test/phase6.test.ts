/**
 * Phase 6 core: volume engine, deload offer and targets, the bodyweight
 * progression branch, prefill with a recommendation, substitution. Every
 * expectation is a hand calculation against §12.3–§12.6 and the owner's
 * decisions 12.1–12.8.
 */
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { MUSCLE_GROUPS, VOLUME_LANDMARKS, type CatalogueExercise, type MuscleGroup } from '../src/training/generator.js';
import {
  DELOAD_LEAD_LIFTS,
  deloadEndsOn,
  deloadTargets,
  mesocycleAfterDeload,
  roundToHalf,
  shouldOfferDeload,
} from '../src/training/deload.js';
import { prefillSet } from '../src/training/prefill.js';
import { recommendProgression, type ExerciseTarget, type SessionLog } from '../src/training/progression.js';
import { needsSubstitution, pickAlternative, substitute } from '../src/training/substitution.js';
import {
  daysSinceTrained,
  landmarkStatus,
  neglectedMuscles,
  recentWeeks,
  volumeReport,
  weeklyVolume,
  type VolumeSet,
} from '../src/training/volume.js';

/* -------------------------------------------------------------- volume -- */

const vset = (
  localDate: string,
  primary: MuscleGroup[],
  secondary: MuscleGroup[] = [],
  weightKg: number | null = 60,
  reps = 10,
  setType: VolumeSet['setType'] = 'working',
): VolumeSet => ({ localDate, exerciseId: `${primary[0]}-x`, primaryMuscles: primary, secondaryMuscles: secondary, setType, weightKg, reps });

describe('weeklyVolume — hand calculation', () => {
  // ISO week 2026-W39 = Mon 2026-09-21 … Sun 2026-09-27.
  const sets: VolumeSet[] = [
    vset('2026-09-21', ['chest'], ['triceps', 'shoulders'], 60, 10), // bench ×3
    vset('2026-09-21', ['chest'], ['triceps', 'shoulders'], 60, 10),
    vset('2026-09-21', ['chest'], ['triceps', 'shoulders'], 60, 8),
    vset('2026-09-21', ['chest'], ['triceps', 'shoulders'], 40, 12, 'warmup'), // never counts
    vset('2026-09-23', ['quads', 'glutes'], ['hamstrings', 'abs'], 80, 8), // squat ×2
    vset('2026-09-23', ['quads', 'glutes'], ['hamstrings', 'abs'], 80, 8),
    vset('2026-09-23', ['quads'], [], 40, 12, 'drop'), // never counts
    vset('2026-09-27', ['back'], ['biceps'], null, 8), // Sunday, unloaded chin-ups: sets count, tonnage 0
    vset('2026-09-28', ['chest'], ['triceps'], 62.5, 10), // Monday: next week
  ];

  it('counts working sets only, 1 per primary and 0.5 per secondary, inside the ISO week', () => {
    const v = weeklyVolume(sets, '2026-W39');
    expect(v.chest.hardSets).toBe(3);
    expect(v.triceps.hardSets).toBe(1.5);
    expect(v.shoulders.hardSets).toBe(1.5);
    expect(v.quads.hardSets).toBe(2);
    expect(v.glutes.hardSets).toBe(2);
    expect(v.hamstrings.hardSets).toBe(1);
    expect(v.abs.hardSets).toBe(1);
    expect(v.back.hardSets).toBe(1);
    expect(v.biceps.hardSets).toBe(0.5);
    expect(v.calves.hardSets).toBe(0);
  });

  it('tonnage: weight × reps on loaded working sets, halved for secondaries, zero when unloaded', () => {
    const v = weeklyVolume(sets, '2026-W39');
    expect(v.chest.tonnageKg).toBe(600 + 600 + 480);
    expect(v.triceps.tonnageKg).toBe(840);
    expect(v.quads.tonnageKg).toBe(1280);
    expect(v.back.tonnageKg).toBe(0);
  });

  it('the next ISO week holds only Monday\'s set', () => {
    const v = weeklyVolume(sets, '2026-W40');
    expect(v.chest.hardSets).toBe(1);
    expect(v.triceps.hardSets).toBe(0.5);
    expect(v.quads.hardSets).toBe(0);
  });

  it('a muscle listed as both primary and secondary counts once', () => {
    const v = weeklyVolume([vset('2026-09-21', ['back'], ['back', 'biceps'])], '2026-W39');
    expect(v.back.hardSets).toBe(1);
  });
});

describe('landmarkStatus — every §12.3 boundary', () => {
  it('chest: 0 none; 5 below-mv; 6–9 below-mev; 10–18 mev-to-mav; 19 above-mav; 20 at-mrv', () => {
    expect(landmarkStatus('chest', 0)).toBe('none');
    expect(landmarkStatus('chest', 5)).toBe('below-mv');
    expect(landmarkStatus('chest', 6)).toBe('below-mev');
    expect(landmarkStatus('chest', 9.5)).toBe('below-mev');
    expect(landmarkStatus('chest', 10)).toBe('mev-to-mav');
    expect(landmarkStatus('chest', 18)).toBe('mev-to-mav');
    expect(landmarkStatus('chest', 19)).toBe('above-mav');
    expect(landmarkStatus('chest', 20)).toBe('at-mrv');
    expect(landmarkStatus('chest', 25)).toBe('at-mrv');
  });

  it('every muscle follows its own row of the table', () => {
    for (const m of MUSCLE_GROUPS) {
      const lm = VOLUME_LANDMARKS[m];
      expect(landmarkStatus(m, lm.mv - 0.5)).toBe('below-mv');
      expect(landmarkStatus(m, lm.mev)).toBe('mev-to-mav');
      expect(landmarkStatus(m, lm.mavHigh)).toBe('mev-to-mav');
      expect(landmarkStatus(m, lm.mrv)).toBe('at-mrv');
    }
  });
});

describe('recentWeeks / volumeReport / neglect', () => {
  it('four weeks ending in the week of a date, oldest first, across a month boundary', () => {
    expect(recentWeeks('2026-09-21', 4)).toEqual(['2026-W36', '2026-W37', '2026-W38', '2026-W39']);
    expect(recentWeeks('2027-01-04', 2)).toEqual(['2026-W53', '2027-W01']);
  });

  it('the report marks owned muscles and carries the landmarks', () => {
    const r = volumeReport([vset('2026-09-21', ['chest'])], ['chest', 'back'], ['chest', 'back']);
    expect(r.length).toBe(2);
    const chest = r[0]!.muscles.find((m) => m.muscle === 'chest')!;
    expect(chest.owned).toBe(true);
    expect(chest.landmarks).toEqual(VOLUME_LANDMARKS.chest);
    expect(r[0]!.muscles.find((m) => m.muscle === 'calves')!.owned).toBe(false);
  });

  it('neglect: owned muscles with no set in the last 6 days; exactly 6 days is not neglected, 7 is', () => {
    const sets = [vset('2026-09-15', ['chest'], ['triceps']), vset('2026-09-14', ['back'], ['biceps'])];
    const owned: MuscleGroup[] = ['chest', 'triceps', 'back', 'biceps', 'quads'];
    expect(neglectedMuscles(sets, owned, '2026-09-21')).toEqual(['back', 'quads', 'biceps']); // back 7 days, chest 6
    expect(neglectedMuscles(sets, owned, '2026-09-20')).toEqual(['quads']);
    // Secondary work counts as trained.
    expect(neglectedMuscles(sets, ['triceps'], '2026-09-21')).toEqual([]);
    // Owned only (owner 12.7): calves are not the programme's problem.
    expect(neglectedMuscles(sets, ['chest'], '2026-09-21')).toEqual([]);
    // Nothing logged yet: nothing is "behind".
    expect(neglectedMuscles([], owned, '2026-09-21')).toEqual([]);
  });

  it('daysSinceTrained', () => {
    const sets = [vset('2026-09-15', ['chest'], ['triceps']), vset('2026-09-19', ['chest'])];
    expect(daysSinceTrained(sets, 'chest', '2026-09-21')).toBe(2);
    expect(daysSinceTrained(sets, 'triceps', '2026-09-21')).toBe(6);
    expect(daysSinceTrained(sets, 'quads', '2026-09-21')).toBeNull();
  });
});

/* -------------------------------------------------------------- deload -- */

describe('shouldOfferDeload (owner 12.2–12.3)', () => {
  const quiet = weeklyVolume([], '2026-W39');
  const base = { mesocycleWeek: 3, thisWeek: quiet, fatiguedLeadLifts: [], snoozedUntil: null, active: false, today: '2026-09-21' };
  const squat = { exerciseId: 'sq', name: 'Barbell Back Squat' };
  const bench = { exerciseId: 'bp', name: 'Barbell Bench Press' };

  it('nothing → no offer, with a reason', () => {
    const r = shouldOfferDeload(base);
    expect(r.offer).toBe(false);
    expect(r.reason.length).toBeGreaterThan(10);
  });

  it('fatigue on one lead lift is not enough; on two it is, naming them', () => {
    expect(shouldOfferDeload({ ...base, fatiguedLeadLifts: [squat] }).offer).toBe(false);
    const r = shouldOfferDeload({ ...base, fatiguedLeadLifts: [squat, bench] });
    expect(r).toMatchObject({ offer: true, trigger: 'fatigue' });
    expect(r.reason).toContain('Barbell Back Squat and Barbell Bench Press');
    expect(DELOAD_LEAD_LIFTS).toBe(2);
    // The same lift twice is still one lift.
    expect(shouldOfferDeload({ ...base, fatiguedLeadLifts: [squat, squat] }).offer).toBe(false);
  });

  it('week ≥ 6 with a muscle at MRV offers; week 5 does not; week 6 under MRV does not', () => {
    const chestAtMrv = { ...quiet, chest: { hardSets: 20, tonnageKg: 0 } };
    expect(shouldOfferDeload({ ...base, mesocycleWeek: 6, thisWeek: chestAtMrv })).toMatchObject({ offer: true, trigger: 'mrv' });
    expect(shouldOfferDeload({ ...base, mesocycleWeek: 5, thisWeek: chestAtMrv }).offer).toBe(false);
    expect(shouldOfferDeload({ ...base, mesocycleWeek: 6, thisWeek: { ...quiet, chest: { hardSets: 19, tonnageKg: 0 } } }).offer).toBe(false);
  });

  it('a declined offer is not repeated before the snooze date; an active week is never re-offered', () => {
    const fatigued = { ...base, fatiguedLeadLifts: [squat, bench] };
    expect(shouldOfferDeload({ ...fatigued, snoozedUntil: '2026-09-28' }).offer).toBe(false);
    expect(shouldOfferDeload({ ...fatigued, snoozedUntil: '2026-09-21' }).offer).toBe(true);
    expect(shouldOfferDeload({ ...fatigued, active: true }).offer).toBe(false);
  });
});

describe('deloadTargets (owner 12.4)', () => {
  const planned = [1, 2, 3, 4].map((i) => ({ setIndex: i, repsMin: 6, repsMax: 12, weightKg: null, rir: 1 }));

  it('sets × 0.6 rounded (4 → 2, 3 → 2, 1 → 1), load × 0.9 to 0.5 kg, RIR + 2 capped at 5', () => {
    const t = deloadTargets(planned, 62.5);
    expect(t.length).toBe(2);
    expect(t.map((s) => s.setIndex)).toEqual([1, 2]);
    expect(t[0]!.weightKg).toBe(56.5); // 56.25 → 56.5
    expect(t[0]!.rir).toBe(3);
    expect(deloadTargets(planned.slice(0, 3), 100).length).toBe(2);
    expect(deloadTargets(planned.slice(0, 1), 100).length).toBe(1);
    expect(deloadTargets(planned.map((s) => ({ ...s, rir: 4 })), 100)[0]!.rir).toBe(5);
  });

  it('no last load: the plan\'s weight × 0.9 when it has one, else none', () => {
    expect(deloadTargets(planned, null)[0]!.weightKg).toBeNull();
    expect(deloadTargets(planned.map((s) => ({ ...s, weightKg: 40 })), null)[0]!.weightKg).toBe(36);
  });

  it('roundToHalf, deloadEndsOn, mesocycleAfterDeload', () => {
    expect(roundToHalf(56.25)).toBe(56.5);
    expect(roundToHalf(56.2)).toBe(56);
    expect(deloadEndsOn('2026-09-21')).toBe('2026-09-28');
    expect(deloadEndsOn('2026-12-28')).toBe('2027-01-04');
    expect(mesocycleAfterDeload()).toBe(1);
  });
});

/* --------------------------------------------------- bodyweight branch -- */

describe('progression: bodyweight lifts progress by reps (owner 12.5); the six branches are untouched', () => {
  const target: ExerciseTarget = { repMin: 8, repMax: 15, targetRir: 2, sets: 3, incrementKg: 2.5 };
  const bw = (date: string, reps: number[]): SessionLog => ({ date, sets: reps.map((r) => ({ weightKg: 0, reps: r, rir: 2 })) });

  it('below the top of the range: add reps toward repMax, no load', () => {
    const r = recommendProgression({ history: [bw('2026-09-14', [10, 9, 8])], target });
    expect(r.action).toBe('add-reps');
    expect(r.weightKg).toBeNull();
    expect(r.repTarget).toBe('11–15');
    expect(r.reason).toContain('10 reps');
  });

  it('every set at the top: say so and hand the next step to the user', () => {
    const r = recommendProgression({ history: [bw('2026-09-14', [15, 15, 15])], target });
    expect(r.action).toBe('add-reps');
    expect(r.repTarget).toBe('15+');
    expect(r.reason).toMatch(/Add a set|load it/);
  });

  it('a loaded lift still takes the loaded branches (regression guard)', () => {
    const loaded: SessionLog = { date: '2026-09-14', sets: [{ weightKg: 60, reps: 15, rir: 1 }, { weightKg: 60, reps: 15, rir: 1 }, { weightKg: 60, reps: 15, rir: 1 }] };
    expect(recommendProgression({ history: [loaded], target }).action).toBe('increase-load');
    expect(recommendProgression({ history: [], target }).action).toBe('establish-baseline');
  });
});

/* -------------------------------------------- prefill with recommendation -- */

describe('prefillSet with a recommendation (owner 12.1)', () => {
  const planned = { setIndex: 1, repsMin: 6, repsMax: 12, weightKg: null, rir: 1 };
  const last = [{ id: 'a', setType: 'working' as const, weightKg: 60, reps: 12, rir: 1 }];

  it('increase-load: the new load and the bottom of the range', () => {
    const p = prefillSet({ planned, lastPerformance: last, recommendation: { action: 'increase-load', weightKg: 62.5, repTarget: '6–12', targetRir: 1, reason: 'r' } });
    expect(p).toMatchObject({ weightKg: 62.5, reps: 6, rir: 1, weightSource: 'recommendation' });
    expect(p.lastTime).toBe(last[0]);
  });

  it('hold / add-reps: the recommended load at the top of the range; deload: its lighter load and higher RIR', () => {
    expect(prefillSet({ planned, lastPerformance: last, recommendation: { action: 'add-reps', weightKg: 60, repTarget: '6–12', targetRir: 1, reason: 'r' } })).toMatchObject({ weightKg: 60, reps: 12 });
    expect(prefillSet({ planned, lastPerformance: last, recommendation: { action: 'deload', weightKg: 54, repTarget: '6–12', targetRir: 3, reason: 'r' } })).toMatchObject({ weightKg: 54, rir: 3, weightSource: 'recommendation' });
  });

  it('establish-baseline or a reps-only recommendation: back to last time / the plan', () => {
    expect(prefillSet({ planned, lastPerformance: last, recommendation: { action: 'establish-baseline', weightKg: null, repTarget: '6–12', targetRir: 1, reason: 'r' } })).toMatchObject({ weightKg: 60, weightSource: 'last-session' });
    expect(prefillSet({ planned, lastPerformance: [], recommendation: null })).toMatchObject({ weightKg: null, weightSource: 'none' });
  });
});

/* -------------------------------------------------------- substitution -- */

describe('substitution (§12.6, owner 12.6)', () => {
  const seed = JSON.parse(readFileSync(new URL('../../../database/seeds/exercises.json', import.meta.url), 'utf8')) as (Omit<CatalogueExercise, 'id'> & { alternatives: { slug: string }[] })[];
  const catalogue = new Map(seed.map((e) => [e.slug, { ...e, id: `id-${e.slug}` } as CatalogueExercise & { alternatives: { slug: string }[] }]));
  const bench = catalogue.get('barbell-bench-press')!;
  const benchAlternatives = bench.alternatives.map((a) => catalogue.get(a.slug)!);
  const fullKit = ['barbell', 'dumbbell', 'machine', 'cable', 'kettlebell', 'pull-up-bar', 'resistance-band', 'bodyweight'] as const;

  it('nothing wrong: no substitution', () => {
    expect(needsSubstitution(bench, fullKit, [], 0)).toBeNull();
    expect(substitute(bench, benchAlternatives, fullKit, [], 1)).toBeNull();
  });

  it('equipment lost: a same-pattern, same-muscle alternative the user can perform', () => {
    const kit = ['dumbbell', 'bodyweight'] as const;
    const s = substitute(bench, benchAlternatives, kit, [], 0)!;
    expect(s.trigger).toBe('equipment');
    expect(s.alternative).not.toBeNull();
    expect(s.alternative!.movementPattern).toBe(bench.movementPattern);
    expect(s.alternative!.primaryMuscles[0]).toBe(bench.primaryMuscles[0]);
    expect(s.alternative!.equipment.every((q) => q === 'bodyweight' || (kit as readonly string[]).includes(q))).toBe(true);
    expect(s.reason).toContain('barbell');
    expect(s.reason).toContain('load does not carry over');
  });

  it('rejected twice triggers; once does not', () => {
    expect(needsSubstitution(bench, fullKit, [], 1)).toBeNull();
    expect(needsSubstitution(bench, fullKit, [], 2)?.trigger).toBe('rejected');
  });

  it('limitation: the alternative must not be contraindicated either', () => {
    const squat = catalogue.get('barbell-back-squat')!;
    const alts = squat.alternatives.map((a) => catalogue.get(a.slug)!);
    const s = substitute(squat, alts, fullKit, ['knee'], 0);
    expect(s?.trigger).toBe('limitation');
    if (s?.alternative !== null && s?.alternative !== undefined) {
      expect(s.alternative.contraindications).not.toContain('knee');
    }
  });

  it('no performable alternative: said honestly, nothing invented', () => {
    // Push-ups are always performable, so equipment alone never empties the
    // list; a limitation every alternative shares does.
    const s = substitute(bench, benchAlternatives, ['kettlebell'], ['shoulder', 'wrist', 'elbow'], 0)!;
    expect(s.alternative).toBeNull();
    expect(s.reason).toContain('No alternative');
    expect(pickAlternative(bench, [], fullKit, [])).toBeNull();
  });
});
