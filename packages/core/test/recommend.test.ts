/**
 * The TODAY decision engine — the original behaviour, carried onto the
 * Phase 11 model (ADR-017, D17). Detailed Phase 11 rules are pinned in
 * today-phase11.test.ts.
 */
import { describe, expect, it } from 'vitest';
import { buildActions, topActions } from '../src/recommend/engine.js';
import { BASE, model } from './today-fixtures.js';

describe('TODAY decision engine', () => {
  it('leads with the workout on a training day', () => {
    const [first] = buildActions(BASE);
    expect(first?.kind).toBe('start-workout');
    expect(first?.headline).toBe('Pull — Back / Biceps');
    expect(first?.detail).toBe('6 exercises · about 60 minutes.'); // 17 sets × 3.5
  });

  it('surfaces the protein gap with the actual shortfall, as a range', () => {
    const protein = buildActions(BASE).find((a) => a.kind === 'eat-protein');
    expect(protein).toBeDefined();
    expect(protein?.headline).toBe('108–120 g protein to go'); // 150 − 42 … 150 − 30
    expect(protein?.detail).toContain('1580–1750 kcal'); // 2400 − 820 … 2400 − 650
  });

  it('puts a deload above everything else', () => {
    const [first] = buildActions(model({ training: { deload: { state: 'offered', trigger: 'fatigue' } } }));
    expect(first?.kind).toBe('deload');
  });

  it('does not offer a rest day and a deload at the same time', () => {
    const actions = buildActions(model({ training: { sessionName: null, deload: { state: 'offered', trigger: 'mrv' } } }));
    expect(actions.some((a) => a.kind === 'deload')).toBe(true);
    expect(actions.some((a) => a.kind === 'rest-day')).toBe(false);
  });

  it('gives a rest day something to do rather than a shrug', () => {
    const rest = buildActions(model({ training: { sessionName: null } })).find((a) => a.kind === 'rest-day');
    expect(rest).toBeDefined();
    expect(rest?.detail).toBe(
      'Next: Legs — Quads / Glutes on 2026-09-25. Eat to about 2400 kcal and 150 g protein. A walk helps recovery without adding fatigue.',
    );
    expect(rest?.headline).not.toContain('😴');
  });

  it('never shows both eat-protein and eat-meal', () => {
    for (const proteinHigh of [0, 50, 92, 112, 113, 150]) {
      const actions = buildActions(model({ nutrition: { eaten: { kcalLow: 900, kcalHigh: 1100, proteinLow: proteinHigh * 0.8, proteinHigh } } }));
      const eating = actions.filter((a) => a.kind === 'eat-protein' || a.kind === 'eat-meal');
      expect(eating.length).toBeLessThanOrEqual(1);
    }
  });

  it('stops nagging about food once protein is on track and calories are nearly met', () => {
    const actions = buildActions(model({ nutrition: { eaten: { kcalLow: 2100, kcalHigh: 2300, proteinLow: 130, proteinHigh: 145 } } }));
    expect(actions.some((a) => a.kind === 'eat-protein' || a.kind === 'eat-meal')).toBe(false);
  });

  it('says nothing about food once every remaining meal is logged', () => {
    const actions = buildActions(model({ hourOfDay: 20, nutrition: { loggedSlots: ['breakfast', 'lunch', 'snacks', 'dinner'] } }));
    expect(actions.some((a) => a.kind === 'eat-protein' || a.kind === 'eat-meal')).toBe(false);
  });

  it('does not ask for a weigh-in when one is already logged', () => {
    expect(buildActions(BASE).some((a) => a.kind === 'log-weight')).toBe(false);
    expect(buildActions(model({ body: { weighedToday: false, daysSinceWeighIn: 3 } })).some((a) => a.kind === 'log-weight')).toBe(true);
  });

  it('reports the basis of every action so the UI can label estimates', () => {
    for (const action of buildActions(BASE)) expect(['logged', 'calculated', 'estimated']).toContain(action.basis);
  });

  it('caps the surface at four and keeps them ordered', () => {
    const actions = topActions(model({
      training: {
        neglected: [{ muscle: 'quads', daysSince: 8 }],
        prsToday: [{ prId: 'p', exerciseName: 'Deadlift', prType: 'weight', value: 120, previous: 115 }],
        deload: { state: 'offered', trigger: 'fatigue' },
      },
      body: { weighedToday: false, daysSinceWeighIn: 4 },
    }));
    expect(actions).toHaveLength(4);
    const priorities = actions.map((a) => a.priority);
    expect([...priorities].sort((a, b) => b - a)).toEqual(priorities);
  });

  it('is deterministic for identical state', () => {
    expect(buildActions(BASE)).toEqual(buildActions(BASE));
  });
});
