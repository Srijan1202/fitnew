import { describe, expect, it } from 'vitest';

import { aiStatusResponseSchema } from './ai.js';

describe('ai status (Phase 6.6)', () => {
  it('states configured / provider / model and what the assistant never sees', () => {
    expect(
      aiStatusResponseSchema.parse({ configured: false, provider: 'none', model: null, excludes: ['health-connect', 'food-log'] }),
    ).toMatchObject({ configured: false });
    expect(aiStatusResponseSchema.safeParse({ configured: true, provider: 'gemini', model: 'gemini-3.6-flash', excludes: ['steps'] }).success).toBe(false);
  });
});
