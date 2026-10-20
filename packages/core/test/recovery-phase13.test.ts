/**
 * Phase 13 — Recovery (MASTER-SPEC §18, §31; ADR-019): the readiness score,
 * its bands and escalation, the deload `readiness` trigger, and TODAY's
 * advisory `low-readiness` action.
 */
import { describe, expect, it } from 'vitest';

import {
  BAND_ADVICE,
  LOW_READINESS_ESCALATION_DAYS,
  PENALTY_MAX,
  adherenceGapPenalty,
  bandOf,
  energyPenalty,
  liftSignals,
  lowReadinessRun,
  performanceDropPenalty,
  readinessOn,
  sleepDebtPenalty,
  sorenessPenalty,
  type ReadinessInput,
  type RecoveryCheckIn,
} from '../src/recovery/readiness.js';
import { shouldOfferDeload, type DeloadInput } from '../src/training/deload.js';
import { MUSCLE_GROUPS } from '../src/training/generator.js';
import type { SessionLog } from '../src/training/progression.js';
import { PRIORITIES, buildActions, wordReason, type UserModel } from '../src/recommend/engine.js';
import { COMPLETION_EVIDENCE, checkTransition } from '../src/recommend/events.js';
import { recoveryState, trainingFromPlan } from '../src/recommend/model.js';
import { model } from './today-fixtures.js';

const DAY = '2026-09-24';

const check = (date: string, over: Partial<RecoveryCheckIn> = {}): RecoveryCheckIn => ({
  date, sleepHours: null, sleepQuality: null, soreness: null, energy: null, stress: null, ...over,
});

const input = (over: Partial<ReadinessInput> = {}): ReadinessInput => ({
  day: DAY, checkIns: [check(DAY, { sleepHours: 7.5, soreness: 1, energy: 5 })], lifts: [], nutritionDays: [], targets: [], ...over,
});

/* ------------------------------------------------------------ penalties -- */

describe('§18 penalties, each capped and each honest about a missing input', () => {
  it('sleep debt: 10 × the mean nightly shortfall below 7.5 h over the last 7 days, max 25', () => {
    expect(sleepDebtPenalty([], DAY)).toEqual({ key: 'sleep', penalty: 0, max: 25, available: false });
    expect(sleepDebtPenalty([check(DAY, { soreness: 3 })], DAY).available).toBe(false); // a check-in without sleep
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 7.5 })], DAY).penalty).toBe(0);
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 9 })], DAY).penalty).toBe(0); // oversleep is not credit
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 6.5 })], DAY).penalty).toBe(10);
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 6.3 })], DAY).penalty).toBe(12); // float noise does not move it
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 6.25 })], DAY).penalty).toBe(13); // 12.5 rounds up
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 3 })], DAY).penalty).toBe(25); // capped
    // The mean over the nights that were logged: 6 h and 8 h → 0.75 h short on average.
    expect(sleepDebtPenalty([check(DAY, { sleepHours: 6 }), check('2026-09-22', { sleepHours: 8 })], DAY).penalty).toBe(8);
  });

  it('sleep window: the day and the six before it; not the seventh before, not after', () => {
    const edge = [check('2026-09-18', { sleepHours: 4.5 })]; // day − 6
    expect(sleepDebtPenalty(edge, DAY).penalty).toBe(25);
    expect(sleepDebtPenalty([check('2026-09-17', { sleepHours: 4.5 })], DAY).available).toBe(false); // day − 7
    expect(sleepDebtPenalty([check('2026-09-25', { sleepHours: 4.5 })], DAY).available).toBe(false); // after the day
  });

  it('soreness 1 none … 5 very sore → 0…20; energy 5 great … 1 drained → 0…20', () => {
    expect([1, 2, 3, 4, 5].map((s) => sorenessPenalty(s).penalty)).toEqual([0, 5, 10, 15, 20]);
    expect([5, 4, 3, 2, 1].map((e) => energyPenalty(e).penalty)).toEqual([0, 5, 10, 15, 20]);
    expect(sorenessPenalty(null)).toEqual({ key: 'soreness', penalty: 0, max: 20, available: false });
    expect(energyPenalty(null)).toEqual({ key: 'energy', penalty: 0, max: 20, available: false });
  });

  const s = (date: string, weightKg: number, reps: number[], rir: (number | null)[] = reps.map(() => null)): SessionLog => ({
    date, sets: reps.map((r, i) => ({ weightKg, reps: r, rir: rir[i] ?? null })),
  });

  it('performance: the Phase 6 signals (rep decline, RIR drift) at the same load, over lifts trained in the last 7 days', () => {
    const declineAndDrift = [s('2026-09-16', 100, [8, 8, 8], [2, 2, 2]), s('2026-09-20', 100, [8, 7, 7], [2, 2, 1]), s('2026-09-23', 100, [7, 6, 6], [1, 1, 1])];
    expect(liftSignals(declineAndDrift, DAY)).toEqual({ repDecline: true, rirDrift: true });
    expect(performanceDropPenalty([declineAndDrift], DAY)).toEqual({ key: 'performance', penalty: 25, max: 25, available: true });
    const declineOnly = [s('2026-09-16', 100, [8, 8, 8]), s('2026-09-20', 100, [8, 7, 7]), s('2026-09-23', 100, [7, 6, 6])];
    expect(performanceDropPenalty([declineOnly], DAY).penalty).toBe(13); // 12.5
    const steady = [s('2026-09-16', 100, [8, 8, 8], [2, 2, 2]), s('2026-09-20', 100, [8, 8, 8], [2, 2, 2]), s('2026-09-23', 100, [8, 8, 9], [2, 2, 2])];
    expect(performanceDropPenalty([steady], DAY).penalty).toBe(0);
    // Two lifts judged, one fully fatigued: half the points.
    expect(performanceDropPenalty([declineAndDrift, steady], DAY).penalty).toBe(13);
  });

  it('performance: not judged — fewer than three sessions, a changed load, bodyweight, or nothing in the last 7 days', () => {
    expect(liftSignals([s('2026-09-20', 100, [8]), s('2026-09-23', 100, [7])], DAY)).toBeNull();
    expect(liftSignals([s('2026-09-16', 95, [8]), s('2026-09-20', 100, [8]), s('2026-09-23', 100, [7])], DAY)).toBeNull();
    expect(liftSignals([s('2026-09-16', 0, [12]), s('2026-09-20', 0, [11]), s('2026-09-23', 0, [10])], DAY)).toBeNull();
    expect(liftSignals([s('2026-09-10', 100, [8]), s('2026-09-14', 100, [7]), s('2026-09-17', 100, [6])], DAY)).toBeNull(); // last one 7 days before
    expect(performanceDropPenalty([], DAY)).toEqual({ key: 'performance', penalty: 0, max: 25, available: false });
  });

  it('performance: sessions after the day are ignored (readiness for a past day uses what was known then)', () => {
    const history = [s('2026-09-16', 100, [8, 8]), s('2026-09-20', 100, [8, 7]), s('2026-09-23', 100, [7, 6]), s('2026-09-25', 102.5, [8, 8])];
    expect(liftSignals(history, DAY)).toEqual({ repDecline: true, rirDrift: false });
  });

  const day = (date: string, proteinHigh: number, kcalLow: number, kcalHigh: number) => ({ date, itemCount: 3, kcalLow, kcalHigh, proteinHigh });
  const targets = [{ effectiveFrom: '2026-01-01', kcal: 2000, proteinG: 120 }];

  it('adherence gap: the Phase 12 rules over the seven days before the day, logged days only', () => {
    expect(adherenceGapPenalty([], targets, DAY)).toEqual({ key: 'adherence', penalty: 0, max: 10, available: false });
    const met = day('2026-09-23', 130, 1900, 2100);
    const missedBoth = day('2026-09-22', 80, 1200, 1400);
    expect(adherenceGapPenalty([met], targets, DAY).penalty).toBe(0);
    expect(adherenceGapPenalty([met, missedBoth], targets, DAY).penalty).toBe(5);
    expect(adherenceGapPenalty([missedBoth], targets, DAY).penalty).toBe(10);
    // Today (not finished) and the eighth day back are outside the window.
    expect(adherenceGapPenalty([day(DAY, 0, 0, 100), day('2026-09-16', 0, 0, 100)], targets, DAY).available).toBe(false);
    expect(adherenceGapPenalty([day('2026-09-17', 0, 0, 100)], targets, DAY).penalty).toBe(10); // day − 7 is in
    // No target in effect: nothing to judge against.
    expect(adherenceGapPenalty([met], [], DAY).available).toBe(false);
  });
});

/* ---------------------------------------------------------------- score -- */

describe('readiness: 100 minus the penalties, only from available inputs', () => {
  it('no check-in for the day → no readiness (nothing guessed)', () => {
    expect(readinessOn(input({ checkIns: [] }))).toBeNull();
    expect(readinessOn(input({ checkIns: [check('2026-09-23', { sleepHours: 5 })] }))).toBeNull();
  });

  it('a perfect check-in with nothing else known → 100, the missing components listed as not available', () => {
    const r = readinessOn(input())!;
    expect(r.score).toBe(100);
    expect(r.band).toBe('ready');
    expect(r.components.map((c) => [c.key, c.available])).toEqual([
      ['sleep', true], ['soreness', true], ['energy', true], ['performance', false], ['adherence', false],
    ]);
    expect(r.components.map((c) => c.max)).toEqual([25, 20, 20, 25, 10]);
    expect(Object.values(PENALTY_MAX).reduce((a, b) => a + b, 0)).toBe(100);
  });

  it('a check-in with one answer: only that input counts', () => {
    const r = readinessOn(input({ checkIns: [check(DAY, { soreness: 4 })] }))!;
    expect(r.score).toBe(85);
    expect(r.components.filter((c) => c.available).map((c) => c.key)).toEqual(['soreness']);
  });

  it('sleep quality and stress are logged but have no term in the formula', () => {
    const calm = readinessOn(input({ checkIns: [check(DAY, { soreness: 2, energy: 4, sleepQuality: 5, stress: 1 })] }))!;
    const tense = readinessOn(input({ checkIns: [check(DAY, { soreness: 2, energy: 4, sleepQuality: 1, stress: 5 })] }))!;
    expect(tense.score).toBe(calm.score);
  });

  it('every penalty at its maximum → 0, never negative', () => {
    const decline = [0, 1, 2].map((i): SessionLog => ({ date: `2026-09-2${i + 1}`, sets: [{ weightKg: 100, reps: 8 - i, rir: 3 - i }] }));
    const r = readinessOn(input({
      checkIns: [check(DAY, { sleepHours: 3, soreness: 5, energy: 1 })],
      lifts: [decline],
      nutritionDays: [{ date: '2026-09-23', itemCount: 1, kcalLow: 100, kcalHigh: 200, proteinHigh: 5 }],
      targets: [{ effectiveFrom: '2026-01-01', kcal: 2000, proteinG: 120 }],
    }))!;
    expect(r.components.map((c) => c.penalty)).toEqual([25, 20, 20, 25, 10]);
    expect(r.score).toBe(0);
    expect(r.band).toBe('rest');
  });

  it('band boundaries: 75/74, 55/54, 35/34', () => {
    expect([100, 75, 74, 55, 54, 35, 34, 0].map(bandOf)).toEqual(['ready', 'ready', 'advisory', 'advisory', 'reduce', 'reduce', 'rest', 'rest']);
    const at = (sleepHours: number, soreness: number, energy: number) =>
      readinessOn(input({ checkIns: [check(DAY, { sleepHours, soreness, energy })] }))!;
    expect(at(6.5, 3, 4)).toMatchObject({ score: 75, band: 'ready' }); // 10 + 10 + 5
    expect(at(6.4, 3, 4)).toMatchObject({ score: 74, band: 'advisory' }); // 11 + 10 + 5
    expect(at(5.5, 5, 4)).toMatchObject({ score: 55, band: 'advisory' }); // 20 + 20 + 5
    expect(at(5.4, 5, 4)).toMatchObject({ score: 54, band: 'reduce' }); // 21 + 20 + 5
    expect(at(5, 5, 1)).toMatchObject({ score: 35, band: 'reduce' }); // 25 + 20 + 20
    // 34: one more point from the adherence gap (one mark missed in ten).
    const days = ['2026-09-19', '2026-09-20', '2026-09-21', '2026-09-22', '2026-09-23'].map((date, i) => ({
      date, itemCount: 2, kcalLow: 1950, kcalHigh: 2050, proteinHigh: i === 0 ? 100 : 130,
    }));
    const r = readinessOn(input({ checkIns: [check(DAY, { sleepHours: 5, soreness: 5, energy: 1 })], nutritionDays: days, targets: [{ effectiveFrom: '2026-01-01', kcal: 2000, proteinG: 120 }] }))!;
    expect(r).toMatchObject({ score: 34, band: 'rest' });
  });

  it('advice is §18\'s effect for the band, in plain words (no diagnosis)', () => {
    expect(BAND_ADVICE.ready).toBe('Ready to train as planned.');
    expect(BAND_ADVICE.advisory).toContain('Train as planned');
    expect(BAND_ADVICE.reduce).toContain('one fewer set on your accessory lifts');
    expect(BAND_ADVICE.rest).toContain('Consider resting today');
    for (const words of Object.values(BAND_ADVICE)) expect(words).not.toMatch(/injur|illness|diagnos|sick|medical/i);
    expect(readinessOn(input({ checkIns: [check(DAY, { soreness: 5, energy: 1 })] }))!.advice).toBe(BAND_ADVICE.advisory);
  });

  it('deterministic: the same records give the same readiness', () => {
    const i = input({ checkIns: [check(DAY, { sleepHours: 6, soreness: 3, energy: 3 }), check('2026-09-21', { sleepHours: 5 })] });
    expect(readinessOn(i)).toEqual(readinessOn(i));
    expect(readinessOn({ ...i, checkIns: [...i.checkIns].reverse() })).toEqual(readinessOn(i));
  });
});

/* ------------------------------------------------------------ escalation -- */

describe('escalation: readiness under 35 three days running', () => {
  const scores = (m: Record<string, number>) => (d: string) => m[d] ?? null;

  it('counts consecutive low days ending today', () => {
    expect(lowReadinessRun(scores({ '2026-09-24': 30, '2026-09-23': 20, '2026-09-22': 34 }), DAY)).toBe(3);
    expect(lowReadinessRun(scores({ '2026-09-24': 30, '2026-09-23': 35, '2026-09-22': 10 }), DAY)).toBe(1); // 35 is not low
    expect(lowReadinessRun(scores({ '2026-09-24': 30, '2026-09-22': 10 }), DAY)).toBe(1); // a day without a check-in breaks it
    expect(lowReadinessRun(scores({ '2026-09-24': 60, '2026-09-23': 20, '2026-09-22': 20 }), DAY)).toBe(0); // better today
  });

  it('before today\'s check-in, the run ending yesterday still stands', () => {
    expect(lowReadinessRun(scores({ '2026-09-23': 20, '2026-09-22': 20, '2026-09-21': 20 }), DAY)).toBe(3);
  });

  it('counted at most a week back', () => {
    const all = Object.fromEntries(Array.from({ length: 20 }, (_, i) => [`2026-09-${String(24 - i).padStart(2, '0')}`, 10]));
    expect(lowReadinessRun(scores(all), DAY)).toBe(7);
  });

  const quiet = Object.fromEntries(MUSCLE_GROUPS.map((m) => [m, { hardSets: 0, tonnageKg: 0 }])) as DeloadInput['thisWeek'];
  const deload = (over: Partial<DeloadInput>): DeloadInput => ({
    mesocycleWeek: 2, thisWeek: quiet, fatiguedLeadLifts: [], snoozedUntil: null, active: false, today: DAY, ...over,
  });

  it('three days → the Phase 6 deload is OFFERED with trigger readiness; two days are not enough', () => {
    expect(LOW_READINESS_ESCALATION_DAYS).toBe(3);
    expect(shouldOfferDeload(deload({ lowReadinessDays: 2 })).offer).toBe(false);
    const o = shouldOfferDeload(deload({ lowReadinessDays: 3 }));
    expect(o).toMatchObject({ offer: true, trigger: 'readiness' });
    expect(o.reason).toContain('under 35 for 3 days running');
    expect(shouldOfferDeload(deload({})).offer).toBe(false); // unknown = 0
  });

  it('the Phase 6 rules keep their behaviour: fatigue first, snooze and an active week still win', () => {
    const lifts = [{ exerciseId: 'a', name: 'Squat' }, { exerciseId: 'b', name: 'Bench' }];
    expect(shouldOfferDeload(deload({ lowReadinessDays: 5, fatiguedLeadLifts: lifts })).trigger).toBe('fatigue');
    expect(shouldOfferDeload(deload({ lowReadinessDays: 5, snoozedUntil: '2026-09-30' })).offer).toBe(false);
    expect(shouldOfferDeload(deload({ lowReadinessDays: 5, active: true })).offer).toBe(false);
  });
});

/* ------------------------------------------------------------ TODAY ------ */

describe('TODAY low-readiness (band 89): advice only, dismissible, never completed', () => {
  const accessories = ['Cable Lateral Raise', 'Triceps Pushdown'];
  const m = (readiness: number | null, band: UserModel['recovery']['band'], over: { lowDays?: number; training?: Partial<UserModel['training']> } = {}) =>
    model({ training: { accessories, ...(over.training ?? {}) }, recovery: { readiness, band, lowDays: over.lowDays ?? 0 } });
  const low = (x: UserModel) => buildActions(x).find((a) => a.kind === 'low-readiness');

  it('reduce band on a training day: one fewer set on the accessories, named', () => {
    const a = low(m(48, 'reduce'))!;
    expect(a).toMatchObject({ priority: 89, subjectKey: 'fewer-sets', basis: 'calculated', target: 'train', reason: { code: 'readiness-low', values: { readiness: 48, band: 'reduce', accessories, lowDays: 0 } } });
    expect(a.headline).toBe('Readiness 48: one fewer set on accessories');
    expect(a.detail).toBe('Consider one fewer set on Cable Lateral Raise and Triceps Pushdown today. Your main lifts stay as planned. Nothing changes unless you choose to.');
    expect(PRIORITIES['low-readiness']).toBe(89);
  });

  it('reduce band with no accessories today → nothing to suggest', () => {
    expect(low(m(48, 'reduce', { training: { accessories: [] } }))).toBeUndefined();
  });

  it('rest band: consider resting; the run is named from two days', () => {
    expect(low(m(30, 'rest'))!.detail).toBe('Your check-in points to low recovery today. Resting is reasonable; the session stays planned if you feel ready. Nothing changes unless you choose to.');
    const a = low(m(30, 'rest', { lowDays: 3 }))!;
    expect(a).toMatchObject({ subjectKey: 'rest', reason: { values: { readiness: 30, band: 'rest', accessories: [], lowDays: 3 } } });
    expect(a.headline).toBe('Readiness 30: consider resting');
    expect(a.detail).toContain('under 35 for 3 days running');
  });

  it('nothing for ready or advisory, without a check-in, on a rest day, or once the session is done', () => {
    expect(low(m(80, 'ready'))).toBeUndefined();
    expect(low(m(60, 'advisory'))).toBeUndefined();
    expect(low(m(null, null))).toBeUndefined();
    expect(low(m(20, 'rest', { training: { sessionName: null } }))).toBeUndefined();
    expect(low(m(20, 'rest', { training: { completedToday: true } }))).toBeUndefined();
  });

  it('ranks beside the session it is about: after start-workout (90), before food (88/80)', () => {
    const kinds = buildActions(m(30, 'rest', { lowDays: 1 })).map((a) => a.kind);
    expect(kinds.indexOf('low-readiness')).toBe(kinds.indexOf('start-workout') + 1);
  });

  it('dismissed → hidden for the day; informational → accepted or dismissed, never completed', () => {
    const x = m(30, 'rest');
    expect(low({ ...x, dismissedToday: [{ kind: 'low-readiness', subjectKey: 'rest' }] })).toBeUndefined();
    expect(COMPLETION_EVIDENCE['low-readiness']).toBeNull();
    expect(checkTransition('low-readiness', ['shown'], 'accepted')).toEqual({ outcome: 'record' });
    expect(checkTransition('low-readiness', ['shown'], 'dismissed')).toEqual({ outcome: 'record' });
    expect(checkTransition('low-readiness', ['shown', 'accepted'], 'completed')).toEqual({ outcome: 'reject', code: 'not-completable' });
  });

  it('advice only: the engine never touches the plan it was given', () => {
    const x = m(20, 'rest', { lowDays: 4 });
    const before = JSON.stringify(x);
    buildActions(x);
    expect(JSON.stringify(x)).toBe(before);
    const start = buildActions(x).find((a) => a.kind === 'start-workout')!;
    const same = buildActions(model({ training: { accessories } })).find((a) => a.kind === 'start-workout')!;
    expect(start.reason).toEqual(same.reason); // the session is offered exactly as planned
  });

  it('§16.2: the rest day carries readiness when there is one', () => {
    const rest = (readiness: number | null) =>
      buildActions(model({ training: { sessionName: null }, recovery: { readiness, band: readiness === null ? null : bandOf(readiness), lowDays: 0 } })).find((a) => a.kind === 'rest-day')!;
    expect(rest(82).reason.values['readiness']).toBe(82);
    expect(rest(82).detail).toContain('Readiness today: 82.');
    expect(rest(null).detail).not.toContain('Readiness');
    // Regression (found by the API suite): without a programme the rest day carries it too.
    const none = buildActions(model({ training: { hasProgramme: false, sessionName: null }, recovery: { readiness: 90, band: 'ready', lowDays: 0 } })).find((a) => a.kind === 'rest-day')!;
    expect(none.detail).toBe('Set up a programme and FITOS will plan your sessions. A walk is a good start. Readiness today: 90.');
  });

  it('the deload offer words name the readiness trigger', () => {
    expect(wordReason({ code: 'deload-offered', values: { trigger: 'readiness' } }).detail).toBe(
      'Your readiness has been under 35 for three days or more. A lighter week is offered; nothing changes until you accept it.',
    );
  });
});

describe('model assembly (Phase 13)', () => {
  const x = (exerciseName: string, compound: boolean, ruledOutBy: string[] = []) => ({
    exerciseId: exerciseName, exerciseName, progression: null, ruledOutBy, swap: null, compound,
  });

  it('accessories: the non-compound exercises not ruled out, in plan order, once each', () => {
    expect(trainingFromPlan([x('Squat', true), x('Leg Curl', false), x('Calf Raise', false), x('Leg Extension', false, ['knee']), x('Leg Curl', false)]).accessories)
      .toEqual(['Leg Curl', 'Calf Raise']);
  });

  it('recoveryState from readiness (nulls without a check-in)', () => {
    expect(recoveryState(null, 0)).toEqual({ readiness: null, band: null, lowDays: 0 });
    const r = readinessOn(input({ checkIns: [check(DAY, { soreness: 5, energy: 1, sleepHours: 5 })] }))!;
    expect(recoveryState(r, 2)).toEqual({ readiness: 35, band: 'reduce', lowDays: 2 });
  });
});
