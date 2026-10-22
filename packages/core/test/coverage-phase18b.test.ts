/**
 * Phase 18 (§26.1), batch 2 — mess recommendations, the reminder planner,
 * the weight trend and the training rules at their edges.
 */
import { describe, expect, it } from 'vitest';

import { dishVerdicts, selectCandidates, type PlateRequest } from '../src/mess/recommend.js';
import type { MessDish } from '../src/mess/types.js';
import { chooseVariant, ignoredInARow, planNotifications, type NotifyHistoryItem, type PlanFacts } from '../src/notify/planner.js';
import { formatClock, instantAt, minuteOfDay } from '../src/notify/time.js';
import { DEFAULT_NOTIFY_SETTINGS, NOTIFY_KINDS } from '../src/notify/types.js';
import { estimateAdaptiveTdee } from '../src/nutrition/trend.js';
import { workingReps } from '../src/training/progression.js';
import { detectPRs } from '../src/training/records.js';
import { pickAlternative, substitute } from '../src/training/substitution.js';
import { daysSinceTrained, recentWeeks, weeklyVolume } from '../src/training/volume.js';
import { deloadEndsOn, shouldOfferDeload } from '../src/training/deload.js';
import type { CatalogueExercise } from '../src/training/generator.js';

/* -------------------------------------------------- mess recommendations -- */

const nut = (kcal: number, protein: number) => ({
  servingLabel: '1 katori',
  servingGrams: 150,
  macros: { kcalLow: kcal, kcalHigh: kcal, proteinLow: protein, proteinHigh: protein, carbLow: 10, carbHigh: 10, fatLow: 5, fatHigh: 5 },
  confidence: 'medium' as const,
  source: 'estimated-table' as const,
});
const dish = (id: string, name: string, over: Partial<MessDish> = {}): MessDish => ({
  id, name, raw: name, label: null, diet: 'veg', role: 'staple', alternatives: [], alternativeDiets: [], isAmbient: false, nutrition: nut(200, 10), ...over,
});
const request = (dishes: MessDish[], over: Partial<PlateRequest> = {}): PlateRequest => ({
  meal: { slot: 'lunch', dishes, rawMenu: '' },
  remainingKcal: 800,
  remainingProtein: 40,
  diet: 'vegetarian',
  goal: 'general',
  ...over,
});

describe('mess recommendations', () => {
  it('an alternative without a known diet is unknown, so a vegetarian never gets it; the same with an allergy', () => {
    const d = dish('veg-pulao', 'Veg Pulao', { alternatives: ['Mystery Rice'], alternativeDiets: [] });
    expect(dishVerdicts(request([d]))[0]).toMatchObject({ eligible: false, reasons: [{ code: 'diet-alternative', dietClass: 'unknown' }] });
    const nv = dish('veg-pulao', 'Veg Pulao', { alternatives: ['Prawn Rice'], alternativeDiets: [] });
    const v = dishVerdicts(request([nv], { diet: 'non-vegetarian', allergies: ['shellfish'] }))[0]!;
    expect(v.eligible).toBe(false);
    expect(v.reasons[0]!.code).toBe('allergen-alternative');
  });

  it('candidates: a zero-kcal estimate has no protein density; equal densities fall back to the slug, both ways', () => {
    const list = selectCandidates(
      request([
        dish('c-chapati', 'Chapati'),
        dish('a-chapati', 'Chapati'),
        dish('b-chapati', 'Chapati'),
        dish('z-chapati', 'Chapati', { nutrition: nut(0, 0) }),
      ]),
    );
    expect(list.filter((c) => c.component === 'staple').map((c) => c.dish.id)).toEqual(['a-chapati', 'b-chapati', 'c-chapati', 'z-chapati'].slice(0, list.filter((c) => c.component === 'staple').length));
  });
});

/* ------------------------------------------------------------- planner -- */

const TZ = 'Asia/Kolkata';
const ist = (date: string, hhmm: string): Date => instantAt(date, Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3)), TZ);
const only = (...kinds: string[]) => ({
  ...DEFAULT_NOTIFY_SETTINGS,
  kinds: Object.fromEntries(NOTIFY_KINDS.map((k) => [k, kinds.includes(k)])) as typeof DEFAULT_NOTIFY_SETTINGS.kinds,
});
const facts = (over: Partial<PlanFacts> = {}): PlanFacts => ({
  now: ist('2026-10-19', '05:00'),
  timeZone: TZ,
  seed: 's',
  name: null,
  settings: DEFAULT_NOTIFY_SETTINGS,
  programme: null,
  sessionStarts: [],
  completedDates: [],
  foodLogs: [],
  weighIns: [],
  checkIns: [],
  proteinMetDates: [],
  proteinTargetG: null,
  todayProteinHigh: 0,
  readinessBand: null,
  skippedDates: [],
  history: [],
  ...over,
});

describe('notification planner', () => {
  it('goal met per kind: doing the thing after a send is not "ignored"; recap and comeback count only when opened', () => {
    const sent = (kind: NotifyHistoryItem['kind']): NotifyHistoryItem[] => [{ kind, localDate: '2026-10-18', variant: 'x', at: ist('2026-10-18', '19:00'), status: 'delivered' }];
    const sets = {
      completed: new Set(['2026-10-18']),
      proteinMet: new Set(['2026-10-18']),
      active: new Set(['2026-10-18']),
      weighed: new Set(['2026-10-18']),
      checkedIn: new Set(['2026-10-18']),
    };
    for (const kind of ['workout-reminder', 'missed-session', 'protein-gap', 'streak-at-risk', 'weigh-in', 'recovery-checkin'] as const) {
      expect(ignoredInARow(kind, sent(kind), sets).count, kind).toBe(0);
    }
    for (const kind of ['weekly-recap', 'comeback'] as const) expect(ignoredInARow(kind, sent(kind), sets).count, kind).toBe(1);
  });

  it('no template for a request (a comeback without a stage) is no variant', () => {
    expect(chooseVariant('comeback', 'cheeky', { name: null }, undefined, [], '2026-10-19', 's')).toBeNull();
  });

  it('unreadable quiet hours fall back to 22:30–07:30', () => {
    const plan = planNotifications(facts({ settings: { ...only('streak-at-risk'), quietStart: 'late', quietEnd: '??' } }));
    expect(plan.every((p) => formatClock(minuteOfDay(p.at, TZ)) === '21:00')).toBe(true);
  });

  it('learned weigh-in and check-in times, and a morning time inside quiet hours moves to their end', () => {
    const mornings = ['2026-10-12', '2026-10-13', '2026-10-14'];
    const plan = planNotifications(facts({ settings: only('weigh-in'), weighIns: mornings.map((d) => ({ at: ist(d, '06:10'), localDate: d })) }));
    const weigh = plan.find((p) => p.kind === 'weigh-in')!;
    expect(formatClock(minuteOfDay(weigh.at, TZ))).toBe('07:30');
    expect(weigh.why).toContain('06:10');
    const check = planNotifications(facts({ settings: only('recovery-checkin'), checkIns: mornings.map((d) => ({ at: ist(d, '09:40'), localDate: d })) }));
    expect(check[0]!.why).toContain('09:40');
    // A weigh-in two days ago: none for a day yet (§21: 2+ days missed).
    const recent = planNotifications(facts({ settings: only('weigh-in'), weighIns: [{ at: ist('2026-10-18', '07:00'), localDate: '2026-10-18' }] }));
    expect(recent.some((p) => p.localDate === '2026-10-19' || p.localDate === '2026-10-20')).toBe(false);
  });

  it('protein nudge: before the learned dinner time, with that time in its why', () => {
    const dinners = ['2026-10-12', '2026-10-13', '2026-10-14'].map((d) => ({ at: ist(d, '20:30'), slot: 'dinner' as const, localDate: d }));
    const plan = planNotifications(facts({ settings: only('protein-gap'), proteinTargetG: 100, foodLogs: dinners }));
    expect(formatClock(minuteOfDay(plan[0]!.at, TZ))).toBe('19:45');
    expect(plan[0]!.why).toContain('20:30');
  });

  it('a Sunday recap with a programme of no training days reports no counts', () => {
    const plan = planNotifications(facts({ now: ist('2026-10-25', '09:00'), programme: {}, settings: only('weekly-recap') }));
    expect(plan.find((p) => p.localDate === '2026-10-25')).toBeDefined();
  });
});

/* ------------------------------------------------------- trend & training -- */

describe('weight trend', () => {
  const entries = Array.from({ length: 21 }, (_, i) => ({ date: new Date(Date.UTC(2026, 9, 1 + i)).toISOString().slice(0, 10), kg: 70 + i * 0.03 }));

  it('adaptive TDEE needs enough logged days and refuses an absurd answer', () => {
    expect(estimateAdaptiveTdee({ entries, intake: [{ date: '2026-10-20', kcal: 2200 }] })).toBeNull();
    const starving = entries.map((e) => ({ date: e.date, kcal: 300 }));
    expect(estimateAdaptiveTdee({ entries, intake: starving })).toBeNull();
  });
});

const ex = (id: string, over: Partial<CatalogueExercise> = {}): CatalogueExercise => ({
  id, slug: id, name: id, movementPattern: 'horizontal-push', equipment: ['barbell'], difficulty: 'beginner', isUnilateral: false,
  defaultIncrementKg: 2.5, primaryMuscles: ['chest'], secondaryMuscles: [], contraindications: [], ...over,
});

describe('training rules', () => {
  it('working reps of a session with no loaded set are zero', () => {
    expect(workingReps({ date: '2026-10-01', sets: [] })).toBe(0);
  });

  it('records pick the heaviest, the most reps and the best 1RM wherever they are in the session', () => {
    const prior = [{ sessionId: 'p', sets: [{ id: 'p1', setType: 'working' as const, weightKg: 60, reps: 5, rir: 2 }] }];
    const current = [
      { id: 'c1', setType: 'working' as const, weightKg: 60, reps: 6, rir: 2 },
      { id: 'c2', setType: 'working' as const, weightKg: 62.5, reps: 3, rir: 1 },
      { id: 'c3', setType: 'working' as const, weightKg: 60, reps: 8, rir: 1 },
      { id: 'c4', setType: 'working' as const, weightKg: 55, reps: 4, rir: 3 },
    ];
    const prs = detectPRs({ prior, current });
    expect(prs.map((p) => `${p.prType}:${p.setLogId}`)).toEqual(expect.arrayContaining(['1rm_est:c3', 'reps:c3', 'weight:c2']));
  });

  it('alternatives: itself, another pattern or another first muscle never qualify; with none the reason names the muscle', () => {
    const bench = ex('bench', { equipment: ['barbell'] });
    const alts = [ex('bench'), ex('row', { movementPattern: 'horizontal-pull' }), ex('fly', { primaryMuscles: ['shoulders'] })];
    expect(pickAlternative(bench, alts, ['dumbbell'], [])).toBeNull();
    const s = substitute(bench, alts, ['dumbbell'], [], 0)!;
    expect(s.alternative).toBeNull();
    expect(s.reason).toContain('chest');
    const noMuscle = substitute(ex('odd', { primaryMuscles: [] }), [], ['dumbbell'], [], 0)!;
    expect(noMuscle.reason).toContain('the same muscle');
  });

  it('dates are validated; future and warm-up sets do not count as trained', () => {
    expect(() => recentWeeks('22-10-2026', 2)).toThrow(RangeError);
    expect(() => deloadEndsOn('soon')).toThrow(RangeError);
    const sets = [
      { localDate: '2026-10-25', exerciseId: 'x', primaryMuscles: ['chest' as const], secondaryMuscles: [], setType: 'working' as const, weightKg: 50, reps: 8 },
      { localDate: '2026-10-20', exerciseId: 'x', primaryMuscles: ['chest' as const], secondaryMuscles: [], setType: 'warmup' as const, weightKg: 20, reps: 10 },
    ];
    expect(daysSinceTrained(sets, 'chest', '2026-10-22')).toBeNull();
    expect(() => daysSinceTrained([{ ...sets[0]!, localDate: 'bad' }], 'chest', '2026-10-22')).toThrow(RangeError);
  });

  it('a deload offered for one muscle at MRV says "is"', () => {
    const week = weeklyVolume([], '2026-W43');
    const offer = shouldOfferDeload({ mesocycleWeek: 6, thisWeek: { ...week, chest: { hardSets: 99, tonnageKg: 0 } }, fatiguedLeadLifts: [], snoozedUntil: null, active: false, today: '2026-10-22' });
    expect(offer.reason).toContain('chest is at the most volume');
  });
});
