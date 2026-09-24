/**
 * Phase 11 — TODAY (ADR-017; docs/phase-plans/phase-11-plan.md; owner D1–D19, P1–P7).
 * Every approved rule, band, identity property and event rule is pinned here.
 */
import { describe, expect, it } from 'vitest';

import {
  ACTION_KINDS, EAT_CUTOFF_HOUR, ENGINE_VERSION, MAX_ACTIONS, PRIORITIES, REASON_CODES,
  buildActions, contentHashOf, inputDigestOf, todayActions, todayClock, topActions, wordReason,
  type Action, type ActionKind, type UserModel,
} from '../src/recommend/engine.js';
import {
  COMPLETION_EVIDENCE, TODAY_EVENTS, checkEventTiming, checkTransition, isCompletable, type TodayEvent,
} from '../src/recommend/events.js';
import { canonicalJson, sha256Hex } from '../src/recommend/hash.js';
import { BASE, IDS, PERSONAS, model } from './today-fixtures.js';

const kinds = (m: UserModel): ActionKind[] => topActions(m).map((a) => a.kind);
const find = (m: UserModel, k: ActionKind): Action | undefined => buildActions(m).find((a) => a.kind === k);

/** A model in which every one of the ten server rules fires. */
const EVERYTHING = model({
  hourOfDay: 12,
  training: {
    deload: { state: 'offered', trigger: 'fatigue' },
    limitationSwaps: [{ exerciseId: IDS.squat, exerciseName: 'Barbell Back Squat', bodyParts: ['knee'], alternativeId: IDS.legPress, alternativeName: 'Leg Press' }],
    increaseLoad: [{ exerciseId: IDS.bench, exerciseName: 'Barbell Bench Press', weightKg: 62.5, repTarget: '6–8' }],
    neglected: [{ muscle: 'hamstrings', daysSince: 7 }],
    prsToday: [{ prId: IDS.pr1, exerciseName: 'Deadlift', prType: 'weight', value: 140, previous: 135 }],
  },
  body: { weighedToday: false, daysSinceWeighIn: 5 },
});

/* -------------------------------------------------------- vocabulary -- */

describe('the approved vocabulary, bands and codes (D5, P1)', () => {
  it('ten server kinds in tie-break order; nothing deferred leaks in', () => {
    expect([...ACTION_KINDS]).toEqual([
      'deload', 'injured-limitation', 'start-workout', 'eat-protein', 'eat-meal',
      'progress-load', 'muscle-neglected', 'rest-day', 'celebrate-pr', 'log-weight',
    ]);
    for (const deferred of ['calorie-adjust', 'hydrate', 'add-steps', 'low-readiness', 'resume', 'workout-done', 'volume-ceiling']) {
      expect(ACTION_KINDS as readonly string[]).not.toContain(deferred);
    }
  });

  it('§16.1 bands, injured-limitation at 91 between deload and start-workout', () => {
    expect(PRIORITIES).toEqual({
      deload: 95, 'injured-limitation': 91, 'start-workout': 90, 'eat-protein': { dinner: 88, other: 80 }, 'eat-meal': 75,
      'progress-load': 72, 'muscle-neglected': 68, 'rest-day': 60, 'celebrate-pr': 50, 'log-weight': 45,
    });
    expect(PRIORITIES.deload).toBeGreaterThan(PRIORITIES['injured-limitation']);
    expect(PRIORITIES['injured-limitation']).toBeGreaterThan(PRIORITIES['start-workout']);
  });

  it('every emitted action carries its band', () => {
    const all = buildActions(EVERYTHING);
    const by = (k: ActionKind) => all.find((a) => a.kind === k)?.priority;
    expect(by('deload')).toBe(95);
    expect(by('injured-limitation')).toBe(91);
    expect(by('start-workout')).toBe(90);
    expect(by('eat-protein')).toBe(80); // lunch
    expect(by('progress-load')).toBe(72);
    expect(by('muscle-neglected')).toBe(68);
    expect(by('celebrate-pr')).toBe(50);
    expect(by('log-weight')).toBe(45);
    expect(find(model({ hourOfDay: 20, nutrition: { loggedSlots: ['breakfast', 'lunch', 'snacks'] } }), 'eat-protein')?.priority).toBe(88); // dinner
    expect(find(model({ nutrition: { eaten: { kcalLow: 900, kcalHigh: 1000, proteinLow: 120, proteinHigh: 130 } } }), 'eat-meal')?.priority).toBe(75);
    expect(find(model({ training: { sessionName: null } }), 'rest-day')?.priority).toBe(60);
  });

  it('reason codes, one per kind', () => {
    expect([...REASON_CODES]).toEqual([
      'deload-offered', 'exercise-contraindicated', 'session-scheduled', 'protein-behind', 'meal-remaining',
      'load-increase-due', 'muscle-untrained', 'rest-day', 'pr-today', 'weigh-in-due',
    ]);
  });

  it('basis per kind reflects the source data', () => {
    const basis = Object.fromEntries(buildActions(EVERYTHING).map((a) => [a.kind, a.basis]));
    expect(basis).toMatchObject({
      deload: 'calculated', 'injured-limitation': 'logged', 'start-workout': 'calculated', 'eat-protein': 'calculated',
      'progress-load': 'calculated', 'muscle-neglected': 'logged', 'celebrate-pr': 'logged', 'log-weight': 'calculated',
    });
    expect(find(model({ training: { sessionName: null } }), 'rest-day')?.basis).toBe('calculated');
    expect(find(model({ nutrition: { eaten: { kcalLow: 900, kcalHigh: 1000, proteinLow: 120, proteinHigh: 130 } } }), 'eat-meal')?.basis).toBe('calculated');
  });

  it('targets', () => {
    const target = Object.fromEntries(buildActions(EVERYTHING).map((a) => [a.kind, a.target]));
    expect(target).toMatchObject({
      deload: 'train', 'injured-limitation': 'train', 'start-workout': 'train', 'eat-protein': 'eat',
      'progress-load': 'train', 'muscle-neglected': 'train', 'celebrate-pr': 'progress', 'log-weight': 'progress',
    });
    expect(find(model({ training: { sessionName: null } }), 'rest-day')?.target).toBe('today');
  });
});

/* ------------------------------------------------ ordering and caps -- */

describe('ranking, exclusions, cap and suppression', () => {
  it('at most four, in band order, ranks 1–4', () => {
    const top = topActions(EVERYTHING);
    expect(MAX_ACTIONS).toBe(4);
    expect(top.map((a) => a.kind)).toEqual(['deload', 'injured-limitation', 'start-workout', 'eat-protein']);
    expect(top.map((a) => a.rank)).toEqual([1, 2, 3, 4]);
    expect(buildActions(EVERYTHING).length).toBeGreaterThan(4);
  });

  it('eat-protein XOR eat-meal, across the whole protein range', () => {
    for (let high = 0; high <= 200; high += 5) {
      const n = buildActions(model({ nutrition: { eaten: { kcalLow: 900, kcalHigh: 1000, proteinLow: high * 0.8, proteinHigh: high } } }))
        .filter((a) => a.kind === 'eat-protein' || a.kind === 'eat-meal').length;
      expect(n).toBeLessThanOrEqual(1);
    }
  });

  it('a deload suppresses the rest day', () => {
    expect(kinds(PERSONAS['deload-due']!)).toContain('deload');
    expect(kinds(PERSONAS['deload-due']!)).not.toContain('rest-day');
    expect(kinds(model({ training: { sessionName: null } }))).toContain('rest-day');
  });

  it('deload is first whenever it is offered', () => {
    for (const m of Object.values(PERSONAS)) {
      const top = topActions(model({ training: { deload: { state: 'offered', trigger: 'mrv' } } }, m));
      expect(top[0]?.kind).toBe('deload');
    }
  });

  it('a dismissal hides (kind, subject) for the day; the cap applies after it', () => {
    const dismissed = model({ ...EVERYTHING, dismissedToday: [{ kind: 'deload', subjectKey: '' }] }, EVERYTHING);
    expect(kinds(dismissed)).toEqual(['injured-limitation', 'start-workout', 'eat-protein', 'progress-load']);
    // Only the dismissed subject: another slot's eat action still shows.
    const other = model({ dismissedToday: [{ kind: 'eat-protein', subjectKey: 'dinner' }] });
    expect(kinds(other)).toContain('eat-protein'); // lunch, not dinner
  });
});

/* ---------------------------------------------------- subject keys -- */

describe('stable subject keys', () => {
  it('per kind', () => {
    const subject = Object.fromEntries(buildActions(EVERYTHING).map((a) => [a.kind, a.subjectKey]));
    expect(subject).toEqual({
      deload: '',
      'injured-limitation': `${IDS.squat}>${IDS.legPress}`,
      'start-workout': '',
      'eat-protein': 'lunch',
      'progress-load': IDS.bench,
      'muscle-neglected': 'hamstrings',
      'celebrate-pr': IDS.pr1,
      'log-weight': '',
    });
    expect(find(model({ training: { sessionName: null } }), 'rest-day')?.subjectKey).toBe('');
  });

  it('the same inputs give the same subjects', () => {
    expect(buildActions(EVERYTHING).map((a) => a.subjectKey)).toEqual(buildActions(EVERYTHING).map((a) => a.subjectKey));
  });
});

/* -------------------------------------------------- reasons, words -- */

describe('reason codes and structured values', () => {
  const r = (k: ActionKind, m: UserModel = EVERYTHING) => find(m, k)?.reason;

  it('each kind', () => {
    expect(r('deload')).toEqual({ code: 'deload-offered', values: { trigger: 'fatigue' } });
    expect(r('injured-limitation')).toEqual({
      code: 'exercise-contraindicated',
      values: { exerciseId: IDS.squat, exerciseName: 'Barbell Back Squat', bodyParts: ['knee'], alternativeId: IDS.legPress, alternativeName: 'Leg Press', affectedCount: 1 },
    });
    expect(r('start-workout')).toEqual({ code: 'session-scheduled', values: { sessionName: 'Pull — Back / Biceps', exerciseCount: 6, minutes: 60 } });
    expect(r('eat-protein')).toEqual({
      code: 'protein-behind', values: { slot: 'lunch', proteinTarget: 150, proteinLow: 30, proteinHigh: 42, kcalLeftLow: 1580, kcalLeftHigh: 1750 },
    });
    expect(r('eat-meal', model({ nutrition: { eaten: { kcalLow: 900.4, kcalHigh: 1100.6, proteinLow: 120.44, proteinHigh: 130.06 } } }))).toEqual({
      code: 'meal-remaining', values: { slot: 'lunch', kcalLeftLow: 1299, kcalLeftHigh: 1500, proteinLeftLow: 19.9, proteinLeftHigh: 29.6 },
    });
    expect(r('progress-load')).toEqual({ code: 'load-increase-due', values: { exerciseId: IDS.bench, exerciseName: 'Barbell Bench Press', weightKg: 62.5, repTarget: '6–8' } });
    expect(r('muscle-neglected')).toEqual({ code: 'muscle-untrained', values: { muscle: 'hamstrings', daysSince: 7 } });
    expect(r('rest-day', model({ training: { sessionName: null } }))).toEqual({
      code: 'rest-day', values: { hasProgramme: true, nextSessionName: 'Legs — Quads / Glutes', nextSessionDate: '2026-09-25', kcalTarget: 2400, proteinTarget: 150 },
    });
    expect(r('celebrate-pr')).toEqual({ code: 'pr-today', values: { exerciseName: 'Deadlift', prType: 'weight', value: 140, previous: 135, count: 1 } });
    expect(r('log-weight')).toEqual({ code: 'weigh-in-due', values: { daysSinceWeighIn: 5 } });
  });

  it('the headline and detail are words for the reason, deterministic, and never mention a number the reason lacks', () => {
    for (const a of buildActions(EVERYTHING)) {
      expect(wordReason(a.reason)).toEqual({ headline: a.headline, detail: a.detail });
      expect(a.headline.length).toBeGreaterThan(0);
      expect(a.detail.length).toBeGreaterThan(0);
    }
    expect(find(EVERYTHING, 'injured-limitation')?.headline).toBe('Swap Barbell Back Squat for Leg Press');
    expect(find(EVERYTHING, 'injured-limitation')?.detail).toBe('Barbell Back Squat is ruled out by your knee limitation. Leg Press is the safer swap for today.');
    expect(find(EVERYTHING, 'deload')?.headline).toBe('Take a lighter week');
    expect(find(EVERYTHING, 'log-weight')?.detail).toBe('Last reading 5 days ago. The trend needs regular readings; single numbers do not matter.');
  });

  it('every reason code has words', () => {
    const samples = {
      'deload-offered': { trigger: 'mrv' },
      'exercise-contraindicated': { exerciseName: 'A', bodyParts: ['lower-back', 'knee'], alternativeName: 'B', affectedCount: 3 },
      'session-scheduled': { sessionName: 'S', exerciseCount: 1, minutes: 4 },
      'protein-behind': { slot: 'dinner', proteinTarget: 100, proteinLow: 10, proteinHigh: 20, kcalLeftLow: 1, kcalLeftHigh: 2 },
      'meal-remaining': { slot: 'snacks', kcalLeftLow: 300, kcalLeftHigh: 400, proteinLeftLow: 0, proteinLeftHigh: 5 },
      'load-increase-due': { exerciseName: 'E', weightKg: null, repTarget: '8' },
      'muscle-untrained': { muscle: 'quads', daysSince: null },
      'rest-day': { hasProgramme: false, nextSessionName: null, nextSessionDate: null, kcalTarget: null, proteinTarget: null },
      'pr-today': { exerciseName: 'E', prType: '1rm_est', value: 100, previous: 95, count: 2 },
      'weigh-in-due': { daysSinceWeighIn: null },
    } as const;
    for (const code of REASON_CODES) {
      const w = wordReason({ code, values: samples[code] });
      expect(w.headline, code).not.toMatch(/undefined|NaN/);
      expect(w.detail, code).not.toMatch(/undefined|NaN/);
    }
    expect(wordReason({ code: 'exercise-contraindicated', values: samples['exercise-contraindicated'] }).detail).toContain('lower back and knee limitation'); // the words follow the values; the engine sorts them
    expect(wordReason({ code: 'rest-day', values: samples['rest-day'] }).headline).toBe('No session today');
  });
});

/* ------------------------------------------------- range-aware food -- */

describe('range-aware nutrition (Phase 8 ranges)', () => {
  const eaten = (proteinLow: number, proteinHigh: number, kcalLow = 900, kcalHigh = 1000) =>
    model({ nutrition: { eaten: { kcalLow, kcalHigh, proteinLow, proteinHigh } } });

  it('eat-protein only when even the HIGH end is under 75 % of the target', () => {
    // target 150 → 112.5
    expect(find(eaten(80, 112.4), 'eat-protein')).toBeDefined();
    expect(find(eaten(80, 112.5), 'eat-protein')).toBeUndefined(); // may be on track: no claim it is low
    expect(find(eaten(100, 130), 'eat-protein')).toBeUndefined();
  });

  it('eat-meal only when more than 250 kcal are left at the LOW end (target − eaten high)', () => {
    expect(find(eaten(120, 130, 2000, 2149), 'eat-meal')).toBeDefined(); // 251 left
    expect(find(eaten(120, 130, 2000, 2150), 'eat-meal')).toBeUndefined(); // exactly 250
    expect(find(eaten(120, 130, 1500, 2300), 'eat-meal')).toBeUndefined(); // wide range: at worst 100 left
  });

  it('no targets, or no meal remaining → no eat action', () => {
    expect(kinds(model({ nutrition: { targets: null } })).filter((k) => k.startsWith('eat'))).toEqual([]);
    expect(kinds(model({ hourOfDay: 19, nutrition: { loggedSlots: ['breakfast', 'lunch', 'snacks', 'dinner'] } })).filter((k) => k.startsWith('eat'))).toEqual([]);
  });

  it('the meal is the next unlogged one at or after the current hour (Phase 10 rule, 11/16/19)', () => {
    expect(find(model({ hourOfDay: 10, nutrition: { loggedSlots: [] } }), 'eat-protein')?.subjectKey).toBe('breakfast');
    expect(find(model({ hourOfDay: 10, nutrition: { loggedSlots: ['breakfast'] } }), 'eat-protein')?.subjectKey).toBe('lunch');
    expect(find(model({ hourOfDay: 16, nutrition: { loggedSlots: ['breakfast', 'lunch'] } }), 'eat-protein')?.subjectKey).toBe('snacks');
    expect(find(model({ hourOfDay: 16, nutrition: { loggedSlots: ['breakfast', 'lunch', 'snacks'] } }), 'eat-protein')?.subjectKey).toBe('dinner');
  });
});

/* ------------------------------------------------------- P7 cut-off -- */

describe('P7: no eat action from 22:00 local (21:59 eligible), in the user\'s zone', () => {
  it('the hour boundary', () => {
    const at = (hourOfDay: number) => model({ hourOfDay, nutrition: { loggedSlots: ['breakfast', 'lunch', 'snacks'] } });
    expect(EAT_CUTOFF_HOUR).toBe(22);
    expect(find(at(21), 'eat-protein')).toBeDefined();
    expect(find(at(22), 'eat-protein')).toBeUndefined();
    expect(find(at(23), 'eat-protein')).toBeUndefined();
    const meal = (hourOfDay: number) => model({ hourOfDay, nutrition: { loggedSlots: ['breakfast', 'lunch', 'snacks'], eaten: { kcalLow: 900, kcalHigh: 1000, proteinLow: 120, proteinHigh: 130 } } });
    expect(find(meal(21), 'eat-meal')).toBeDefined();
    expect(find(meal(22), 'eat-meal')).toBeUndefined();
  });

  it('21:59 vs 22:00 is decided in the stored zone, never UTC', () => {
    // 16:29Z and 16:30Z are 21:59 and 22:00 in Asia/Kolkata (UTC+5:30), but 16:xx in UTC.
    const before = todayClock(new Date('2026-09-24T16:29:00Z'), 'Asia/Kolkata');
    const at = todayClock(new Date('2026-09-24T16:30:00Z'), 'Asia/Kolkata');
    expect(before).toEqual({ localDate: '2026-09-24', hourOfDay: 21 });
    expect(at).toEqual({ localDate: '2026-09-24', hourOfDay: 22 });
    const logged = { loggedSlots: ['breakfast', 'lunch', 'snacks'] as const };
    expect(find(model({ ...before, nutrition: logged }), 'eat-protein')).toBeDefined();
    expect(find(model({ ...at, nutrition: logged }), 'eat-protein')).toBeUndefined();
    // The same instant in UTC would still be eligible — which is why UTC is never used.
    expect(todayClock(new Date('2026-09-24T16:30:00Z'), 'UTC').hourOfDay).toBe(16);
  });

  it('the local date follows the zone at midnight', () => {
    expect(todayClock(new Date('2026-09-24T18:29:59Z'), 'Asia/Kolkata')).toEqual({ localDate: '2026-09-24', hourOfDay: 23 });
    expect(todayClock(new Date('2026-09-24T18:30:00Z'), 'Asia/Kolkata')).toEqual({ localDate: '2026-09-25', hourOfDay: 0 });
    expect(todayClock(new Date('2026-09-25T03:30:00Z'), 'America/New_York')).toEqual({ localDate: '2026-09-24', hourOfDay: 23 });
  });
});

/* ----------------------------------------------- P1 injured-limitation -- */

describe('P1: injured-limitation (91) only for a blocked exercise with a safer swap, on a training day', () => {
  const swap = (alternative: boolean) => ({
    exerciseId: IDS.squat, exerciseName: 'Barbell Back Squat', bodyParts: ['knee'],
    alternativeId: alternative ? IDS.legPress : null, alternativeName: alternative ? 'Leg Press' : null,
  });

  it('fires with a swap, at 91, just above start-workout', () => {
    const top = topActions(model({ training: { limitationSwaps: [swap(true)] } }));
    expect(top[0]?.kind).toBe('injured-limitation');
    expect(top[0]?.priority).toBe(91);
    expect(top[1]?.kind).toBe('start-workout');
  });

  it('does not fire without a safer swap, on a rest day, or once the session is done', () => {
    expect(find(model({ training: { limitationSwaps: [swap(false)] } }), 'injured-limitation')).toBeUndefined();
    expect(find(model({ training: { sessionName: null, limitationSwaps: [swap(true)] } }), 'injured-limitation')).toBeUndefined();
    expect(find(model({ training: { completedToday: true, limitationSwaps: [swap(true)] } }), 'injured-limitation')).toBeUndefined();
  });

  it('never merely because a limitation exists: nothing planned is ruled out → nothing fires', () => {
    // The model carries only exercises /training/today flagged; none flagged → no action.
    expect(find(model({ training: { limitationSwaps: [] } }), 'injured-limitation')).toBeUndefined();
  });

  it('the first swappable exercise in plan order is the subject; the count covers every swappable one', () => {
    const a = find(PERSONAS['injured-limitation']!, 'injured-limitation')!;
    expect(a.subjectKey).toBe(`${IDS.squat}>${IDS.legPress}`);
    expect(a.reason.values['affectedCount']).toBe(1); // the lunge has no swap: not counted
    const two = find(model({ training: { limitationSwaps: [swap(false), swap(true), { ...swap(true), exerciseId: IDS.lunge, exerciseName: 'Walking Lunge' }] } }), 'injured-limitation')!;
    expect(two.subjectKey).toBe(`${IDS.squat}>${IDS.legPress}`);
    expect(two.reason.values['affectedCount']).toBe(2);
    expect(two.detail).toContain('1 more exercise today has a safer swap too.');
  });
});

/* ------------------------------------------ identity: hashes, digest -- */

describe('identity: content hash, rank, engine version, input digest (D4, D16, P5)', () => {
  it('SHA-256 matches the standard vectors, including multi-byte UTF-8', () => {
    expect(sha256Hex('')).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(sha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')).toBe('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
    expect(sha256Hex('₹ 5–8 g — Dhal 🍽')).toBe('10a45d410b070df6fd925ecc2460526da0ad522ae9fac2f83b165d37b4e73267');
    expect(sha256Hex('a'.repeat(1000))).toBe('41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3');
  });

  it('canonical JSON: key order never matters', () => {
    expect(canonicalJson({ b: 1, a: { d: [2, { z: 1, y: 2 }], c: null } })).toBe('{"a":{"c":null,"d":[2,{"y":2,"z":1}]},"b":1}');
    expect(canonicalJson({ a: 1, b: 2 })).toBe(canonicalJson({ b: 2, a: 1 }));
  });

  it('the same content gives the same hash, whatever else changed', () => {
    const a = find(BASE, 'start-workout')!;
    const b = find(model({ body: { weighedToday: false, daysSinceWeighIn: 9 }, hourOfDay: 14 }), 'start-workout')!;
    expect(b.contentHash).toBe(a.contentHash);
    expect(a.contentHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('any change in content gives a new hash', () => {
    const before = find(BASE, 'eat-protein')!;
    const after = find(model({ nutrition: { eaten: { kcalLow: 650, kcalHigh: 820, proteinLow: 30, proteinHigh: 43 } } }), 'eat-protein')!;
    expect(after.contentHash).not.toBe(before.contentHash);
  });

  it('rank is not part of the hash: a re-rank keeps the hash (and so the row)', () => {
    const ranked = topActions(EVERYTHING).find((a) => a.kind === 'start-workout')!;
    const reranked = topActions(model({ dismissedToday: [{ kind: 'deload', subjectKey: '' }] }, EVERYTHING)).find((a) => a.kind === 'start-workout')!;
    expect(ranked.rank).toBe(3);
    expect(reranked.rank).toBe(2);
    expect(reranked.contentHash).toBe(ranked.contentHash);
    const { rank: _r, contentHash: _h, ...content } = ranked;
    expect(contentHashOf(content)).toBe(ranked.contentHash);
  });

  it('engine version and input digest', () => {
    const result = todayActions(BASE);
    expect(result.engineVersion).toBe(ENGINE_VERSION);
    expect(ENGINE_VERSION).toBe('today-1');
    expect(result.actions.every((a) => a.engineVersion === 'today-1')).toBe(true);
    expect(result.inputDigest).toBe(sha256Hex(canonicalJson(BASE)));
    expect(result.inputDigest).toBe(inputDigestOf(model({})));
    expect(inputDigestOf(model({ hourOfDay: 14 }))).not.toBe(result.inputDigest);
    expect(result.localDate).toBe('2026-09-24');
  });

  it('deterministic: the same model twice, and with its keys in another order', () => {
    const reordered = JSON.parse(canonicalJson(BASE)) as UserModel;
    expect(todayActions(reordered)).toEqual(todayActions(BASE));
    expect(todayActions(BASE)).toEqual(todayActions(BASE));
  });
});

/* ------------------------------------------------------ the personas -- */

describe('the 11 Phase 11 personas (D11): frozen models, snapshotted ranked output', () => {
  it('there are exactly the approved eleven; low-readiness is not faked', () => {
    expect(Object.keys(PERSONAS).sort()).toEqual([
      'advanced-strength', 'beginner-muscle-gain', 'calorie-deficit', 'calorie-surplus', 'deload-due',
      'first-day-no-data', 'injured-limitation', 'intermediate-fat-loss', 'non-vit-home', 'recomposition', 'rest-day',
    ]);
  });

  for (const [name, m] of Object.entries(PERSONAS)) {
    it(name, async () => {
      await expect(JSON.stringify({ model: m, today: todayActions(m) }, null, 2) + '\n').toMatchFileSnapshot(`./fixtures/today-personas/${name}.json`);
    });
  }

  it('the ranked kinds, at a glance', () => {
    const glance = Object.fromEntries(Object.entries(PERSONAS).map(([n, m]) => [n, kinds(m)]));
    expect(glance).toEqual({
      'beginner-muscle-gain': ['start-workout', 'eat-protein', 'log-weight'],
      'intermediate-fat-loss': ['start-workout', 'eat-meal', 'progress-load'],
      'advanced-strength': ['deload', 'start-workout', 'eat-protein', 'muscle-neglected'],
      recomposition: ['eat-protein', 'muscle-neglected', 'celebrate-pr'],
      'non-vit-home': ['eat-protein', 'rest-day'],
      'rest-day': ['eat-meal', 'rest-day', 'log-weight'],
      'deload-due': ['deload', 'eat-protein'],
      'calorie-deficit': ['eat-protein'],
      'calorie-surplus': ['log-weight'],
      'first-day-no-data': ['eat-protein', 'rest-day'],
      'injured-limitation': ['injured-limitation', 'start-workout', 'eat-meal', 'progress-load'],
    });
  });
});

/* ------------------------------------------------------------ events -- */

describe('events (D7, P2, P4)', () => {
  it('the five events of §9.2', () => {
    expect([...TODAY_EVENTS]).toEqual(['shown', 'opened', 'accepted', 'dismissed', 'completed']);
  });

  it('informational actions cannot be completed; the rest name their evidence', () => {
    expect(COMPLETION_EVIDENCE).toEqual({
      deload: 'deload-accepted', 'injured-limitation': null, 'start-workout': 'session-completed',
      'eat-protein': 'food-logged-in-slot', 'eat-meal': 'food-logged-in-slot', 'progress-load': 'session-with-exercise',
      'muscle-neglected': 'session-with-muscle', 'rest-day': null, 'celebrate-pr': null, 'log-weight': 'weight-logged',
    });
    for (const k of ['rest-day', 'celebrate-pr', 'injured-limitation'] as const) {
      expect(isCompletable(k)).toBe(false);
      expect(checkTransition(k, ['shown', 'accepted'], 'completed')).toEqual({ outcome: 'reject', code: 'not-completable' });
      expect(checkTransition(k, ['shown'], 'accepted')).toEqual({ outcome: 'record' });
      expect(checkTransition(k, ['shown'], 'dismissed')).toEqual({ outcome: 'record' });
    }
  });

  it('transitions', () => {
    const t = (recorded: TodayEvent[], next: TodayEvent, kind: ActionKind = 'start-workout') => checkTransition(kind, recorded, next);
    expect(t([], 'shown')).toEqual({ outcome: 'record' });
    expect(t(['shown'], 'shown')).toEqual({ outcome: 'duplicate' }); // recorded once per action
    for (const e of ['opened', 'accepted', 'dismissed', 'completed'] as const) expect(t([], e)).toEqual({ outcome: 'reject', code: 'not-shown' });
    expect(t(['shown'], 'opened')).toEqual({ outcome: 'record' });
    expect(t(['shown', 'opened'], 'accepted')).toEqual({ outcome: 'record' });
    expect(t(['shown', 'accepted'], 'completed')).toEqual({ outcome: 'record' }); // accepted and completed are separate events
    expect(t(['shown', 'accepted'], 'dismissed')).toEqual({ outcome: 'reject', code: 'accepted-and-dismissed' });
    expect(t(['shown', 'dismissed'], 'accepted')).toEqual({ outcome: 'reject', code: 'accepted-and-dismissed' });
    expect(t(['shown', 'dismissed'], 'opened')).toEqual({ outcome: 'reject', code: 'after-dismissed' });
    expect(t(['shown', 'dismissed'], 'completed')).toEqual({ outcome: 'reject', code: 'after-dismissed' });
    expect(t(['shown', 'completed'], 'dismissed')).toEqual({ outcome: 'reject', code: 'after-completed' });
    expect(t(['shown', 'accepted', 'completed'], 'completed')).toEqual({ outcome: 'duplicate' });
  });

  it('P3 timing: the local day through 03:00 next, delivery within 7 days, in the user\'s zone', () => {
    const base = { generatedFor: '2026-09-24', timeZone: 'Asia/Kolkata', createdAt: new Date('2026-09-24T03:30:00Z') }; // 09:00 IST
    const at = (occurred: string, received = occurred) => checkEventTiming({ ...base, occurredAt: new Date(occurred), receivedAt: new Date(received) });
    expect(at('2026-09-24T04:00:00Z')).toEqual({ ok: true }); // 09:30 IST
    expect(at('2026-09-24T21:29:59Z')).toEqual({ ok: true }); // 02:59:59 IST next day
    expect(at('2026-09-24T21:30:00Z')).toEqual({ ok: false, code: 'outside-day' }); // 03:00 IST next day
    expect(at('2026-09-24T03:20:00Z')).toEqual({ ok: false, code: 'before-recommendation' }); // 10 min before it existed
    expect(at('2026-09-24T03:27:00Z')).toEqual({ ok: true }); // within the 5-minute skew
    expect(at('2026-09-24T04:00:00Z', '2026-09-24T03:50:00Z')).toEqual({ ok: false, code: 'in-future' });
    // A late offline event: delivered 7 days later it is still accepted — as an event of its own day.
    expect(at('2026-09-24T04:00:00Z', '2026-10-01T04:00:00Z')).toEqual({ ok: true });
    expect(at('2026-09-24T04:00:00Z', '2026-10-01T04:00:01Z')).toEqual({ ok: false, code: 'delivered-too-late' });
  });
});
