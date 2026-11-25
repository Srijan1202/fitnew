import { describe, expect, it } from 'vitest';

import {
  LEAGUE_METRIC,
  LEAGUE_MIN_MEMBERS,
  LEAGUE_SEASON_WEEKS,
  LEAGUE_TABLE_SHOWN,
  POINTS,
  inSeason,
  isPairingDay,
  leagueOrder,
  metSet,
  nextSeasonFrom,
  ordinal,
  pairClubs,
  seasonEnd,
  seasonEndLine,
  seasonWeek,
  type TableRow,
} from '../src/community/league.js';

const never = () => false;

describe('the club league (beta 6.6, L1)', () => {
  it('the owner’s choices', () => {
    expect(LEAGUE_METRIC).toBe('active-days');
    expect(LEAGUE_MIN_MEMBERS).toBe(3);
    expect(LEAGUE_SEASON_WEEKS).toBe(4);
    expect(LEAGUE_TABLE_SHOWN).toBe(5);
    expect(POINTS).toEqual({ won: 3, drew: 1, lost: 0, bye: 1 });
  });

  it('seasons are 4 weeks, back to back; pairing is on Saturdays (UTC)', () => {
    expect(seasonEnd('2026-11-30')).toBe('2026-12-27');
    expect(nextSeasonFrom('2026-11-30')).toBe('2026-12-28');
    expect(inSeason('2026-11-30', '2026-12-21')).toBe(true);
    expect(inSeason('2026-11-30', '2026-12-28')).toBe(false);
    expect(inSeason('2026-11-30', '2026-11-23')).toBe(false);
    expect(seasonWeek('2026-11-30', '2026-11-30')).toBe(1);
    expect(seasonWeek('2026-11-30', '2026-12-21')).toBe(4);
    expect(isPairingDay('2026-11-28')).toBe(true);
    expect(isPairingDay('2026-11-29')).toBe(false);
  });

  it('pairs like with like, highest first', () => {
    const clubs = [
      { id: 'a', avg: 4, byes: 0 },
      { id: 'b', avg: 1, byes: 0 },
      { id: 'c', avg: 3.8, byes: 0 },
      { id: 'd', avg: 1.2, byes: 0 },
    ];
    expect(pairClubs(clubs, new Set(), never)).toEqual({ pairs: [['a', 'c'], ['d', 'b']], byes: [] });
  });

  it('equal averages go by id', () => {
    const clubs = [
      { id: 'd', avg: 2, byes: 0 },
      { id: 'c', avg: 2, byes: 0 },
      { id: 'b', avg: 2, byes: 0 },
      { id: 'a', avg: 2, byes: 0 },
    ];
    expect(pairClubs(clubs, new Set(), never).pairs).toEqual([['a', 'b'], ['c', 'd']]);
  });

  it('an odd number: the fewest byes sits out, then the lowest id', () => {
    const clubs = [
      { id: 'a', avg: 4, byes: 1 },
      { id: 'b', avg: 3, byes: 0 },
      { id: 'c', avg: 2, byes: 0 },
    ];
    expect(pairClubs(clubs, new Set(), never)).toEqual({ pairs: [['a', 'c']], byes: ['b'] });
  });

  it('no rematch in the season when another club is free; a rematch over a bye', () => {
    const clubs = [
      { id: 'a', avg: 4, byes: 0 },
      { id: 'b', avg: 3.9, byes: 0 },
      { id: 'c', avg: 1, byes: 0 },
      { id: 'd', avg: 0.5, byes: 0 },
    ];
    const met = metSet([['b', 'a']]);
    expect(pairClubs(clubs, met, never).pairs).toEqual([['a', 'c'], ['b', 'd']]);
    expect(pairClubs(clubs.slice(0, 2), met, never).pairs).toEqual([['a', 'b']]);
  });

  it('never across a block; a club with nobody left has a bye', () => {
    const clubs = [
      { id: 'a', avg: 4, byes: 0 },
      { id: 'b', avg: 3, byes: 0 },
    ];
    const blocked = (x: string, y: string) => [x, y].sort().join() === 'a,b';
    expect(pairClubs(clubs, new Set(), blocked)).toEqual({ pairs: [], byes: ['a', 'b'] });
    expect(pairClubs([], new Set(), never)).toEqual({ pairs: [], byes: [] });
  });

  it('the table: points, then the average per match, then fewer matches, then the name; level clubs share a place', () => {
    const row = (clubId: string, points: number, played: number, scoreSum: number, name = clubId): TableRow => ({
      clubId,
      name,
      played,
      won: 0,
      drawn: 0,
      lost: 0,
      points,
      scoreSum,
    });
    const t = leagueOrder([row('a', 6, 3, 9), row('b', 7, 3, 6), row('c', 6, 3, 12), row('d', 6, 2, 6), row('e', 6, 2, 6, 'aa'), row('f', 0, 0, 0)]);
    expect(t.map((r) => [r.clubId, r.place])).toEqual([
      ['b', 1],
      ['c', 2],
      ['e', 3],
      ['d', 3],
      ['a', 5],
      ['f', 6],
    ]);
    // Level on points and average, but fewer matches is higher, and not level.
    expect(leagueOrder([row('g', 6, 4, 12), row('h', 6, 2, 6)]).map((r) => [r.clubId, r.place])).toEqual([
      ['h', 1],
      ['g', 2],
    ]);
    // New clubs with no match yet are level.
    expect(leagueOrder([row('j', 0, 0, 0), row('i', 0, 0, 0)]).map((r) => [r.clubId, r.place])).toEqual([
      ['i', 1],
      ['j', 1],
    ]);
  });

  it('places in words, and the season-end push', () => {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101, 111].map(ordinal)).toEqual([
      '1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd', '101st', '111th',
    ]);
    expect(seasonEndLine('Hostel A', 2, 14)).toEqual({
      title: 'Hostel A finished 2nd in the league',
      body: 'Out of 14 clubs this season. A new season starts on Monday.',
    });
  });
});
