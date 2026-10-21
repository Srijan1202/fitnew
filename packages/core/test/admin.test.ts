import { describe, expect, it } from 'vitest';

import {
  FAILING_AFTER,
  STALE_AFTER_HOURS,
  applyCorrection,
  applyDietOverrides,
  endpointHealth,
  notificationRates,
  rate,
  recommendationRates,
} from '../src/admin/admin.js';
import type { MessDay, MessDish } from '../src/mess/types.js';

const now = new Date('2026-10-22T06:00:00Z');
const hoursAgo = (h: number) => new Date(now.getTime() - h * 3_600_000);

describe('admin/endpoint health — per-endpoint staleness (§20)', () => {
  it('ok, stale after 26 h, never, failing after 3 in a row', () => {
    expect(endpointHealth({ lastSuccessAt: hoursAgo(2), consecutiveFailures: 0 }, now)).toEqual({ state: 'ok', hoursSinceSuccess: 2 });
    expect(endpointHealth({ lastSuccessAt: hoursAgo(STALE_AFTER_HOURS + 1), consecutiveFailures: 1 }, now).state).toBe('stale');
    expect(endpointHealth({ lastSuccessAt: hoursAgo(STALE_AFTER_HOURS), consecutiveFailures: 0 }, now).state).toBe('ok');
    expect(endpointHealth({ lastSuccessAt: null, consecutiveFailures: 0 }, now)).toEqual({ state: 'never', hoursSinceSuccess: null });
    expect(endpointHealth({ lastSuccessAt: hoursAgo(1), consecutiveFailures: FAILING_AFTER }, now).state).toBe('failing');
  });
});

const ranges = { kcalLow: 200, kcalHigh: 300, proteinLow: 5, proteinHigh: 8, carbLow: 30, carbHigh: 40, fatLow: 6, fatHigh: 10 };

describe('admin/corrections', () => {
  it('a reviewed range replaces one field and keeps the rest', () => {
    expect(applyCorrection(ranges, 'protein', 12, 15.555)).toEqual({ ok: true, ranges: { ...ranges, proteinLow: 12, proteinHigh: 15.56 } });
  });

  it('refuses a slip: negative, reversed, above the per-serving bound, not a number', () => {
    expect(applyCorrection(ranges, 'kcal', -1, 10)).toEqual({ ok: false, problem: 'negative' });
    expect(applyCorrection(ranges, 'kcal', 300, 200)).toEqual({ ok: false, problem: 'low above high' });
    expect(applyCorrection(ranges, 'kcal', 3000, 30000)).toMatchObject({ ok: false });
    expect(applyCorrection(ranges, 'fat', Number.NaN, 1)).toMatchObject({ ok: false });
  });

  it('diet overrides apply by slug on any served day; others untouched; nothing when empty', () => {
    const dish = (id: string, diet: MessDish['diet']): MessDish => ({
      id, name: id, raw: id, label: null, diet, role: 'staple', alternatives: [], alternativeDiets: [], isAmbient: false, nutrition: null,
    });
    const day: MessDay = {
      date: '2026-10-22',
      resolution: { kind: 'exact', date: '2026-10-22' },
      meals: [{ slot: 'lunch', rawMenu: 'x', dishes: [dish('veg-pulao', 'veg'), dish('dal-fry', 'veg')] }],
    };
    const out = applyDietOverrides(day, new Map([['veg-pulao', 'egg']]));
    expect(out.meals[0]!.dishes.map((d) => `${d.id}:${d.diet}`)).toEqual(['veg-pulao:egg', 'dal-fry:veg']);
    expect(day.meals[0]!.dishes[0]!.diet).toBe('veg');
    expect(applyDietOverrides(day, new Map())).toBe(day);
  });
});

describe('admin/dashboards', () => {
  it('rates: one decimal of a percent, null over nothing', () => {
    expect(rate(1, 3)).toBe(33.3);
    expect(rate(0, 0)).toBeNull();
  });

  it('recommendation acceptance per TODAY kind', () => {
    const rows = [
      { kind: 'eat-protein', event: 'shown', n: 10 },
      { kind: 'eat-protein', event: 'opened', n: 6 },
      { kind: 'eat-protein', event: 'accepted', n: 4 },
      { kind: 'eat-protein', event: 'dismissed', n: 2 },
      { kind: 'eat-protein', event: 'completed', n: 3 },
      { kind: 'log-weight', event: 'shown', n: 4 },
    ];
    expect(recommendationRates(rows)).toEqual([
      { kind: 'eat-protein', shown: 10, opened: 6, accepted: 4, dismissed: 2, completed: 3, acceptRate: 40, dismissRate: 20, completeRate: 30 },
      { kind: 'log-weight', shown: 4, opened: 0, accepted: 0, dismissed: 0, completed: 0, acceptRate: 0, dismissRate: 0, completeRate: 0 },
    ]);
  });

  it('notification open rate per kind: opened over sent (delivered + opened)', () => {
    expect(
      notificationRates([
        { kind: 'protein-gap', status: 'delivered', n: 6 },
        { kind: 'protein-gap', status: 'opened', n: 2 },
        { kind: 'protein-gap', status: 'cancelled', n: 5 },
        { kind: 'protein-gap', status: 'planned', n: 9 },
      ]),
    ).toEqual([{ kind: 'protein-gap', sent: 8, opened: 2, cancelled: 5, openRate: 25 }]);
  });
});
