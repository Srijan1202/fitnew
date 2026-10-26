import { describe, expect, it } from 'vitest';

import { BANNED, TEMPLATES, fits, nameFor, render } from '../src/notify/copy.js';
import { chooseVariant, ignoredInARow, learnMeals, planNotifications, streakEnding, type NotifyHistoryItem, type PlanFacts } from '../src/notify/planner.js';
import { formatClock, inWindow, instantAt, isoWeekday, minuteOfDay, parseClock, usualMinute } from '../src/notify/time.js';
import { DAILY_CAP, DEFAULT_NOTIFY_SETTINGS, MIN_GAP_MINUTES, NOTIFY_KINDS, NOTIFY_TONES } from '../src/notify/types.js';
import { addDays, localDateOf } from '../src/nutrition/log.js';

const TZ = 'Asia/Kolkata';
/** Monday 2026-10-19, 09:00 IST. */
const MONDAY_9 = instantAt('2026-10-19', 9 * 60, TZ);
const ist = (date: string, hhmm: string): Date => instantAt(date, parseClock(hhmm)!, TZ);

function facts(over: Partial<PlanFacts> = {}): PlanFacts {
  return {
    now: MONDAY_9,
    timeZone: TZ,
    seed: 'user-1',
    name: 'Srijan Srivastava',
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
  };
}

const onlyKinds = (...kinds: string[]) => ({
  ...DEFAULT_NOTIFY_SETTINGS,
  kinds: Object.fromEntries(NOTIFY_KINDS.map((k) => [k, kinds.includes(k)])) as typeof DEFAULT_NOTIFY_SETTINGS.kinds,
});

/* --------------------------------------------------------------- time -- */

describe('notify/time', () => {
  it('local minute and instant round-trip in IST; the weekday', () => {
    expect(minuteOfDay(MONDAY_9, TZ)).toBe(540);
    expect(MONDAY_9.toISOString()).toBe('2026-10-19T03:30:00.000Z');
    expect(localDateOf(instantAt('2026-10-19', 23 * 60 + 59, TZ), TZ)).toBe('2026-10-19');
    expect(isoWeekday('2026-10-19')).toBe(1);
    expect(isoWeekday('2026-10-25')).toBe(7);
  });

  it('a habit is the median local time, the day pivoting at 04:00, to 5 minutes; needs repeats', () => {
    expect(usualMinute([18 * 60 + 20, 18 * 60 + 35, 18 * 60 + 40])).toBe(18 * 60 + 35);
    // 23:50, 00:10 and 00:30 are one late habit, around 00:10 — not midday.
    expect(usualMinute([23 * 60 + 50, 10, 30])).toBe(10);
    expect(usualMinute([600, 610])).toBeNull();
    expect(usualMinute([600, 610], 2)).toBe(605);
  });

  it('clock strings and quiet windows that wrap midnight', () => {
    expect(parseClock('07:30')).toBe(450);
    expect(parseClock('7:30')).toBeNull();
    expect(parseClock('24:00')).toBeNull();
    expect(formatClock(1415)).toBe('23:35');
    expect(inWindow(23 * 60, 22 * 60 + 30, 7 * 60 + 30)).toBe(true);
    expect(inWindow(6 * 60, 22 * 60 + 30, 7 * 60 + 30)).toBe(true);
    expect(inWindow(12 * 60, 22 * 60 + 30, 7 * 60 + 30)).toBe(false);
    expect(inWindow(13 * 60, 13 * 60, 14 * 60)).toBe(true);
  });
});

/* --------------------------------------------------------------- copy -- */

describe('notify/copy — every word is FITOS-written, and kind', () => {
  it('ids are unique; every kind has cheeky and gentle words, and comeback every stage in each tone', () => {
    expect(new Set(TEMPLATES.map((t) => t.id)).size).toBe(TEMPLATES.length);
    for (const kind of NOTIFY_KINDS) {
      for (const tone of NOTIFY_TONES) {
        const pool = TEMPLATES.filter((t) => t.kind === kind && t.tone === tone);
        expect(pool.length, `${kind}/${tone}`).toBeGreaterThan(0);
        if (kind === 'comeback') expect(new Set(pool.map((t) => t.stage))).toEqual(new Set([2, 4, 7]));
        // Every kind can always be said: a variant needing no data beyond what the kind always has.
        const always = kind === 'workout-reminder' || kind === 'missed-session' ? ['session'] : [];
        expect(pool.some((t) => (t.needs ?? []).every((n) => always.includes(n))), `${kind}/${tone} always sayable`).toBe(true);
      }
    }
  });

  it('guardrails in every tone: nothing about the body, no food guilt, no insults; slots are declared', () => {
    for (const t of TEMPLATES) {
      expect(`${t.title} ${t.body}`, t.id).not.toMatch(BANNED);
      const slots = [...`${t.title} ${t.body}`.matchAll(/\{(\w+)\}/g)].map((m) => m[1]);
      for (const s of slots) if (s !== 'name') expect(t.needs ?? [], `${t.id} declares {${s}}`).toContain(s);
      expect(t.title.length, t.id).toBeLessThanOrEqual(60);
      expect(t.body.length, t.id).toBeLessThanOrEqual(140);
    }
    expect('you look fat').toMatch(BANNED);
    expect('eat less today').toMatch(BANNED);
  });

  it('render fills slots; the name is the first word, or the tone\'s stand-in', () => {
    const t = TEMPLATES.find((x) => x.id === 'wr-c4')!;
    expect(render(t, { name: 'Srijan Srivastava', session: 'Legs' })).toEqual({
      title: "Plot twist: it's Legs day",
      body: "Not really a twist, it's in the plan. One hour, Srijan.",
    });
    expect(nameFor(null, 'cheeky')).toBe('legend');
    expect(nameFor('  ', 'gentle')).toBe('there');
    expect(fits(TEMPLATES.find((x) => x.id === 'sr-c1')!, { name: null, streak: null })).toBe(false);
  });
});

/* ------------------------------------------------------------ planner -- */

const PPL = { 1: 'Push', 3: 'Pull', 5: 'Legs' } as const;

describe('notify/planner', () => {
  it('off means nothing at all', () => {
    expect(planNotifications(facts({ settings: { ...DEFAULT_NOTIFY_SETTINGS, enabled: false }, programme: PPL }))).toEqual([]);
  });

  it('every item is a FITOS template, rendered (no generated words)', () => {
    const plan = planNotifications(facts({ programme: PPL, proteinTargetG: 120 }));
    expect(plan.length).toBeGreaterThan(0);
    for (const p of plan) {
      const t = TEMPLATES.find((x) => x.id === p.variant)!;
      expect(t.kind).toBe(p.kind);
      expect(p.title.length).toBeGreaterThan(0);
      expect(`${p.title} ${p.body}`).not.toMatch(BANNED);
    }
  });

  it('§21: at most two a day, three hours apart, none in quiet hours, none in the past', () => {
    for (const settings of [DEFAULT_NOTIFY_SETTINGS, { ...DEFAULT_NOTIFY_SETTINGS, kinds: { ...DEFAULT_NOTIFY_SETTINGS.kinds, 'weigh-in': true, 'recovery-checkin': true } }]) {
      const plan = planNotifications(facts({ settings, programme: { 1: 'Push', 2: 'Pull', 3: 'Legs', 4: 'Upper', 5: 'Lower', 6: 'Full', 7: 'Arms' }, proteinTargetG: 120 }));
      const byDay = new Map<string, number[]>();
      for (const p of plan) {
        expect(p.at.getTime()).toBeGreaterThan(MONDAY_9.getTime());
        const m = minuteOfDay(p.at, TZ);
        expect(inWindow(m, 22 * 60 + 30, 7 * 60 + 30), `${p.kind} at ${formatClock(m)}`).toBe(false);
        byDay.set(p.localDate, [...(byDay.get(p.localDate) ?? []), m]);
      }
      for (const [day, minutes] of byDay) {
        expect(minutes.length, day).toBeLessThanOrEqual(DAILY_CAP);
        if (minutes.length === 2) expect(Math.abs(minutes[0]! - minutes[1]!)).toBeGreaterThanOrEqual(MIN_GAP_MINUTES);
      }
    }
  });

  it('a notification already sent today counts against today\'s cap and spacing', () => {
    const sent: NotifyHistoryItem = { kind: 'missed-session', localDate: '2026-10-19', variant: 'ms-c4', at: ist('2026-10-19', '08:30'), status: 'delivered' };
    const now = ist('2026-10-19', '09:00');
    const plan = planNotifications(facts({ now, programme: PPL, proteinTargetG: 120, history: [sent] })).filter((p) => p.localDate === '2026-10-19');
    expect(plan.length).toBeLessThanOrEqual(DAILY_CAP - 1);
    expect(plan.every((p) => p.kind !== 'missed-session')).toBe(true);
    for (const p of plan) expect(minuteOfDay(p.at, TZ) - 8 * 60 - 30).toBeGreaterThanOrEqual(MIN_GAP_MINUTES);
  });

  it('preferences: a kind switched off never appears; weigh-in and check-in are off by default', () => {
    const plan = planNotifications(facts({ programme: PPL, proteinTargetG: 120, settings: { ...DEFAULT_NOTIFY_SETTINGS, kinds: { ...DEFAULT_NOTIFY_SETTINGS.kinds, 'protein-gap': false } } }));
    expect(plan.some((p) => p.kind === 'protein-gap')).toBe(false);
    expect(plan.some((p) => p.kind === 'weigh-in' || p.kind === 'recovery-checkin')).toBe(false);
  });

  it('learned timing: an hour before this user usually trains on that weekday; 17:00 until learned', () => {
    const mondays = ['2026-09-28', '2026-10-05', '2026-10-12'];
    const learned = planNotifications(
      facts({ programme: { 3: 'Pull' }, settings: onlyKinds('workout-reminder'), sessionStarts: mondays.map((d) => ist(addDays(d, 2), '18:40')), completedDates: mondays.map((d) => addDays(d, 2)) }),
    );
    const wed = learned.find((p) => p.localDate === '2026-10-21')!;
    expect(formatClock(minuteOfDay(wed.at, TZ))).toBe('17:40');
    expect(wed.why).toContain('18:40');
    expect(wed.cancelOn).toEqual([{ event: 'workout-started', localDate: '2026-10-21', grams: null }]);
    const fresh = planNotifications(facts({ programme: { 3: 'Pull' }, settings: onlyKinds('workout-reminder') }));
    expect(formatClock(minuteOfDay(fresh[0]!.at, TZ))).toBe('17:00');
    expect(fresh[0]!.title + fresh[0]!.body).toMatch(/Pull/);
  });

  it('only when useful: no workout reminder on a rest day or once trained; protein nudge skipped once on track', () => {
    // (Day 7 is the comeback's last word, so the next Monday is silent.)
    const plan = planNotifications(facts({ programme: { 1: 'Push', 3: 'Pull' }, completedDates: ['2026-10-19'], settings: onlyKinds('workout-reminder') }));
    expect(plan.map((p) => p.localDate)).toEqual(['2026-10-21']);
    const protein = planNotifications(facts({ proteinTargetG: 120, todayProteinHigh: 95, settings: onlyKinds('protein-gap') }));
    expect(protein.some((p) => p.localDate === '2026-10-19')).toBe(false);
    const behind = planNotifications(facts({ proteinTargetG: 120, todayProteinHigh: 40, settings: onlyKinds('protein-gap') }));
    expect(behind[0]).toMatchObject({ localDate: '2026-10-19', screen: 'food-log', slot: 'dinner' });
    expect(behind[0]!.cancelOn).toEqual([{ event: 'protein-reached', localDate: '2026-10-19', grams: 90 }]);
  });

  it('missed session: the morning after an unlogged planned day, cancelled by completing it late or training today', () => {
    const now = ist('2026-10-20', '06:00');
    const plan = planNotifications(facts({ now, programme: { 1: 'Push' }, settings: onlyKinds('missed-session') }));
    const tue = plan.find((p) => p.localDate === '2026-10-20')!;
    expect(tue.title + tue.body).toMatch(/Push|Yesterday/);
    expect(formatClock(minuteOfDay(tue.at, TZ))).toBe('08:30');
    expect(tue.cancelOn.map((c) => `${c.event}@${c.localDate}`)).toEqual(['workout-completed@2026-10-19', 'workout-started@2026-10-20']);
  });

  it('ADR-030: a skipped day gets no workout reminder, and no "missed session" the morning after', () => {
    // Monday skipped: the week has moved on a day, so Monday's weekday entry is
    // not a session today, and Tuesday morning does not call it missed.
    const plan = planNotifications(facts({ programme: { 1: 'Push', 3: 'Pull' }, skippedDates: ['2026-10-19'], settings: onlyKinds('workout-reminder') }));
    expect(plan.map((p) => p.localDate)).toEqual(['2026-10-21']);
    const now = ist('2026-10-20', '06:00');
    const missed = planNotifications(facts({ now, programme: { 1: 'Push' }, skippedDates: ['2026-10-19'], settings: onlyKinds('missed-session') }));
    expect(missed.find((p) => p.localDate === '2026-10-20')).toBeUndefined();
  });

  it('streak at risk: tonight, with the real streak; cancelled by any activity', () => {
    const active = ['2026-10-14', '2026-10-15', '2026-10-16', '2026-10-17', '2026-10-18'];
    const plan = planNotifications(facts({ settings: onlyKinds('streak-at-risk'), foodLogs: active.map((d) => ({ at: ist(d, '13:00'), slot: 'lunch' as const, localDate: d })) }));
    const tonight = plan.find((p) => p.localDate === '2026-10-19')!;
    expect(`${tonight.title} ${tonight.body}`).toMatch(/5/);
    expect(formatClock(minuteOfDay(tonight.at, TZ))).toBe('21:00');
    expect(tonight.cancelOn).toEqual([{ event: 'any-activity', localDate: '2026-10-19', grams: null }]);
    expect(streakEnding(new Set(active), '2026-10-18')).toBe(5);
    // Already active today: no streak nudge tonight.
    const logged = planNotifications(facts({ settings: onlyKinds('streak-at-risk'), foodLogs: [{ at: ist('2026-10-19', '08:00'), slot: 'breakfast', localDate: '2026-10-19' }] }));
    expect(logged.some((p) => p.localDate === '2026-10-19')).toBe(false);
  });

  it('beta 3.8: no "streak at risk" on a rest day (it counts by itself) or a skipped day; the number counts rest days', () => {
    // 2026-10-19 is a Monday: Push Mon, Pull Wed; the rest are rest days. Monday is skipped.
    const plan = planNotifications(facts({ programme: { 1: 'Push', 3: 'Pull' }, skippedDates: ['2026-10-19'], settings: onlyKinds('streak-at-risk') }));
    const days = plan.map((p) => p.localDate);
    expect(days).toContain('2026-10-21');
    for (const d of ['2026-10-19', '2026-10-20', '2026-10-22', '2026-10-23', '2026-10-24', '2026-10-25']) expect(days, d).not.toContain(d);

    // Sun 18 rest, Sat 17 logged, Fri 16 logged, Thu 15 rest (before the run): 3.
    const rest = (d: string): boolean => ['2026-10-15', '2026-10-18'].includes(d);
    expect(streakEnding(new Set(['2026-10-16', '2026-10-17']), '2026-10-18', rest)).toBe(3);
    expect(streakEnding(new Set(), '2026-10-18', rest)).toBe(0);
    // Every day a rest day: looked back at most a year, still nothing active.
    expect(streakEnding(new Set(), '2026-10-18', () => true)).toBe(0);
  });

  it('quiet hours move a nudge out of the window, or drop it', () => {
    const plan = planNotifications(facts({ settings: { ...onlyKinds('streak-at-risk'), quietStart: '20:00', quietEnd: '08:00' } }));
    for (const p of plan) expect(formatClock(minuteOfDay(p.at, TZ))).toBe('19:00');
  });

  it('comeback: day 2 and 4 if the app is not opened, day 7 says reminders stop — and is the only word that day', () => {
    const plan = planNotifications(facts({ programme: PPL, proteinTargetG: 120 }));
    const comeback = plan.filter((p) => p.kind === 'comeback');
    expect(comeback.map((p) => p.localDate)).toEqual(['2026-10-21', '2026-10-23', '2026-10-26']);
    expect(comeback.at(-1)!.title).toMatch(/don't seem to be working/);
    expect(plan.filter((p) => p.localDate === '2026-10-26').map((p) => p.kind)).toEqual(['comeback']);
    for (const c of comeback) expect(c.cancelOn).toEqual([{ event: 'app-opened', localDate: '2026-10-19', grams: null }]);
  });

  it('back-off: ignored three times → every other day; six → a week off; opened or done resets', () => {
    const sent = (n: number, status: NotifyHistoryItem['status'] = 'delivered'): NotifyHistoryItem[] =>
      Array.from({ length: n }, (_, i) => {
        const d = addDays('2026-10-18', -i);
        return { kind: 'streak-at-risk', localDate: d, variant: 'sr-c4', at: ist(d, '21:00'), status };
      });
    const days = (h: NotifyHistoryItem[]) => planNotifications(facts({ settings: onlyKinds('streak-at-risk'), history: h })).map((p) => p.localDate);
    expect(days([])).toHaveLength(7);
    expect(days(sent(3))).toEqual(['2026-10-20', '2026-10-22', '2026-10-24']);
    expect(days(sent(6))).toEqual(['2026-10-25']);
    expect(days([{ ...sent(1, 'opened')[0]!, localDate: '2026-10-18' }, ...sent(6).slice(1)])).toHaveLength(7);
    const sets = { completed: new Set<string>(), started: new Set<string>(), meals: new Set<string>(), proteinMet: new Set<string>(), active: new Set(['2026-10-18']), weighed: new Set<string>(), checkedIn: new Set<string>() };
    expect(ignoredInARow('streak-at-risk', sent(6), sets).count).toBe(0);
  });

  it('variety: never the same words for a kind within a week; the variant this user opens most wins', () => {
    const plan = planNotifications(facts({ settings: onlyKinds('streak-at-risk') }));
    const variants = plan.map((p) => p.variant);
    expect(new Set(variants).size).toBe(variants.length);
    const history: NotifyHistoryItem[] = [
      { kind: 'protein-gap', localDate: '2026-10-01', variant: 'pg-c3', at: ist('2026-10-01', '19:00'), status: 'opened' },
      { kind: 'protein-gap', localDate: '2026-10-03', variant: 'pg-c3', at: ist('2026-10-03', '19:00'), status: 'opened' },
      { kind: 'protein-gap', localDate: '2026-10-05', variant: 'pg-c5', at: ist('2026-10-05', '19:00'), status: 'delivered' },
    ];
    expect(chooseVariant('protein-gap', 'cheeky', { name: null, target: 120 }, undefined, history, '2026-10-19', 'u')!.id).toBe('pg-c3');
  });

  it('readiness: a reduce or rest day is spoken to gently; a rest day gets no workout reminder', () => {
    const reduce = planNotifications(facts({ programme: { 1: 'Push', 3: 'Pull' }, readinessBand: 'reduce', settings: onlyKinds('workout-reminder') }));
    expect(reduce[0]).toMatchObject({ localDate: '2026-10-19', tone: 'gentle' });
    expect(reduce.find((p) => p.localDate === '2026-10-21')!.tone).toBe('cheeky');
    const rest = planNotifications(facts({ programme: { 1: 'Push' }, readinessBand: 'rest', settings: onlyKinds('workout-reminder') }));
    expect(rest.some((p) => p.localDate === '2026-10-19')).toBe(false);
  });

  it('gentle tone in settings: every word is gentle', () => {
    const plan = planNotifications(facts({ programme: PPL, proteinTargetG: 120, settings: { ...DEFAULT_NOTIFY_SETTINGS, tone: 'gentle' } }));
    expect(plan.length).toBeGreaterThan(0);
    expect(plan.every((p) => p.tone === 'gentle')).toBe(true);
  });

  it('weekly recap on Sunday afternoon (clear of the evening protein nudge), with this week\'s numbers when planned on the day', () => {
    const sunday = ist('2026-10-25', '10:00');
    const plan = planNotifications(facts({ now: sunday, programme: PPL, completedDates: ['2026-10-19', '2026-10-21'], settings: onlyKinds('weekly-recap') }));
    const recap = plan.find((p) => p.localDate === '2026-10-25')!;
    expect(formatClock(minuteOfDay(recap.at, TZ))).toBe('16:00');
    expect(recap.screen).toBe('progress');
    expect(recap.actions).toEqual([]);
  });

  it('found in the sample week: on Sunday the recap and the protein nudge both fit, with meal reminders, within the cap', () => {
    const plan = planNotifications(facts({ programme: PPL, proteinTargetG: 120 })).filter((p) => p.localDate === '2026-10-25');
    const kinds = plan.map((p) => p.kind);
    expect(kinds).toEqual(expect.arrayContaining(['protein-gap', 'weekly-recap']));
    expect(kinds.some((k) => k.startsWith('meal-'))).toBe(true);
    expect(plan.length).toBeLessThanOrEqual(DAILY_CAP);
  });

  it('a kind already handled today (cancelled because done, or sent) is not planned again', () => {
    const cancelled: NotifyHistoryItem = { kind: 'workout-reminder', localDate: '2026-10-19', variant: 'wr-c1', at: ist('2026-10-19', '17:00'), status: 'cancelled' };
    const plan = planNotifications(facts({ programme: { 1: 'Push' }, settings: onlyKinds('workout-reminder'), history: [cancelled] }));
    expect(plan.some((p) => p.localDate === '2026-10-19')).toBe(false);
  });

  /* ------------------------------------------------- beta 3.5 (owner) -- */

  it('a workout started today (still running, or not yet synced) means no workout reminder, and no missed-session nudge', () => {
    const now = ist('2026-10-19', '07:00');
    const started = ist('2026-10-19', '06:30');
    const settings = onlyKinds('workout-reminder', 'missed-session');
    const plan = planNotifications(facts({ now, programme: { 1: 'Push', 7: 'Legs' }, settings, sessionStarts: [started] }));
    expect(plan.some((p) => p.localDate === '2026-10-19')).toBe(false);
    const without = planNotifications(facts({ now, programme: { 1: 'Push', 7: 'Legs' }, settings }));
    expect(without.filter((p) => p.localDate === '2026-10-19').map((p) => p.kind).sort()).toEqual(['missed-session', 'workout-reminder']);
  });

  it('meals while learning (fewer than 7 days logged): every meal at its default, 9:00 / 14:00 / 21:00', () => {
    const meals = learnMeals({ timeZone: TZ, foodLogs: [] });
    expect(meals.map((m) => [m.kind, m.minute === null ? null : formatClock(m.minute)])).toEqual([
      ['meal-breakfast', '09:00'],
      ['meal-lunch', '14:00'],
      ['meal-dinner', '21:00'],
    ]);
    expect(meals[0]!.why).toContain('learns');
  });

  it("meals once learned: half an hour after this person's usual time; a meal they usually skip gets none", () => {
    const days = Array.from({ length: 10 }, (_, i) => addDays('2026-10-18', -i));
    const foodLogs = days.flatMap((d, i) => [
      { slot: 'lunch' as const, localDate: d, at: ist(d, i % 2 === 0 ? '13:10' : '13:30') },
      { slot: 'dinner' as const, localDate: d, at: ist(d, '20:15') },
      ...(i < 3 ? [{ slot: 'breakfast' as const, localDate: d, at: ist(d, '08:00') }] : []),
    ]);
    const meals = learnMeals({ timeZone: TZ, foodLogs });
    const byKind = Object.fromEntries(meals.map((m) => [m.kind, m]));
    expect(byKind['meal-breakfast']!.minute).toBeNull();
    expect(byKind['meal-breakfast']!.why).toContain('fewer than half');
    expect(formatClock(byKind['meal-lunch']!.minute!)).toBe('13:50');
    expect(formatClock(byKind['meal-dinner']!.minute!)).toBe('20:45');
    expect(byKind['meal-dinner']!.why).toContain('20:15');

    const plan = planNotifications(facts({ settings: onlyKinds('meal-breakfast', 'meal-lunch', 'meal-dinner'), foodLogs }));
    const tomorrow = plan.filter((p) => p.localDate === '2026-10-20');
    expect(tomorrow.map((p) => p.kind)).toEqual(['meal-lunch', 'meal-dinner']);
    expect(tomorrow[0]!.slot).toBe('lunch');
    expect(tomorrow[0]!.screen).toBe('food-log');
    expect(tomorrow[0]!.cancelOn).toEqual([{ event: 'food-logged', localDate: '2026-10-20', grams: null, slot: 'lunch' }]);
  });

  it('a meal already logged today gets no reminder today', () => {
    const now = ist('2026-10-19', '10:00');
    const lunch = { slot: 'lunch' as const, localDate: '2026-10-19', at: ist('2026-10-19', '09:45') };
    const today = planNotifications(facts({ now, settings: onlyKinds('meal-lunch', 'meal-dinner'), foodLogs: [lunch] })).filter((p) => p.localDate === '2026-10-19');
    expect(today.map((p) => p.kind)).toEqual(['meal-dinner']);
  });
});
