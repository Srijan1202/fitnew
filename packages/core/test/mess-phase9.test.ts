/**
 * Phase 9 — the mess mirror in core: hardened shape check (D23), menus from
 * stored snapshots (D2/D5), freshness (D19), the medium confidence cap and
 * the D9 table additions. The 2026-09-07 fixtures stay under test in
 * mess.test.ts, unchanged; the 2026-09-24 capture is added here.
 */
import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { VIT_DESCRIPTORS, VIT_ENDPOINTS, messCode } from '../src/mess/providers/vit/config.js';
import { buildDay, detectCycleLength, isMessItResponse } from '../src/mess/providers/vit/provider.js';
import { capMessConfidence, estimateNutrition } from '../src/mess/nutrition.js';
import { latestPublishedDate, mergeSnapshots, resolveDayFromSnapshots, type MenuSnapshot } from '../src/mess/snapshots.js';
import { MIRROR_STALE_AFTER_HOURS, isMirrorStale } from '../src/mess/freshness.js';
import type { MessItResponse } from '../src/mess/types.js';

function load(path: string): MessItResponse {
  return JSON.parse(readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8')) as MessItResponse;
}
const old = (n: string): MessItResponse => load(`./fixtures/${n}.json`);
const fresh = (n: string): MessItResponse => load(`./fixtures/messit-2026-09-24/${n}.json`);
const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);

function day(date: string, breakfast: string, lunch = 'Rice, Dal'): MessItResponse['menu'][number] {
  return { date, menu: [{ type: 1, menu: breakfast }, { type: 2, menu: lunch }] };
}
function payload(days: MessItResponse['menu']): MessItResponse {
  return { hostel: 1, mess: 2, menu: days };
}

/* ------------------------------------------------------- shape check (D23) */

describe('isMessItResponse — every entry checked', () => {
  const good = payload([day('2026-09-01', 'Idly, Sambar')]);

  it('accepts all twelve real captures (2026-09-07 and 2026-09-24)', () => {
    for (const n of NAMES) {
      expect(isMessItResponse(old(n)), n).toBe(true);
      expect(isMessItResponse(fresh(n)), n).toBe(true);
    }
  });

  it('accepts a well-formed payload, and an unknown type VALUE (dropped later, not guessed)', () => {
    expect(isMessItResponse(good)).toBe(true);
    const withType9 = payload([{ date: '2026-09-01', menu: [{ type: 9, menu: 'Mystery' }] }]);
    expect(isMessItResponse(withType9)).toBe(true);
    expect(buildDay(withType9, '2026-09-01', false).meals).toEqual([]);
  });

  it.each([
    ['a string type', { date: '2026-09-01', menu: [{ type: '1', menu: 'Idly' }] }],
    ['a fractional type', { date: '2026-09-01', menu: [{ type: 1.5, menu: 'Idly' }] }],
    ['a non-string menu', { date: '2026-09-01', menu: [{ type: 1, menu: ['Idly'] }] }],
    ['a null menu', { date: '2026-09-01', menu: [{ type: 1, menu: null }] }],
    ['a missing menu', { date: '2026-09-01', menu: [{ type: 1 }] }],
    ['a null entry', { date: '2026-09-01', menu: [null] }],
    ['a malformed date', { date: '1 Sep 2026', menu: [{ type: 1, menu: 'Idly' }] }],
    ['a date with a time', { date: '2026-09-01T00:00:00Z', menu: [{ type: 1, menu: 'Idly' }] }],
  ])('rejects the whole payload for %s', (_why, badDay) => {
    expect(isMessItResponse({ hostel: 1, mess: 2, menu: [day('2026-08-31', 'Poha'), badDay] })).toBe(false);
  });

  it('rejects a non-object, missing ids, or a non-array menu', () => {
    expect(isMessItResponse(null)).toBe(false);
    expect(isMessItResponse('[]')).toBe(false);
    expect(isMessItResponse({ hostel: '1', mess: 2, menu: [] })).toBe(false);
    expect(isMessItResponse({ hostel: 1, mess: 2, menu: {} })).toBe(false);
  });
});

/* ---------------------------------------------- the 2026-09-24 live capture */

describe('the 2026-09-24 capture parses with the existing parser', () => {
  it('all six: a 14-day cycle, today exact, 2 Oct inferred from 18 Sep', () => {
    for (const e of VIT_ENDPOINTS) {
      const n = `hostel-${e.hostel}-mess-${e.mess}`;
      const p = fresh(n);
      const d = VIT_DESCRIPTORS.find((x) => x.hostelId === e.hostelId && x.messId === e.messId);
      expect(detectCycleLength(p), n).toBe(14);
      const today = buildDay(p, '2026-09-24', d?.servesNonVeg ?? true);
      expect(today.resolution.kind, n).toBe('exact');
      expect(today.meals.map((m) => m.slot), n).toEqual(['breakfast', 'lunch', 'snacks', 'dinner']);
      expect(buildDay(p, '2026-10-02', true).resolution).toEqual({
        kind: 'cycle-inferred', date: '2026-10-02', sourceDate: '2026-09-18', cycleLengthDays: 14,
      });
    }
  });

  it('keeps the verbatim upstream text on every meal', () => {
    const p = fresh('hostel-1-mess-2');
    const upstream = p.menu.find((d) => d.date === '2026-09-24')?.menu.find((m) => m.type === 2)?.menu;
    const lunch = buildDay(p, '2026-09-24', false).meals.find((m) => m.slot === 'lunch');
    expect(lunch?.rawMenu).toBe(upstream);
  });

  it('unlabelled non-veg in the men\'s special mess is still classified by keyword (§14.5)', () => {
    const breakfast = buildDay(fresh('hostel-1-mess-1'), '2026-09-01', true).meals.find((m) => m.slot === 'breakfast');
    const egg = breakfast?.dishes.find((x) => x.name === 'Scrambled Egg');
    expect(egg?.label).toBeNull();
    expect(egg?.diet).toBe('egg');
  });

  it('after the D9 additions, only one served dish has no estimate at all (Urapadai, not guessed)', () => {
    const missing = new Set<string>();
    for (const n of NAMES) {
      const p = fresh(n);
      for (const d of p.menu) {
        for (const meal of buildDay(p, d.date, true).meals) {
          for (const dish of meal.dishes) if (dish.nutrition === null) missing.add(dish.name);
        }
      }
    }
    expect([...missing]).toEqual(['Urapadai']);
  });
});

/* ------------------------------------------------------ D9 table additions */

describe('estimate table additions (D9)', () => {
  it.each([
    ['Subzi', 'Poriyal'],
    ['Green Veg Subzi', 'Poriyal'],
    ['Dry Jamoon', 'Gulab Jamun'],
    ['Kova Mysorepaku', 'Mysore Pak'],
    ['Rasagulla', 'Rasgulla'],
    ['Badusha', 'Badhusa'],
    ['Sweet Corn Chaat', 'Sweet Corn Chat'],
    ['Aloo Tikka Chaat', 'Aloo Tikka Chat'],
    ['Mint Lemon', 'Nimbu Sarbat'],
    ['Pineapple Pudding', 'Custard'],
    ['Salna', 'Veg Gravy'],
  ])('%s shares the existing estimate of %s (a spelling variant, not a new number)', (variant, base) => {
    expect(estimateNutrition(variant, 'other')).toEqual(estimateNutrition(base, 'other'));
  });

  it('new dishes are low-confidence, weighed estimates', () => {
    for (const name of ['Idiyappam', 'Stew']) {
      const est = estimateNutrition(name, 'other');
      expect(est?.confidence).toBe('low');
      expect(est?.servingGrams).not.toBeNull();
      expect(est?.source).toBe('estimated-table');
    }
  });

  it('additions never shadow a base entry (first match wins; the Phase 7 seed reads the base)', () => {
    expect(estimateNutrition('Gulab Jamun', 'other')?.servingLabel).toBe('1 piece');
    expect(estimateNutrition('Veg Gravy', 'other')?.servingGrams).toBe(120);
    expect(estimateNutrition('White Rice', 'other')?.confidence).toBe('high');
  });

  it('a dish nothing describes stays unestimated', () => {
    expect(estimateNutrition('Urapadai', 'other')).toBeNull();
  });
});

describe('capMessConfidence — mess nutrition is never high', () => {
  it('caps high to medium and keeps the rest', () => {
    expect(capMessConfidence('high')).toBe('medium');
    expect(capMessConfidence('medium')).toBe('medium');
    expect(capMessConfidence('low')).toBe('low');
  });
});

/* ------------------------------------------------- snapshots (D2, D3, D5) */

describe('resolveDayFromSnapshots', () => {
  // A 14-day cycle: 1 Sep == 15 Sep, 2 Sep == 16 Sep (two confirming pairs).
  const cycle = [
    day('2026-09-01', 'Poha'), day('2026-09-02', 'Dosa'),
    day('2026-09-15', 'Poha'), day('2026-09-16', 'Dosa'),
  ];

  it('no snapshots: unavailable, nothing published', () => {
    const r = resolveDayFromSnapshots([], '2026-09-24', true);
    expect(r.snapshotId).toBeNull();
    expect(r.day.resolution).toEqual({ kind: 'unavailable', date: '2026-09-24', latestAvailable: null });
    expect(r.day.meals).toEqual([]);
  });

  it('a published date is exact, from the newest snapshot that has it — MessIT edits past days', () => {
    const older: MenuSnapshot = { id: 'old', payload: payload([day('2026-09-07', 'Poori, Chutney')]) };
    const newer: MenuSnapshot = { id: 'new', payload: payload([day('2026-09-07', 'Poori, Chutney, Tea')]) };
    const r = resolveDayFromSnapshots([newer, older], '2026-09-07', false);
    expect(r.snapshotId).toBe('new');
    expect(r.day.resolution.kind).toBe('exact');
    expect(r.day.meals[0]?.rawMenu).toBe('Poori, Chutney, Tea');
  });

  it('a date only an older snapshot publishes is exact from that snapshot', () => {
    const older: MenuSnapshot = { id: 'aug', payload: payload([day('2026-08-20', 'Upma')]) };
    const newer: MenuSnapshot = { id: 'sep', payload: payload([day('2026-09-20', 'Idly')]) };
    const r = resolveDayFromSnapshots([newer, older], '2026-08-20', false);
    expect(r.snapshotId).toBe('aug');
    expect(r.day.resolution).toEqual({ kind: 'exact', date: '2026-08-20' });
  });

  it('an unpublished date is cycle-inferred from the latest snapshot, and says so', () => {
    const r = resolveDayFromSnapshots([{ id: 's1', payload: payload(cycle) }], '2026-09-29', false);
    expect(r.snapshotId).toBe('s1');
    expect(r.day.resolution).toEqual({ kind: 'cycle-inferred', date: '2026-09-29', sourceDate: '2026-09-15', cycleLengthDays: 14 });
    expect(r.day.meals[0]?.rawMenu).toBe('Poha');
  });

  it('falls back to the union of snapshots only when the latest alone has no cycle', () => {
    const thinLatest: MenuSnapshot = { id: 'thin', payload: payload([day('2026-09-15', 'Poha'), day('2026-09-16', 'Dosa')]) };
    const earlier: MenuSnapshot = { id: 'early', payload: payload([day('2026-09-01', 'Poha'), day('2026-09-02', 'Dosa')]) };
    const r = resolveDayFromSnapshots([thinLatest, earlier], '2026-09-30', false);
    expect(r.day.resolution).toEqual({ kind: 'cycle-inferred', date: '2026-09-30', sourceDate: '2026-09-16', cycleLengthDays: 14 });
    expect(r.snapshotId).toBe('thin');
  });

  it('prefers the latest snapshot\'s own cycle over a union that retroactive edits would contradict', () => {
    // The older copy of 1 Sep differs from the newer copy (an upstream edit);
    // merged, it would still take 1 Sep from the newer snapshot.
    const newer: MenuSnapshot = { id: 'new', payload: payload(cycle) };
    const older: MenuSnapshot = { id: 'old', payload: payload([day('2026-09-01', 'Poha (old text)'), day('2026-08-18', 'Something else')]) };
    const r = resolveDayFromSnapshots([newer, older], '2026-09-29', false);
    expect(r.day.resolution.kind).toBe('cycle-inferred');
    expect(r.snapshotId).toBe('new');
  });

  it('no cycle anywhere: unavailable with the latest published date', () => {
    const s: MenuSnapshot = { id: 's', payload: payload([day('2026-08-01', 'A'), day('2026-08-02', 'B')]) };
    const r = resolveDayFromSnapshots([s], '2026-09-24', true);
    expect(r.day.resolution).toEqual({ kind: 'unavailable', date: '2026-09-24', latestAvailable: '2026-08-02' });
    expect(r.snapshotId).toBeNull();
  });

  it('the stale 2026-09-07 men\'s non-veg capture plus the fresh one: today is exact from the fresh', () => {
    const r = resolveDayFromSnapshots(
      [{ id: 'fresh', payload: fresh('hostel-1-mess-3') }, { id: 'stale', payload: old('hostel-1-mess-3') }],
      '2026-09-24',
      true,
    );
    expect(r.snapshotId).toBe('fresh');
    expect(r.day.resolution.kind).toBe('exact');
    // An August day only the old capture has is still answerable, exactly.
    const aug = resolveDayFromSnapshots(
      [{ id: 'fresh', payload: fresh('hostel-1-mess-3') }, { id: 'stale', payload: old('hostel-1-mess-3') }],
      '2026-08-10',
      true,
    );
    expect(aug.snapshotId).toBe('stale');
    expect(aug.day.resolution.kind).toBe('exact');
  });

  it('mergeSnapshots keeps each date once, from its newest snapshot; latestPublishedDate spans all', () => {
    const a: MenuSnapshot = { id: 'a', payload: payload([day('2026-09-02', 'New'), day('2026-09-03', 'C')]) };
    const b: MenuSnapshot = { id: 'b', payload: payload([day('2026-09-01', 'A'), day('2026-09-02', 'Old')]) };
    const merged = mergeSnapshots([a, b]);
    expect(merged.menu.map((d) => d.date).sort()).toEqual(['2026-09-01', '2026-09-02', '2026-09-03']);
    expect(merged.menu.find((d) => d.date === '2026-09-02')?.menu[0]?.menu).toBe('New');
    expect(latestPublishedDate([b, a])).toBe('2026-09-03');
    expect(latestPublishedDate([])).toBeNull();
  });
});

/* ----------------------------------------------------------- freshness D19 */

describe('isMirrorStale', () => {
  const now = new Date('2026-09-24T12:00:00Z');
  it('never fetched is stale', () => expect(isMirrorStale(null, now)).toBe(true));
  it('within 24 h is fresh, beyond is stale', () => {
    expect(MIRROR_STALE_AFTER_HOURS).toBe(24);
    expect(isMirrorStale(new Date('2026-09-23T12:00:00Z'), now)).toBe(false);
    expect(isMirrorStale(new Date('2026-09-23T11:59:59Z'), now)).toBe(true);
  });
});

describe('messCode', () => {
  it('is hostel-mess, unique across the six', () => {
    expect(messCode('mens', 'veg')).toBe('mens-veg');
    const codes = VIT_DESCRIPTORS.map((d) => messCode(d.hostelId, d.messId));
    expect(new Set(codes).size).toBe(6);
  });
});
