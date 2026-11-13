/**
 * Beta 6.3 (C1, C2, C3, C13): Community that talks — the feed's rules
 * (streak milestones, what may still be posted), the evening kudos push,
 * when a friend can be nudged, and the dates a board period covers. Pure:
 * the API reads the records and stores the posts.
 */
import { addDays } from '../nutrition/log.js';
import { isoWeekday } from '../progress/streak.js';

export const FEED_KINDS = ['session', 'run', 'record', 'streak'] as const;
export type FeedKind = (typeof FEED_KINDS)[number];

/** Streak lengths, in days, that make a post. */
export const STREAK_MILESTONES: readonly number[] = [7, 14, 30, 50, 100, 150, 200, 250, 300, 365, 500, 730, 1000];

/** How far back an event may still become a post (a late sync), in days. */
export const POST_CATCH_UP_DAYS = 2;

/** The feed shows the last 14 days; posts are deleted after 30. */
export const FEED_DAYS = 14;
export const POSTS_KEPT_DAYS = 30;

/**
 * The first local date an event may be posted from: the later of the day
 * sharing was switched on and the catch-up window.
 */
export const postFrom = (today: string, sharedSince: string): string => {
  const window = addDays(today, -POST_CATCH_UP_DAYS);
  return sharedSince > window ? sharedSince : window;
};

/**
 * The milestone this streak has passed, when it was reached on or after
 * `from` (local dates): the highest one, once per streak. `ref` names the
 * streak by its first day, so a new streak can reach 7 days again.
 */
export function streakPostDue(streak: number, today: string, from: string): { milestone: number; reachedOn: string; ref: string } | null {
  let milestone = 0;
  for (const m of STREAK_MILESTONES) if (m <= streak) milestone = m;
  if (milestone === 0) return null;
  const startedOn = addDays(today, 1 - streak);
  const reachedOn = addDays(startedOn, milestone - 1);
  if (reachedOn < from) return null;
  return { milestone, reachedOn, ref: `${milestone}:${startedOn}` };
}

/* --------------------------------------------------------------- kudos -- */

/** The evening summary goes between 19:00 and 23:00 local time, once a day. */
export const KUDOS_PUSH_FROM_HOUR = 19;
export const KUDOS_PUSH_UNTIL_HOUR = 23;

export const kudosPushDue = (localHour: number, today: string, pushedOn: string | null): boolean =>
  localHour >= KUDOS_PUSH_FROM_HOUR && localHour < KUDOS_PUSH_UNTIL_HOUR && pushedOn !== today;

/**
 * The summary's line, newest cheer first: "@asha cheered you.", "@asha and
 * @ravi cheered you.", "@asha and 3 others cheered you." (kudos after 23:00
 * wait for the next evening, so it does not say "today").
 */
export function kudosLine(handles: readonly string[]): string {
  const [first, second] = handles;
  if (first === undefined) return '';
  if (second === undefined) return `@${first} cheered you.`;
  if (handles.length === 2) return `@${first} and @${second} cheered you.`;
  return `@${first} and ${handles.length - 1} others cheered you.`;
}

/* --------------------------------------------------------------- nudges -- */

/** A friend can be nudged after 3 local days with nothing counted, once a week. */
export const NUDGE_QUIET_DAYS = 3;
export const NUDGE_EVERY_DAYS = 7;

export type NudgeState = 'can' | 'active' | 'sent';

/**
 * Whether the viewer can nudge a friend: `active` when the friend counted a
 * session or run in the last 3 local days (today included), `sent` when the
 * viewer nudged them in the last 7 days.
 */
export function nudgeState(lastActive: string | null, today: string, lastNudgedAt: Date | null, now: Date): NudgeState {
  if (lastNudgedAt !== null && now.getTime() - lastNudgedAt.getTime() < NUDGE_EVERY_DAYS * 86_400_000) return 'sent';
  if (lastActive !== null && lastActive > addDays(today, -NUDGE_QUIET_DAYS)) return 'active';
  return 'can';
}

/* -------------------------------------------------------------- periods -- */

export const BOARD_PERIODS = ['week', 'month', 'all'] as const;
export type BoardPeriod = (typeof BOARD_PERIODS)[number];

/**
 * The local dates a board period covers, to today: Monday of this week, the
 * 1st of this month, or the day the person joined Community (owner Q4).
 */
export function periodFrom(period: BoardPeriod, today: string, joinedOn: string): string {
  switch (period) {
    case 'week':
      return addDays(today, 1 - isoWeekday(today));
    case 'month':
      return `${today.slice(0, 7)}-01`;
    case 'all':
      return joinedOn < today ? joinedOn : today;
  }
}
