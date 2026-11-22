/**
 * Beta 6.5 (K3, C7, owner Q3): club vs club. One club's owner challenges
 * another for the coming week, Monday to Sunday; the other owner accepts
 * before it starts. The score is the average per member, over the members in
 * each club when the week starts, from each member's own week counts, so a
 * club's size does not decide it. Pure: the API counts and stores.
 */
import { addDays } from '../nutrition/log.js';
import { isoWeekday } from '../progress/streak.js';
import type { ChallengeMetric } from './challenge.js';

/** A finished match's result stays on the club's card for a week. */
export const MATCH_RESULT_SHOWN_DAYS = 7;

export type MatchResult = 'won' | 'lost' | 'drew';

const UNIT: Record<ChallengeMetric, string> = { sessions: 'sessions', distance: 'km', 'active-days': 'active days' };

/** The Monday of the week after the one `today` is in. */
export const nextWeekFrom = (today: string): string => addDays(today, 8 - isoWeekday(today));

/** Days left in the match's week, today included; 7 before it starts, 0 once over. */
export function matchDaysLeft(weekFrom: string, today: string): number {
  const weekTo = addDays(weekFrom, 6);
  if (today > weekTo) return 0;
  if (today < weekFrom) return 7;
  return Math.round((Date.parse(weekTo) - Date.parse(today)) / 86_400_000) + 1;
}

/** The week has started somewhere (UTC), so the members are fixed. */
export const matchWeekStarted = (weekFrom: string, utcToday: string): boolean => utcToday >= weekFrom;

/** The week is over in every time zone and every member's count is final: two days after its Sunday, in UTC. */
export const matchWeekOver = (weekFrom: string, utcToday: string): boolean => utcToday >= addDays(weekFrom, 8);

/** The average per member, in the metric's unit (km for distance), to 0.1. */
export function perMember(metric: ChallengeMetric, raw: number, members: number): number {
  if (members === 0) return 0;
  const avg = (metric === 'distance' ? raw / 1000 : raw) / members;
  return Math.round(avg * 10) / 10;
}

/** Won, lost or drew, by the shown averages. */
export const matchResult = (us: number, them: number): MatchResult => (us > them ? 'won' : us < them ? 'lost' : 'drew');

/** The one push a finished match sends each member (owner Q4), from their club's side. */
export function matchResultLine(club: string, other: string, metric: ChallengeMetric, us: number, them: number): { title: string; body: string } {
  const r = matchResult(us, them);
  const title = r === 'won' ? `${club} won against ${other}` : r === 'lost' ? `${club} lost to ${other}` : `${club} drew with ${other}`;
  return { title, body: `${us} to ${them} ${UNIT[metric]} per member.` };
}
