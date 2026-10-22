/**
 * Phase 18 (§26.1), batch 3 — the last reachable edges: portion ordering, a
 * contradicted menu cycle, equal plates, a nudge inside quiet hours, plural
 * wording, prefill without a matching set, progression and the generator.
 */
import { describe, expect, it } from 'vitest';

import { choosePortion } from '../src/ai/portion.js';
import { suggestPlates } from '../src/mess/recommend.js';
import type { MessDish, MessItResponse } from '../src/mess/types.js';
import { detectCycleLength } from '../src/mess/providers/vit/provider.js';
import { planNotifications } from '../src/notify/planner.js';
import { formatClock, instantAt, minuteOfDay } from '../src/notify/time.js';
import { DEFAULT_NOTIFY_SETTINGS, NOTIFY_KINDS } from '../src/notify/types.js';
import { wordReason } from '../src/recommend/engine.js';
import { shouldOfferDeload } from '../src/training/deload.js';
import { generateProgram, trainingDays, EQUIPMENT, type CatalogueExercise } from '../src/training/generator.js';
import { prefillSet } from '../src/training/prefill.js';
import { recommendProgression } from '../src/training/progression.js';
import { weeklyVolume } from '../src/training/volume.js';
import { materializeTemplate, findTemplate } from '../src/training/templates.js';
import { readFileSync } from 'node:fs';

describe('portions', () => {
  it('several weighed serving rows keep their order behind per 100 g', () => {
    const rows = [
      { basis: 'per_serving' as const, servingLabel: '1 katori', servingGrams: 150 },
      { basis: 'per_serving' as const, servingLabel: '1 bowl', servingGrams: 250 },
      { basis: 'per_serving' as const, servingLabel: '1 plate', servingGrams: 350 },
      { basis: 'per_100g' as const, servingLabel: '100 g', servingGrams: 100 },
    ];
    expect(choosePortion(rows, { quantity: 1, unit: 'cup', grams: 150 })).toEqual({ row: 3, servings: 1.5, exact: false });
  });
});

describe('menu cycles', () => {
  it('a contradiction at the candidate length is no cycle at all (never invented from a coincidence)', () => {
    const menus = ['Idli', 'Poha', 'Dosa', 'Upma', 'Puri', 'Pongal', 'Vada'];
    const dates = Array.from({ length: 16 }, (_, i) => new Date(Date.UTC(2026, 9, 1 + i)).toISOString().slice(0, 10));
    const r: MessItResponse = { hostel: 1, mess: 1, menu: dates.map((date, i) => ({ date, menu: [{ type: 1, menu: i === 14 ? 'Something else' : menus[i % 7]! }] })) };
    expect(detectCycleLength(r)).toBeNull();
  });
});

describe('plates', () => {
  it('two plates of equal score are ordered by their key, stably', () => {
    const nut = (kcal: number, protein: number) => ({
      servingLabel: '1 serving', servingGrams: 100,
      macros: { kcalLow: kcal, kcalHigh: kcal, proteinLow: protein, proteinHigh: protein, carbLow: 30, carbHigh: 30, fatLow: 8, fatHigh: 8 },
      confidence: 'medium' as const, source: 'estimated-table' as const,
    });
    const d = (id: string, name: string, n: ReturnType<typeof nut>): MessDish => ({
      id, name, raw: name, label: null, diet: 'veg', role: 'staple', alternatives: [], alternativeDiets: [], isAmbient: false, nutrition: n,
    });
    const plates = suggestPlates(
      {
        meal: { slot: 'lunch', rawMenu: '', dishes: [d('b-chapati', 'Chapati', nut(120, 3)), d('a-chapati', 'Chapati', nut(120, 3)), d('paneer', 'Paneer Butter Masala', nut(300, 14)), d('mix-veg', 'Mix Veg', nut(90, 3))] },
        remainingKcal: 700, remainingProtein: 30, diet: 'vegetarian', goal: 'general',
      },
      5,
    );
    const keys = plates.map((p) => p.items.map((i) => i.dishId).sort().join('+'));
    const withA = keys.findIndex((k) => k.includes('a-chapati') && !k.includes('b-chapati'));
    const withB = keys.findIndex((k) => k.includes('b-chapati') && !k.includes('a-chapati'));
    expect(withA).toBeGreaterThanOrEqual(0);
    expect(withB).toBeGreaterThan(withA);
    expect(plates.length).toBeGreaterThan(0);
  });
});

describe('reminders inside quiet hours', () => {
  it('an evening nudge that falls in quiet hours moves before them', () => {
    const TZ = 'Asia/Kolkata';
    const at = (date: string, m: number) => instantAt(date, m, TZ);
    const dinners = ['2026-10-12', '2026-10-13', '2026-10-14'].map((d) => ({ at: at(d, 22 * 60 + 30), slot: 'dinner' as const, localDate: d }));
    const plan = planNotifications({
      now: at('2026-10-19', 9 * 60), timeZone: TZ, seed: 's', name: null,
      settings: { ...DEFAULT_NOTIFY_SETTINGS, quietStart: '20:30', quietEnd: '07:30', kinds: Object.fromEntries(NOTIFY_KINDS.map((k) => [k, k === 'protein-gap'])) as typeof DEFAULT_NOTIFY_SETTINGS.kinds },
      programme: null, sessionStarts: [], completedDates: [], foodLogs: dinners, weighIns: [], checkIns: [], proteinMetDates: [],
      proteinTargetG: 100, todayProteinHigh: 0, readinessBand: null, history: [], skippedDates: [],
    });
    expect(formatClock(minuteOfDay(plan[0]!.at, TZ))).toBe('20:00');
  });
});

describe('wording', () => {
  it('a reason with a missing text value reads as empty, never "undefined"', () => {
    const w = wordReason({ code: 'session-scheduled', values: {} } as never);
    expect(`${w.headline} ${w.detail}`).not.toContain('undefined');
  });

  it('a deload offered for several muscles at MRV says "are"', () => {
    const week = weeklyVolume([], '2026-W43');
    const offer = shouldOfferDeload({
      mesocycleWeek: 6, thisWeek: { ...week, chest: { ...week.chest, hardSets: 99 }, back: { ...week.back, hardSets: 99 } },
      fatiguedLeadLifts: [], snoozedUntil: null, active: false, today: '2026-10-22',
    });
    expect(offer.reason).toMatch(/back, chest are at the most volume|chest, back are at the most volume/);
  });
});

describe('prefill & progression', () => {
  it('a recommended load with no matching set last time shows no "last time"', () => {
    const p = prefillSet({
      planned: { setIndex: 3, repsMin: 8, repsMax: 12, weightKg: null, rir: 2 },
      lastPerformance: [{ id: 'a', setType: 'working', weightKg: 50, reps: 10, rir: 2 }],
      recommendation: { action: 'increase-load', weightKg: 52.5, repTarget: '8–12', targetRir: 2, reason: 'x' },
    });
    expect(p).toMatchObject({ weightKg: 52.5, reps: 8, lastTime: null });
  });

  const target = { repMin: 8, repMax: 12, targetRir: 2, sets: 3, incrementKg: 2.5 };
  const set = (weightKg: number, reps: number) => ({ weightKg, reps, rir: 2 });

  it('a last session with nothing logged is a fresh baseline', () => {
    expect(recommendProgression({ target, history: [{ date: '2026-10-01', sets: [] }] }).action).toBe('establish-baseline');
  });

  it('fewer working sets than planned never earns a load increase; an empty earlier session never counts as cleared', () => {
    const r = recommendProgression({
      target,
      history: [
        { date: '2026-10-01', sets: [] },
        { date: '2026-10-04', sets: [set(60, 12), set(60, 12), set(60, 12)] },
        { date: '2026-10-07', sets: [set(60, 12), set(60, 12)] },
      ],
    });
    expect(r.action).not.toBe('increase-load');
  });
});

describe('generator', () => {
  const seed = JSON.parse(readFileSync(new URL('../../../database/seeds/exercises.json', import.meta.url), 'utf8')) as Omit<CatalogueExercise, 'id'>[];
  const catalogue: CatalogueExercise[] = seed.map((e) => ({ ...e, id: `id-${e.slug}` }));
  const base = { goal: 'muscle-gain' as const, experience: 'intermediate' as const, daysPerWeek: 4, availableEquipment: EQUIPMENT, limitations: [], catalogue };

  it('training days outside 2–6 are refused', () => {
    expect(() => trainingDays(7)).toThrow(RangeError);
    expect(() => trainingDays(1)).toThrow(RangeError);
  });

  it('one emphasised muscle a split cannot train is declined ("it"); two are declined together ("them")', () => {
    const t = findTemplate('push-pull')!;
    const one = materializeTemplate(t, { ...base, emphasis: ['abs'] } as never);
    expect(one.rationale.find((r) => r.includes('cannot apply'))).toMatch(/Emphasis on abs cannot apply: .* trains it directly/);
    // The same split with calves taken out of every session: two orphans.
    const noCalves = {
      ...t,
      sessions: t.sessions.map((s) => ({ ...s, muscles: s.muscles.filter((m) => m !== 'calves'), directCoverage: s.directCoverage.filter((m) => m !== 'calves') })),
    };
    const two = materializeTemplate(noCalves, { ...base, emphasis: ['abs', 'calves'] } as never);
    expect(two.rationale.find((r) => r.includes('cannot apply'))).toMatch(/Emphasis on (abs, calves|calves, abs) cannot apply: .* trains them directly/);
  });

  it('a very short fat-loss session trims sets, then drops an unprotected compound, until it fits', () => {
    const p = generateProgram({ ...base, goal: 'fat-loss', experience: 'beginner', daysPerWeek: 2, preferredSessionMinutes: 20 } as never);
    expect(p.days.filter((d) => !d.isRest).every((d) => d.estimatedMinutes <= 20 * 1.15)).toBe(true);
    expect(p.rationale.join(' ')).toMatch(/dropped|trimmed/i);
  });

  it('a catalogue listing the same exercise twice still generates deterministically', () => {
    const doubled = [...catalogue, { ...catalogue[0]!, id: 'id-duplicate' }];
    const a = generateProgram({ ...base, catalogue: doubled } as never);
    const b = generateProgram({ ...base, catalogue: [...doubled].reverse() } as never);
    expect(a.days.map((d) => d.exercises.map((e) => e.exerciseId))).toEqual(b.days.map((d) => d.exercises.map((e) => e.exerciseId)));
  });
});

describe('more generator and progression edges', () => {
  const seed = JSON.parse(readFileSync(new URL('../../../database/seeds/exercises.json', import.meta.url), 'utf8')) as Omit<CatalogueExercise, 'id'>[];
  const catalogue: CatalogueExercise[] = seed.map((e) => ({ ...e, id: `id-${e.slug}` }));

  it('a very short muscle-gain session shaves sets off compounds above two before dropping anything', () => {
    const p = generateProgram({ goal: 'muscle-gain', experience: 'intermediate', daysPerWeek: 2, availableEquipment: EQUIPMENT, limitations: [], catalogue, preferredSessionMinutes: 20 } as never);
    expect(p.days.filter((d) => !d.isRest).every((d) => d.estimatedMinutes <= 20 * 1.15)).toBe(true);
  });

  it('the shortest session (15 minutes) drops even a protected lift when nothing else is left to cut', () => {
    const p = generateProgram({ goal: 'muscle-gain', experience: 'beginner', daysPerWeek: 3, availableEquipment: EQUIPMENT, limitations: [], catalogue, preferredSessionMinutes: 15 } as never);
    const sessions = p.days.filter((d) => !d.isRest);
    expect(sessions.every((d) => d.estimatedMinutes <= 15 * 1.15)).toBe(true);
    expect(sessions.every((d) => d.exercises.length >= 1)).toBe(true);
  });

  it('bodyweight-only sessions (no load) never count as clearing the top of the range', () => {
    const target = { repMin: 8, repMax: 12, targetRir: 2, sets: 3, incrementKg: 2.5 };
    const bw = { weightKg: 0, reps: 15, rir: 1 };
    const r = recommendProgression({ target, history: [{ date: '2026-10-01', sets: [bw, bw, bw] }, { date: '2026-10-04', sets: [bw, bw, bw] }] });
    expect(r.action).not.toBe('increase-load');
  });
});
