import { describe, expect, it } from 'vitest';

import {
  COUNTRIES,
  STORED_CONSENT_TYPES,
  CONSENT_TYPES,
  clubCodeSchema,
  clubNameSchema,
  handleProblem,
  handleSchema,
  hasBlockedWord,
  joinCommunitySchema,
  reportRequestSchema,
} from './index.js';

describe('community (beta 5.8, ADR-057)', () => {
  it('handles: 3–20 of a–z, 0–9 and _, the @ and capitals taken off', () => {
    expect(handleSchema.parse('@Srijan_Lifts')).toBe('srijan_lifts');
    expect(handleSchema.safeParse('ab').success).toBe(false);
    expect(handleSchema.safeParse('a'.repeat(21)).success).toBe(false);
    expect(handleSchema.safeParse('no spaces').success).toBe(false);
    expect(handleSchema.safeParse('émile').success).toBe(false);
  });

  it('reserved handles and anything passing for FITOS are refused', () => {
    expect(handleProblem('admin')).toBe('reserved');
    expect(handleProblem('fitos_team')).toBe('reserved');
    expect(handleProblem('srijan')).toBeNull();
  });

  it('blocked words, with letter swaps undone; innocent words that hold one pass', () => {
    expect(hasBlockedWord('fuckboy')).toBe(true);
    expect(hasBlockedWord('xx_f4ck')).toBe(false);
    expect(hasBlockedWord('big_fuuck')).toBe(false);
    expect(hasBlockedWord('mr_fuck')).toBe(true);
    expect(hasBlockedWord('sh1t_lifter')).toBe(true);
    expect(hasBlockedWord('ch00tiya')).toBe(false);
    expect(hasBlockedWord('chutiya99')).toBe(true);
    expect(hasBlockedWord('grapes_gym')).toBe(false);
    expect(hasBlockedWord('peacock')).toBe(false);
    expect(hasBlockedWord('dickens_reader')).toBe(true);
    expect(handleProblem('n1gga_lift')).toBe('word');
  });

  it('club names and codes', () => {
    expect(clubNameSchema.safeParse("VIT Men's Hostel (Block A)").success).toBe(true);
    expect(clubNameSchema.safeParse('Gold’s').success).toBe(false);
    expect(clubNameSchema.safeParse('ab').success).toBe(false);
    expect(clubNameSchema.safeParse('Shit Lifters').success).toBe(false);
    expect(clubCodeSchema.parse('abcd-ef23')).toBe('ABCDEF23');
    expect(clubCodeSchema.safeParse('ABCDEF0O').success).toBe(false);
  });

  it('countries: ISO codes with names; joining checks the code', () => {
    expect(COUNTRIES.IN).toBe('India');
    expect(COUNTRIES.DE).toBe('Germany');
    expect(Object.keys(COUNTRIES).length).toBeGreaterThan(240);
    const join = { handle: 'srijan', country: 'IN', onWorld: false, policyVersion: 'v' };
    expect(joinCommunitySchema.safeParse(join).success).toBe(true);
    expect(joinCommunitySchema.safeParse({ ...join, country: 'XX' }).success).toBe(false);
    expect(joinCommunitySchema.safeParse({ ...join, country: null }).success).toBe(true);
  });

  it('a report names one person or one club', () => {
    const u = '11111111-1111-4111-8111-111111111111';
    expect(reportRequestSchema.safeParse({ userId: u, reason: 'handle' }).success).toBe(true);
    expect(reportRequestSchema.safeParse({ reason: 'handle' }).success).toBe(false);
    expect(reportRequestSchema.safeParse({ userId: u, clubId: u, reason: 'other' }).success).toBe(false);
  });

  it('the community consent is stored but not on the Privacy list', () => {
    expect(STORED_CONSENT_TYPES).toContain('community');
    expect(CONSENT_TYPES as readonly string[]).not.toContain('community');
  });
});
