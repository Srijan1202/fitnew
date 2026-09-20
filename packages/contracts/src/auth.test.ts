import { describe, expect, it } from 'vitest';
import { createSessionRequestSchema, timeZoneSchema, userProfileSchema } from './auth.js';

describe('createSessionRequestSchema', () => {
  it('accepts an empty body from a first-launch client', () => {
    expect(createSessionRequestSchema.safeParse({}).success).toBe(true);
  });

  it('rejects a client-supplied userId — identity comes from the token only', () => {
    const r = createSessionRequestSchema.safeParse({ userId: 'abc' });
    expect(r.success).toBe(false);
  });

  it('accepts the modern IANA name every Indian device sends', () => {
    // Would fail against Intl.supportedValuesOf, which only lists Asia/Calcutta.
    expect(timeZoneSchema.safeParse('Asia/Kolkata').success).toBe(true);
    expect(timeZoneSchema.safeParse('Europe/Kyiv').success).toBe(true);
  });

  it('still accepts the legacy alias and UTC', () => {
    expect(timeZoneSchema.safeParse('Asia/Calcutta').success).toBe(true);
    expect(timeZoneSchema.safeParse('UTC').success).toBe(true);
    expect(timeZoneSchema.safeParse('Etc/UTC').success).toBe(true);
    expect(timeZoneSchema.safeParse('America/New_York').success).toBe(true);
  });

  it('rejects anything that would silently shift a day boundary', () => {
    for (const bad of ['IST', 'asia/kolkata', 'Asia/Kolkata ', 'Mars/Olympus', '', 'Asia']) {
      expect(timeZoneSchema.safeParse(bad).success, JSON.stringify(bad)).toBe(false);
    }
  });

  it('stores the name as sent, never ICU-canonicalised to the old spelling', () => {
    const r = timeZoneSchema.safeParse('Asia/Kolkata');
    expect(r.success && r.data).toBe('Asia/Kolkata');
  });
});

describe('userProfileSchema', () => {
  it('never carries a password or any credential field', () => {
    const keys = Object.keys(userProfileSchema.shape);
    expect(keys).not.toContain('password');
    expect(keys).not.toContain('passwordHash');
    expect(keys).not.toContain('firebaseUid');
  });
});
