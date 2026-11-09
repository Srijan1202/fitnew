import { describe, expect, it } from 'vitest';

import { planAlternatives, type ExerciseFacts } from '../src/admin/alternatives.js';

const ex = (id: string, over: Partial<ExerciseFacts> = {}): ExerciseFacts => ({
  id,
  slug: id,
  movementPattern: 'horizontal-push',
  primaryMuscles: ['chest'],
  retired: false,
  alternatives: 0,
  ...over,
});

const bench = ex('bench', { primaryMuscles: ['chest', 'triceps'] });
const db = ex('db-bench');
const pushup = ex('push-up', { alternatives: 3 });
const facts = (...xs: ExerciseFacts[]) => new Map(xs.map((x) => [x.id, x]));

describe('planAlternatives (E19, §12.6)', () => {
  it('adds the reverse of an equipment link and marks both exercises edited', () => {
    const r = planAlternatives(bench, [], [{ id: 'db-bench', reason: 'equipment' }], facts(db), 10);
    expect(r).toEqual({
      ok: true,
      plan: {
        addReverse: [{ exerciseId: 'db-bench', alternativeId: 'bench', reason: 'equipment' }],
        removeReverse: [],
        touched: ['bench', 'db-bench'],
      },
    });
  });

  it('keeps an injury link one way', () => {
    const r = planAlternatives(bench, [], [{ id: 'push-up', reason: 'injury' }], facts(pushup), 10);
    expect(r.ok && r.plan).toEqual({ addReverse: [], removeReverse: [], touched: ['bench'] });
  });

  it('removes the reverse of a dropped preference link, not of a dropped injury link', () => {
    const before = [
      { id: 'db-bench', reason: 'preference' as const },
      { id: 'push-up', reason: 'injury' as const },
    ];
    const r = planAlternatives(bench, before, [], facts(db, pushup), 10);
    expect(r.ok && r.plan).toEqual({
      addReverse: [],
      removeReverse: [{ exerciseId: 'db-bench', alternativeId: 'bench', reason: 'preference' }],
      touched: ['bench', 'db-bench'],
    });
  });

  it('touches nothing when the list is unchanged', () => {
    const same = [{ id: 'db-bench', reason: 'equipment' as const }];
    const r = planAlternatives(bench, same, same, facts(db), 10);
    expect(r.ok && r.plan.touched).toEqual([]);
  });

  it('a changed injury list with the same length is still a change', () => {
    const r = planAlternatives(bench, [{ id: 'db-bench', reason: 'injury' }], [{ id: 'push-up', reason: 'injury' }], facts(db, pushup), 10);
    expect(r.ok && r.plan.touched).toEqual(['bench']);
  });

  it('refuses itself, a repeat, an unknown id, a new retired one, another pattern and no shared muscle', () => {
    const fly = ex('fly', { movementPattern: 'isolation' });
    const row = ex('row', { primaryMuscles: ['lats'] });
    const old = ex('old', { retired: true });
    const r = planAlternatives(
      bench,
      [],
      [
        { id: 'bench', reason: 'equipment' },
        { id: 'db-bench', reason: 'equipment' },
        { id: 'db-bench', reason: 'equipment' },
        { id: 'nope', reason: 'equipment' },
        { id: 'old', reason: 'injury' },
        { id: 'fly', reason: 'injury' },
        { id: 'row', reason: 'injury' },
      ],
      facts(db, fly, row, old),
      10,
    );
    expect(r).toEqual({
      ok: false,
      problems: [
        { path: 'items.0', issue: 'an exercise cannot be its own alternative' },
        { path: 'items.2', issue: 'listed twice for the same reason' },
        { path: 'items.3', issue: 'no such exercise' },
        { path: 'items.4', issue: 'old is retired' },
        { path: 'items.5', issue: 'fly is a different movement (isolation, not horizontal-push)' },
        { path: 'items.6', issue: 'row shares no primary muscle' },
      ],
    });
  });

  it('keeps a retired alternative that was already linked', () => {
    const old = ex('old', { retired: true });
    const r = planAlternatives(bench, [{ id: 'old', reason: 'injury' }], [{ id: 'old', reason: 'injury' }], facts(old), 10);
    expect(r.ok).toBe(true);
  });

  it('refuses more than the maximum, here and on the other exercise', () => {
    const many = Array.from({ length: 3 }, (_, i) => ({ id: `x${i}`, reason: 'injury' as const }));
    const xs = many.map((m) => ex(m.id));
    expect(planAlternatives(bench, [], many, facts(...xs), 2)).toEqual({ ok: false, problems: [{ path: 'items', issue: 'at most 2 alternatives' }] });
    const full = ex('db-bench', { alternatives: 2 });
    expect(planAlternatives(bench, [], [{ id: 'db-bench', reason: 'equipment' }], facts(full), 2)).toEqual({
      ok: false,
      problems: [{ path: 'items', issue: 'db-bench would have more than 2 alternatives' }],
    });
  });

  it('a swap on a full exercise nets to zero', () => {
    const full = ex('db-bench', { alternatives: 2 });
    const r = planAlternatives(bench, [{ id: 'db-bench', reason: 'equipment' }], [{ id: 'db-bench', reason: 'preference' }], facts(full), 2);
    expect(r.ok).toBe(true);
  });
});
