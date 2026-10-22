/**
 * Phase 15 — the notification planner (MASTER-SPEC §21, ADR-021).
 *
 * Given the user's own records it plans the next days of notifications:
 * which kinds, at what local time, in which words. The phone schedules the
 * plan on the device and cancels an item the moment its point is gone
 * (`cancelOn`: the workout was started, protein reached, a log made…).
 *
 * The techniques, all deterministic:
 *   - **Learned timing** — sent around when this user actually trains, eats
 *     and weighs in (the median of recent local times), not a fixed clock.
 *   - **Only when useful** — no workout reminder on a rest day or after the
 *     session; no protein nudge once protein is on track; nothing twice for
 *     the same day and kind.
 *   - **A daily cap and spacing** — at most DAILY_CAP a day, MIN_GAP_MINUTES
 *     apart, highest priority first; nothing in quiet hours.
 *   - **Back-off** — a kind ignored three times in a row goes to every other
 *     day; six times, it pauses for a week. Opening one, or doing the thing,
 *     resets it.
 *   - **Variety that learns** — never the same words for a kind within a
 *     week; among the fresh ones, the variant this user opens most wins
 *     (a Laplace-smoothed open rate), ties broken by a stable hash.
 *   - **Comeback** — if the app is not opened again, nudges on day 2 and 4,
 *     and on day 7 a last one that says reminders stop for now.
 *   - **Readiness-aware** — a low-readiness day is spoken to gently, and a
 *     rest-band day gets no workout reminder (§18: advice, never pressure).
 */
import { addDays, localDateOf } from '../nutrition/log.js';
import { TEMPLATES, fits, render, type CopyData, type Template } from './copy.js';
import { daysBetween, formatClock, inWindow, instantAt, isoWeekday, minuteOfDay, parseClock, usualMinute } from './time.js';
import {
  DAILY_CAP,
  HORIZON_DAYS,
  MIN_GAP_MINUTES,
  PROTEIN_GAP_SHARE,
  type CancelEvent,
  type NotifyKind,
  type NotifyScreen,
  type NotifySettings,
  type NotifyTone,
} from './types.js';

export type ReadinessBand = 'ready' | 'advisory' | 'reduce' | 'rest';

export interface NotifyHistoryItem {
  readonly kind: NotifyKind;
  readonly localDate: string;
  readonly variant: string;
  readonly at: Date;
  readonly status: 'planned' | 'delivered' | 'opened' | 'cancelled';
}

export interface PlanFacts {
  readonly now: Date;
  readonly timeZone: string;
  /** Stable per user (the user id): breaks ties between variants. */
  readonly seed: string;
  readonly name: string | null;
  readonly settings: NotifySettings;
  /** ISO weekday (1–7) → session name, training days only; null without a programme. */
  readonly programme: Readonly<Record<number, string>> | null;
  /** Recent session starts (about four weeks). */
  readonly sessionStarts: readonly Date[];
  /** Local dates with a completed session (about five weeks). */
  readonly completedDates: readonly string[];
  readonly foodLogs: readonly { readonly at: Date; readonly slot: 'breakfast' | 'lunch' | 'snacks' | 'dinner'; readonly localDate: string }[];
  readonly weighIns: readonly { readonly at: Date; readonly localDate: string }[];
  readonly checkIns: readonly { readonly at: Date; readonly localDate: string }[];
  /** Local dates whose protein reached PROTEIN_GAP_SHARE of the target. */
  readonly proteinMetDates: readonly string[];
  readonly proteinTargetG: number | null;
  /** Today's protein so far (the high end of the range). */
  readonly todayProteinHigh: number;
  readonly readinessBand: ReadinessBand | null;
  /** Notifications already planned or sent (about five weeks). */
  readonly history: readonly NotifyHistoryItem[];
}

export interface CancelRule {
  readonly event: CancelEvent;
  readonly localDate: string;
  /** protein-reached only: the grams that make the nudge pointless. */
  readonly grams: number | null;
}

export interface PlannedNotification {
  readonly kind: NotifyKind;
  readonly localDate: string;
  readonly at: Date;
  readonly title: string;
  readonly body: string;
  readonly variant: string;
  readonly tone: NotifyTone;
  readonly screen: NotifyScreen;
  readonly slot: 'dinner' | null;
  readonly actions: readonly 'snooze'[];
  readonly cancelOn: readonly CancelRule[];
  /** Why this, why now — shown in settings so the timing is never a mystery. */
  readonly why: string;
  readonly priority: number;
}

/** Defaults until a habit has been seen a few times. */
export const DEFAULT_MINUTES = {
  training: 18 * 60,
  morning: 8 * 60 + 30,
  dinner: 19 * 60,
  streak: 21 * 60,
  weighIn: 7 * 60 + 45,
  checkIn: 8 * 60 + 15,
  recap: 16 * 60,
  comeback: 12 * 60 + 30,
} as const;

const PRIORITY: Readonly<Record<NotifyKind, number>> = {
  // Comeback outranks everything: it only fires if the app is not opened,
  // and opening it rebuilds the plan with the ordinary reminders.
  comeback: 95,
  'workout-reminder': 90,
  'missed-session': 80,
  'protein-gap': 70,
  'streak-at-risk': 60,
  'weekly-recap': 50,
  'weigh-in': 40,
  'recovery-checkin': 35,
};

/** Kinds moved to the end of quiet hours (mornings); the rest move before their start. */
const MORNING: ReadonlySet<NotifyKind> = new Set(['missed-session', 'weigh-in', 'recovery-checkin']);

/** FNV-1a: a stable small hash for tie-breaks. */
function hash(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h;
}

const clamp = (v: number, lo: number, hi: number): number => Math.min(hi, Math.max(lo, v));

/** Habits learned from the user's own records. */
export interface Habits {
  /** Usual session start per ISO weekday, else overall; null until learned. */
  readonly training: (weekday: number) => number | null;
  readonly breakfast: number | null;
  readonly dinner: number | null;
  readonly weighIn: number | null;
  readonly checkIn: number | null;
}

export function learnHabits(facts: Pick<PlanFacts, 'timeZone' | 'sessionStarts' | 'foodLogs' | 'weighIns' | 'checkIns'>): Habits {
  const tz = facts.timeZone;
  const starts = facts.sessionStarts.map((d) => ({ minute: minuteOfDay(d, tz), weekday: isoWeekday(localDateOf(d, tz)) }));
  const overall = usualMinute(starts.map((s) => s.minute));
  const slot = (s: 'breakfast' | 'dinner'): number | null => usualMinute(facts.foodLogs.filter((f) => f.slot === s).map((f) => minuteOfDay(f.at, tz)));
  return {
    training: (weekday) => usualMinute(starts.filter((s) => s.weekday === weekday).map((s) => s.minute), 2) ?? overall,
    breakfast: slot('breakfast'),
    dinner: slot('dinner'),
    weighIn: usualMinute(facts.weighIns.map((w) => minuteOfDay(w.at, tz))),
    checkIn: usualMinute(facts.checkIns.map((c) => minuteOfDay(c.at, tz))),
  };
}

/** Consecutive active days ending on `date` (0 when `date` was not active). */
export function streakEnding(active: ReadonlySet<string>, date: string): number {
  let n = 0;
  for (let d = date; active.has(d); d = addDays(d, -1)) n++;
  return n;
}

/** Whether the point of a sent notification was met that day (so it was not "ignored"). */
function goalMet(kind: NotifyKind, date: string, sets: FactSets): boolean {
  switch (kind) {
    case 'workout-reminder':
    case 'missed-session':
      return sets.completed.has(date);
    case 'protein-gap':
      return sets.proteinMet.has(date);
    case 'streak-at-risk':
      return sets.active.has(date);
    case 'weigh-in':
      return sets.weighed.has(date);
    case 'recovery-checkin':
      return sets.checkedIn.has(date);
    case 'weekly-recap':
    case 'comeback':
      return false;
  }
}

interface FactSets {
  readonly completed: ReadonlySet<string>;
  readonly proteinMet: ReadonlySet<string>;
  readonly active: ReadonlySet<string>;
  readonly weighed: ReadonlySet<string>;
  readonly checkedIn: ReadonlySet<string>;
}

/** Sends of a kind in a row, newest first, that were neither opened nor followed by the thing itself. */
export function ignoredInARow(kind: NotifyKind, history: readonly NotifyHistoryItem[], sets: FactSets): { count: number; lastSent: string | null } {
  const sent = history
    .filter((h) => h.kind === kind && (h.status === 'delivered' || h.status === 'opened'))
    .sort((a, b) => b.at.getTime() - a.at.getTime());
  let count = 0;
  for (const h of sent) {
    if (h.status === 'opened' || goalMet(kind, h.localDate, sets)) break;
    count++;
  }
  return { count, lastSent: sent[0]?.localDate ?? null };
}

interface Candidate {
  readonly kind: NotifyKind;
  readonly minute: number;
  readonly data: CopyData;
  readonly stage?: 2 | 4 | 7;
  readonly screen: NotifyScreen;
  readonly slot: 'dinner' | null;
  readonly cancelOn: readonly CancelRule[];
  readonly why: string;
}

/** The variant for one send: fresh words first, then this user's best open rate, then a stable hash. */
export function chooseVariant(
  kind: NotifyKind,
  tone: NotifyTone,
  data: CopyData,
  stage: 2 | 4 | 7 | undefined,
  used: readonly { readonly variant: string; readonly localDate: string; readonly status: string; readonly kind: NotifyKind }[],
  date: string,
  seed: string,
): Template | null {
  const pool = TEMPLATES.filter((t) => t.kind === kind && t.tone === tone && t.stage === stage && fits(t, data));
  if (pool.length === 0) return null;
  const recent = new Set(
    used.filter((u) => u.kind === kind && Math.abs(daysBetween(u.localDate, date)) < 7).map((u) => u.variant),
  );
  const fresh = pool.filter((t) => !recent.has(t.id));
  const choices = fresh.length > 0 ? fresh : pool;
  // The user's open rate (Laplace-smoothed); words that use their own data
  // ("5 days", "Legs") get a small head start, so they lead until the
  // evidence says otherwise.
  const score = (t: Template): number => {
    const mine = used.filter((u) => u.variant === t.id && (u.status === 'delivered' || u.status === 'opened'));
    const opens = mine.filter((u) => u.status === 'opened').length;
    return (opens + 1) / (mine.length + 2) + ((t.needs ?? []).length > 0 ? 0.05 : 0);
  };
  const best = Math.max(...choices.map(score));
  const top = choices.filter((c) => score(c) === best);
  return top[hash(`${seed}|${date}|${kind}`) % top.length]!;
}

const at = (m: number): string => formatClock(m);

/** The plan: today (what is still ahead) and the next HORIZON_DAYS days. */
export function planNotifications(facts: PlanFacts): PlannedNotification[] {
  const s = facts.settings;
  if (!s.enabled) return [];
  const tz = facts.timeZone;
  const today = localDateOf(facts.now, tz);
  const nowMinute = minuteOfDay(facts.now, tz);
  const quietStart = parseClock(s.quietStart) ?? 22 * 60 + 30;
  const quietEnd = parseClock(s.quietEnd) ?? 7 * 60 + 30;
  const habits = learnHabits(facts);

  const sets: FactSets = {
    completed: new Set(facts.completedDates),
    proteinMet: new Set(facts.proteinMetDates),
    weighed: new Set(facts.weighIns.map((w) => w.localDate)),
    checkedIn: new Set(facts.checkIns.map((c) => c.localDate)),
    active: new Set([
      ...facts.completedDates,
      ...facts.foodLogs.map((f) => f.localDate),
      ...facts.weighIns.map((w) => w.localDate),
      ...facts.checkIns.map((c) => c.localDate),
    ]),
  };
  const lastWeighIn = [...sets.weighed].sort().at(-1) ?? null;
  const proteinGoal = facts.proteinTargetG === null ? null : Math.ceil(facts.proteinTargetG * PROTEIN_GAP_SHARE);

  // Back-off state per kind; `lastSent` advances as this plan schedules.
  const backoff = new Map<NotifyKind, { count: number; lastSent: string | null }>();
  for (const k of Object.keys(PRIORITY) as NotifyKind[]) backoff.set(k, ignoredInARow(k, facts.history, sets));
  const allowedByBackoff = (kind: NotifyKind, date: string): boolean => {
    if (kind === 'comeback') return true;
    const b = backoff.get(kind)!;
    if (b.lastSent === null) return true;
    const gap = daysBetween(b.lastSent, date);
    if (b.count >= 6) return gap >= 7;
    if (b.count >= 3) return gap >= 2;
    return true;
  };

  const used: { variant: string; localDate: string; status: string; kind: NotifyKind }[] = facts.history.map((h) => ({ ...h }));
  const out: PlannedNotification[] = [];

  const trainingWhy = (m: number | null): string =>
    m === null
      ? 'An hour before 18:00, until FITOS learns when you usually train.'
      : `About an hour before you usually start training (around ${at(m)} lately).`;

  for (let i = 0; i <= HORIZON_DAYS; i++) {
    const d = addDays(today, i);
    const weekday = isoWeekday(d);
    const done = facts.history.filter((h) => h.localDate === d && h.status !== 'planned');
    const taken = new Set(done.map((h) => h.kind));
    const sentTimes = done.filter((h) => h.status !== 'cancelled').map((h) => minuteOfDay(h.at, tz));
    const lowToday = i === 0 && (facts.readinessBand === 'reduce' || facts.readinessBand === 'rest');
    const tone: NotifyTone = lowToday ? 'gentle' : s.tone;
    const candidates: Candidate[] = [];

    // Day 7 of no app use is the last word: "we'll stop for now" and nothing else.
    const silentAfterStop = i === HORIZON_DAYS;

    const session = facts.programme?.[weekday] ?? null;
    if (!silentAfterStop && session !== null && !sets.completed.has(d) && !(i === 0 && facts.readinessBand === 'rest')) {
      const learned = habits.training(weekday);
      candidates.push({
        kind: 'workout-reminder',
        minute: (learned ?? DEFAULT_MINUTES.training) - 60,
        data: { name: facts.name, session },
        screen: 'plan',
        slot: null,
        cancelOn: [{ event: 'workout-started', localDate: d, grams: null }],
        why: trainingWhy(learned),
      });
    }

    const prev = addDays(d, -1);
    const missed = facts.programme?.[isoWeekday(prev)] ?? null;
    if (!silentAfterStop && missed !== null && !sets.completed.has(prev)) {
      candidates.push({
        kind: 'missed-session',
        minute: clamp(habits.breakfast ?? DEFAULT_MINUTES.morning, 7 * 60, 11 * 60),
        data: { name: facts.name, session: missed },
        screen: 'plan',
        slot: null,
        cancelOn: [
          { event: 'workout-completed', localDate: prev, grams: null },
          { event: 'workout-started', localDate: d, grams: null },
        ],
        why: `The morning after a planned ${missed} that has not been logged.`,
      });
    }

    if (!silentAfterStop && proteinGoal !== null && !(i === 0 && facts.todayProteinHigh >= proteinGoal)) {
      const learned = habits.dinner;
      candidates.push({
        kind: 'protein-gap',
        minute: clamp((learned ?? DEFAULT_MINUTES.dinner + 45) - 45, 17 * 60, 21 * 60),
        data: { name: facts.name, target: facts.proteinTargetG },
        screen: 'food-log',
        slot: 'dinner',
        cancelOn: [{ event: 'protein-reached', localDate: d, grams: proteinGoal }],
        why:
          learned === null
            ? 'Before dinner, only while protein is under three quarters of your target.'
            : `Before you usually log dinner (around ${at(learned)}), only while protein is under three quarters of your target.`,
      });
    }

    if (!silentAfterStop && !(i === 0 && sets.active.has(d))) {
      const streak = i === 0 ? streakEnding(sets.active, addDays(d, -1)) : null;
      candidates.push({
        kind: 'streak-at-risk',
        minute: Math.min(DEFAULT_MINUTES.streak, quietStart - 60),
        data: { name: facts.name, streak: streak !== null && streak >= 2 ? streak : null },
        screen: 'today',
        slot: null,
        cancelOn: [{ event: 'any-activity', localDate: d, grams: null }],
        why: 'In the evening, only when nothing has been logged that day.',
      });
    }

    if (!silentAfterStop && (lastWeighIn === null || daysBetween(lastWeighIn, d) >= 3) && !sets.weighed.has(d)) {
      const learned = habits.weighIn;
      candidates.push({
        kind: 'weigh-in',
        minute: learned ?? DEFAULT_MINUTES.weighIn,
        data: { name: facts.name },
        screen: 'progress',
        slot: null,
        cancelOn: [{ event: 'weight-logged', localDate: d, grams: null }],
        why: learned === null ? 'In the morning, after two or more days without a reading.' : `Around your usual weigh-in (${at(learned)}), after two or more days without one.`,
      });
    }

    if (!silentAfterStop && !sets.checkedIn.has(d)) {
      const learned = habits.checkIn;
      candidates.push({
        kind: 'recovery-checkin',
        minute: learned ?? DEFAULT_MINUTES.checkIn,
        data: { name: facts.name },
        screen: 'progress',
        slot: null,
        cancelOn: [{ event: 'checkin-logged', localDate: d, grams: null }],
        why: learned === null ? 'In the morning, until you have checked in that day.' : `Around your usual check-in (${at(learned)}).`,
      });
    }

    if (!silentAfterStop && weekday === 7) {
      let planned: number | null = null;
      let sessions: number | null = null;
      if (i === 0 && facts.programme !== null) {
        planned = Object.keys(facts.programme).length;
        sessions = facts.completedDates.filter((c) => daysBetween(c, d) >= 0 && daysBetween(c, d) <= 6).length;
      }
      candidates.push({
        kind: 'weekly-recap',
        minute: DEFAULT_MINUTES.recap,
        data: { name: facts.name, sessions, planned: planned === 0 ? null : planned },
        screen: 'progress',
        slot: null,
        cancelOn: [],
        why: 'Sunday afternoon: the week in one screen.',
      });
    }

    if (i === 2 || i === 4 || i === 7) {
      candidates.push({
        kind: 'comeback',
        // Midday, apart from the evening reminders.
        minute: DEFAULT_MINUTES.comeback,
        data: { name: facts.name },
        stage: i as 2 | 4 | 7,
        screen: 'today',
        slot: null,
        // Opening the app at all after this plan was made cancels it.
        cancelOn: [{ event: 'app-opened', localDate: today, grams: null }],
        why: `Only if FITOS is not opened for ${i} days.`,
      });
    }

    // Settings, already-handled kinds, back-off; then quiet hours and the past.
    const ready = candidates
      .filter((c) => s.kinds[c.kind] && !taken.has(c.kind) && allowedByBackoff(c.kind, d))
      .map((c) => {
        let minute = ((c.minute % 1440) + 1440) % 1440;
        if (inWindow(minute, quietStart, quietEnd)) minute = MORNING.has(c.kind) ? quietEnd : quietStart - 30;
        return { ...c, minute };
      })
      .filter((c) => !inWindow(c.minute, quietStart, quietEnd) && (i > 0 || c.minute > nowMinute + 2))
      .sort((a, b) => PRIORITY[b.kind] - PRIORITY[a.kind]);

    const chosen: number[] = [...sentTimes];
    for (const c of ready) {
      if (chosen.length >= DAILY_CAP) break;
      if (chosen.some((m) => Math.abs(m - c.minute) < MIN_GAP_MINUTES)) continue;
      const template = chooseVariant(c.kind, tone, c.data, c.stage, used, d, facts.seed);
      // Ready candidates are kinds with a usable variant; this is the guard.
      /* v8 ignore next -- @preserve */
      if (template === null) continue;
      chosen.push(c.minute);
      used.push({ variant: template.id, localDate: d, status: 'planned', kind: c.kind });
      const b = backoff.get(c.kind)!;
      backoff.set(c.kind, { ...b, lastSent: d });
      const words = render(template, c.data);
      out.push({
        kind: c.kind,
        localDate: d,
        at: instantAt(d, c.minute, tz),
        title: words.title,
        body: words.body,
        variant: template.id,
        tone: template.tone,
        screen: c.screen,
        slot: c.slot,
        actions: c.kind === 'weekly-recap' || c.kind === 'comeback' ? [] : ['snooze'],
        cancelOn: c.cancelOn,
        why: c.why,
        priority: PRIORITY[c.kind],
      });
    }
  }
  return out.sort((a, b) => a.at.getTime() - b.at.getTime());
}
