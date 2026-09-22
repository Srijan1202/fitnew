import { describe, expect, it } from 'vitest';

import { aiActionSchema, aiStatusResponseSchema } from './ai.js';
import { programRequestSchema } from './training.js';

describe('ai status (Phase 6.6)', () => {
  it('states configured / provider / model and what the assistant never sees', () => {
    expect(
      aiStatusResponseSchema.parse({ configured: false, provider: 'none', model: null, excludes: ['health-connect', 'food-log'] }),
    ).toMatchObject({ configured: false });
    expect(aiStatusResponseSchema.safeParse({ configured: true, provider: 'gemini', model: 'gemini-3.6-flash', excludes: ['steps'] }).success).toBe(false);
  });
});

describe('ai actions (Gate 5)', () => {
  it('apply-program carries the structured request the user must confirm; the request holds no exercises or sets', () => {
    const ok = aiActionSchema.parse({
      type: 'apply-program',
      label: 'Use this programme',
      programRequest: { template: 'bodybuilding-5', preferredSessionMinutes: 60, emphasis: ['chest', 'shoulders'] },
    });
    expect(ok.programRequest?.template).toBe('bodybuilding-5');
    expect(programRequestSchema.safeParse({ days: [] }).success).toBe(false);
    expect(programRequestSchema.safeParse({ emphasis: ['chest', 'back', 'quads', 'abs'] }).success).toBe(false);
    expect(programRequestSchema.safeParse({ emphasis: ['forearms'] }).success).toBe(false);
    expect(programRequestSchema.safeParse({ daysPerWeek: 7 }).success).toBe(false);
    expect(programRequestSchema.safeParse({}).success).toBe(true);
  });
});
