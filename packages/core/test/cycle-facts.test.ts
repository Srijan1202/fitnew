import { describe, expect, it } from 'vitest';

import { planNotifications, type PlanFacts } from '../src/notify/planner.js';
import { instantAt } from '../src/notify/time.js';
import { DEFAULT_NOTIFY_SETTINGS, NOTIFY_KINDS } from '../src/notify/types.js';
import { streak, streakDays } from '../src/progress/streak.js';
import { dayNumberOn } from '../src/training/schedule.js';

const TZ = 'Asia/Kolkata';
const only = (...kinds: string[]) => ({
  ...DEFAULT_NOTIFY_SETTINGS,
  kinds: Object.fromEntries(NOTIFY_KINDS.map((k) => [k, kinds.includes(k)])) as typeof DEFAULT_NOTIFY_SETTINGS.kinds,
});
const facts = (over: Partial<PlanFacts>): PlanFacts => ({
  now: instantAt('2026-11-10', 9 * 60, TZ), // a Tuesday
  timeZone: TZ,
  seed: 'u',
  name: 'Srijan',
  settings: DEFAULT_NOTIFY_SETTINGS,
  programme: {},
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

describe('a cycle programme in the reminders and the streak (F2)', () => {
  // 4 on, 1 off from today: Push, Pull, Legs, Run, rest, Push, Pull, Legs.
  const byDate = {
    '2026-11-09': 'Legs',
    '2026-11-10': 'Push',
    '2026-11-11': 'Pull',
    '2026-11-12': 'Legs',
    '2026-11-13': 'Easy 5K',
    '2026-11-15': 'Push',
    '2026-11-16': 'Pull',
    '2026-11-17': 'Legs',
  };

  it('workout reminders follow the dates, with run words on a run date; the morning after a missed one names it', () => {
    // 06:00, before the morning's "missed session" goes out.
    const plan = planNotifications(facts({ now: instantAt('2026-11-10', 6 * 60, TZ), sessionsByDate: byDate, runDates: ['2026-11-13'], settings: only('workout-reminder', 'missed-session') }));
    const reminders = plan.filter((p) => p.kind === 'workout-reminder').map((p) => [p.localDate, p.title.includes('Push') || p.body.includes('Push') ? 'Push' : p.variant.startsWith('wr-r') ? 'run' : 'other']);
    // The horizon's last day is the quiet one (day 7 of no use says only "we'll stop").
    expect(reminders.map((r) => r[0])).toEqual(['2026-11-10', '2026-11-11', '2026-11-12', '2026-11-13', '2026-11-15', '2026-11-16']);
    expect(plan.find((p) => p.kind === 'workout-reminder' && p.localDate === '2026-11-13')!.variant.startsWith('wr-r')).toBe(true);
    // Yesterday's Legs was not logged.
    expect(plan.find((p) => p.kind === 'missed-session' && p.localDate === '2026-11-10')).toBeDefined();
  });

  it('no streak warning on the cycle\'s rest date; the recap counts the plan per week', () => {
    const sunday = instantAt('2026-11-15', 9 * 60, TZ);
    const plan = planNotifications(facts({ now: sunday, sessionsByDate: byDate, plannedPerWeek: 6, completedDates: ['2026-11-10', '2026-11-11'], settings: only('weekly-recap', 'streak-at-risk') }));
    expect(plan.some((p) => p.kind === 'weekly-recap')).toBe(true);
    const atRisk = planNotifications(facts({ sessionsByDate: byDate, settings: only('streak-at-risk') }));
    expect(atRisk.some((p) => p.localDate === '2026-11-14')).toBe(false);
  });

  it('the streak excuses the cycle\'s rest dates, not the weekdays', () => {
    const cycle = { kind: 'cycle' as const, start: '2026-11-01', length: 3 };
    const restDay = (d: string) => dayNumberOn(cycle, d) === 3;
    const active = new Set(['2026-11-01', '2026-11-02', '2026-11-04', '2026-11-05', '2026-11-07', '2026-11-08', '2026-11-10']);
    const input = { today: '2026-11-10', activeDays: active, restWeekdays: new Set([1, 2, 3, 4, 5, 6, 7]), skippedDays: new Set<string>(), firstDay: '2026-11-01', restDay };
    expect(streak(input).current).toBe(10);
    // 9 Nov is day 3 of the cycle (rest); a weekday rule would call every day rest.
    expect(streakDays(input, 3).map((d) => d.status)).toEqual(['logged', 'rest', 'logged']);
  });
});
