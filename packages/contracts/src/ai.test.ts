import { describe, expect, it } from 'vitest';

import {
  aiActionSchema,
  aiStatusResponseSchema,
  explainRequestSchema,
  explainResponseSchema,
  PHOTO_MAX_BASE64,
  parseFoodPhotoRequestSchema,
  parseFoodPhotoResponseSchema,
  parseFoodRequestSchema,
  parseFoodResponseSchema,
} from './ai.js';
import { programRequestSchema } from './training.js';

describe('ai status (Phase 6.6)', () => {
  it('states configured / provider / model and what the assistant never sees', () => {
    expect(
      aiStatusResponseSchema.parse({ enabled: true, configured: false, provider: 'none', model: null, excludes: ['health-connect', 'food-log'] }),
    ).toMatchObject({ configured: false });
    expect(aiStatusResponseSchema.safeParse({ enabled: true, configured: true, provider: 'gemini', model: 'gemini-3.6-flash', excludes: ['steps'] }).success).toBe(false);
    // Phase 14: the kill switch is always stated.
    expect(aiStatusResponseSchema.safeParse({ configured: true, provider: 'gemini', model: 'm', excludes: [] }).success).toBe(false);
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

describe('Phase 14 drafts (§19.2)', () => {
  const row = {
    basis: 'per_serving', servingLabel: '1 piece', servingGrams: 40,
    kcalLow: 110, kcalHigh: 130, proteinLow: 3, proteinHigh: 4, carbLow: 20, carbHigh: 24, fatLow: 1, fatHigh: 3,
    fibreLow: null, fibreHigh: null, confidence: 'medium',
  };
  const snapshot = { kcalLow: 220, kcalHigh: 260, proteinLow: 6, proteinHigh: 8, carbLow: 40, carbHigh: 48, fatLow: 2, fatHigh: 6 };
  const draft = {
    data: {
      items: [
        {
          phrase: '2 rotis', quantity: 2, unit: 'piece', confidence: 'high',
          match: { foodId: '11111111-1111-4111-8111-111111111111', name: 'Chapati', matchKind: 'alias', basis: 'per_serving', servingLabel: '1 piece', servings: 2, row, snapshot },
          estimate: null, problem: null,
        },
        { phrase: 'a mystery sweet', quantity: 1, unit: 'piece', confidence: 'low', match: null, estimate: { name: 'Mystery sweet', grams: 50, kcal: 210, proteinG: 3, carbG: 28, fatG: 10 }, problem: null },
        { phrase: 'something odd', quantity: 1, unit: 'serving', confidence: 'low', match: null, estimate: null, problem: 'more than 900 kcal per 100 g' },
      ],
    },
    confidence: 'low', source: 'ai-draft', requiresConfirmation: true,
  };

  it('a parse request is the text alone', () => {
    expect(parseFoodRequestSchema.parse({ text: ' 2 rotis and dal ' })).toEqual({ text: '2 rotis and dal' });
    for (const bad of [{ text: 'x' }, { text: 'a'.repeat(501) }, { text: 'dal', userId: 'u' }]) {
      expect(parseFoodRequestSchema.safeParse(bad).success, JSON.stringify(bad)).toBe(false);
    }
  });

  it('a draft is always ai-draft and always requires confirmation', () => {
    expect(parseFoodResponseSchema.safeParse({ draft, model: 'gemini-x' }).success).toBe(true);
    expect(parseFoodResponseSchema.safeParse({ draft: { ...draft, requiresConfirmation: false }, model: 'm' }).success).toBe(false);
    expect(parseFoodResponseSchema.safeParse({ draft: { ...draft, source: 'database' }, model: 'm' }).success).toBe(false);
    expect(parseFoodResponseSchema.safeParse({ draft: { ...draft, data: { items: [], loggedId: 'x' } }, model: 'm' }).success).toBe(false);
  });

  it('beta 5.5: a photo request is the photo (base64, a known type, ≤ 1.5 MB), the meal and optionally the day', () => {
    const ok = { image: 'AAAAAAAAAAAAAAAAAAAA', mimeType: 'image/jpeg', slot: 'lunch' };
    expect(parseFoodPhotoRequestSchema.safeParse(ok).success).toBe(true);
    expect(parseFoodPhotoRequestSchema.safeParse({ ...ok, date: '2026-11-04' }).success).toBe(true);
    for (const bad of [
      { ...ok, image: 'data:image/jpeg;base64,AAAA' },
      { ...ok, image: 'A'.repeat(PHOTO_MAX_BASE64 + 4) },
      { ...ok, mimeType: 'image/gif' },
      { ...ok, slot: 'brunch' },
      { ...ok, text: 'dal' },
    ]) {
      expect(parseFoodPhotoRequestSchema.safeParse(bad).success, JSON.stringify(bad).slice(0, 80)).toBe(false);
    }
  });

  it('beta 5.5: a mess dish line, and the menu it is logged against', () => {
    const macros = { kcalLow: 100, kcalHigh: 120, proteinLow: 3, proteinHigh: 4, carbLow: 20, carbHigh: 22, fatLow: 1, fatHigh: 2 };
    const messDish = { dishSlug: 'white-rice', name: 'White Rice', servingLabel: '1 plate', servings: 1.5, perServing: macros, snapshot: macros };
    const line = { phrase: 'rice', quantity: 1.5, unit: 'serving', confidence: 'medium', match: null, messDish, estimate: null, problem: null };
    const photo = { draft: { ...draft, data: { items: [line] } }, mess: { code: 'mens-veg', menuDate: '2026-11-04' }, model: 'm' };
    expect(parseFoodPhotoResponseSchema.safeParse(photo).success).toBe(true);
    expect(parseFoodPhotoResponseSchema.safeParse({ ...photo, mess: null }).success).toBe(true);
    expect(parseFoodPhotoResponseSchema.safeParse({ ...photo, draft: { ...draft, data: { items: [{ ...line, messDish: { ...messDish, servings: 11 } }] } } }).success).toBe(false);
    // A text draft without the field reads it as no mess dish.
    expect(parseFoodResponseSchema.parse({ draft, model: 'm' }).draft.data.items[0]!.messDish).toBeNull();
  });

  it('explain: an action id in; AI words, or the engine words when they were discarded', () => {
    expect(explainRequestSchema.safeParse({ actionId: '11111111-1111-4111-8111-111111111111' }).success).toBe(true);
    expect(explainRequestSchema.safeParse({ actionId: 'x', text: 'say this' }).success).toBe(false);
    expect(explainResponseSchema.safeParse({ text: 'Eat a bit less.', source: 'ai', discarded: null }).success).toBe(true);
    expect(explainResponseSchema.safeParse({ text: 'engine words', source: 'engine', discarded: 'new-number' }).success).toBe(true);
    expect(explainResponseSchema.safeParse({ text: 'x', source: 'model', discarded: null }).success).toBe(false);
  });
});
