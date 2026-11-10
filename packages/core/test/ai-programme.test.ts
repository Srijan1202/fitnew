import { describe, expect, it } from 'vitest';

import { draftVolume, fitProgramme, programmePrompt, readProgrammeAnswer, type ProgrammeCandidate, type ProgrammeDraft } from '../src/ai/programme.js';

const cands: ProgrammeCandidate[] = [
  { id: 'E1', name: 'Barbell Bench Press', pattern: 'horizontal-push', primary: ['chest'], secondary: ['triceps', 'shoulders'] },
  { id: 'E2', name: 'Barbell Row', pattern: 'horizontal-pull', primary: ['back'], secondary: ['biceps'] },
  { id: 'E3', name: 'Back Squat', pattern: 'squat', primary: ['quads', 'glutes'], secondary: [] },
  { id: 'E4', name: 'Dumbbell Fly', pattern: 'isolation', primary: ['chest'], secondary: [] },
];
const ex = (id: string, sets = 3) => ({ id, sets, repMin: 8, repMax: 12, rir: 2 });

describe('the AI programme builder (beta 6.1)', () => {
  it('the prompt carries the answers and the list, and nothing about the person', () => {
    const p = programmePrompt({ goal: 'muscle-gain', experience: 'intermediate', sessions: 3, minutes: 60, focus: ['chest'], note: 'no jumping' }, cands);
    expect(p.system).toContain('Exactly 3 days');
    expect(p.user).toContain('Muscles to bring up: chest.');
    expect(p.user).toContain('They add: no jumping');
    expect(p.user).toContain('E1: Barbell Bench Press (horizontal-push; chest; also triceps, shoulders)');
    expect(p.user).toContain('E3: Back Squat (squat; quads, glutes)');
    const plain = programmePrompt({ goal: 'strength', experience: 'beginner', sessions: 2, minutes: 45, focus: [], note: null }, cands);
    expect(plain.user).toContain('No muscles to bring up.');
    expect(plain.user).toContain('Nothing else.');
  });

  it('reads a week: unknown ids and repeats dropped, numbers put in bounds, names filled', () => {
    const json = {
      name: '  Upper Lower  ',
      why: 'Because.',
      days: [
        { name: 'Upper', exercises: [ex('E1'), ex('E1'), { id: 'E9', sets: 3, repMin: 8, repMax: 12, rir: 2 }, { id: 'E2', sets: 9, repMin: 15, repMax: 1, rir: 7 }, ex('E4'), 'junk'] },
        { exercises: [ex('E3'), ex('E1'), ex('E2'), { id: 'E4', sets: 'x', repMin: 8, repMax: 12, rir: 2 }] },
      ],
    };
    const d = readProgrammeAnswer(json, cands, 2)!;
    expect(d.name).toBe('Upper Lower');
    expect(d.days[0]!.exercises).toEqual([ex('E1'), { id: 'E2', sets: 6, repMin: 3, repMax: 15, rir: 4 }, ex('E4')]);
    expect(d.days[1]!.name).toBe('Day 2');
    expect(d.days[1]!.exercises.map((x) => x.id)).toEqual(['E3', 'E1', 'E2']);
    // Defaults for a missing name and why.
    expect(readProgrammeAnswer({ days: [{ exercises: [ex('E1'), ex('E2'), ex('E3')] }] }, cands, 1)).toMatchObject({ name: 'FITOS AI programme', why: '' });
  });

  it('refuses what is not a week of the right size', () => {
    const three = { exercises: [ex('E1'), ex('E2'), ex('E3')] };
    expect(readProgrammeAnswer(null, cands, 1)).toBeNull();
    expect(readProgrammeAnswer('x', cands, 1)).toBeNull();
    expect(readProgrammeAnswer({ days: 'no' }, cands, 1)).toBeNull();
    expect(readProgrammeAnswer({ days: [three] }, cands, 2)).toBeNull();
    expect(readProgrammeAnswer({ days: [{ exercises: [ex('E1'), ex('E2')] }] }, cands, 1)).toBeNull();
    expect(readProgrammeAnswer({ days: [null] }, cands, 1)).toBeNull();
    // At most 8 a day: the ninth is not read.
    const many: ProgrammeCandidate[] = Array.from({ length: 10 }, (_, i) => ({ id: `E${i + 1}`, name: `X${i}`, pattern: 'isolation', primary: ['abs'], secondary: [] }));
    expect(readProgrammeAnswer({ days: [{ exercises: many.map((c) => ex(c.id)) }] }, many, 1)!.days[0]!.exercises).toHaveLength(8);
  });

  it('fits: a session over time loses sets, then exercises; it stops at the floor', () => {
    const long: ProgrammeDraft = { name: 'P', why: '', days: [{ name: 'Upper', exercises: [ex('E1', 6), ex('E2', 6), ex('E4', 5), ex('E3', 4)] }] };
    const r = fitProgramme(long, cands, 45);
    const sets = r.draft.days[0]!.exercises.reduce((n, x) => n + x.sets, 0);
    expect(sets * 3.5).toBeLessThanOrEqual(45 * 1.15);
    expect(r.adjustments[0]).toMatch(/^Upper shortened to about \d+ minutes\.$/);
    // Too short for even three exercises at two sets: it stops there.
    const floor = fitProgramme({ name: 'P', why: '', days: [{ name: 'A', exercises: [ex('E1', 2), ex('E2', 2), ex('E3', 2)] }] }, cands, 10);
    expect(floor.draft.days[0]!.exercises).toHaveLength(3);
    // Dropping exercises once every one is at two sets.
    const drop = fitProgramme({ name: 'P', why: '', days: [{ name: 'B', exercises: [ex('E1', 2), ex('E2', 2), ex('E3', 2), ex('E4', 2)] }] }, cands, 20);
    expect(drop.draft.days[0]!.exercises).toHaveLength(3);
    // In time: untouched.
    const ok = fitProgramme({ name: 'P', why: '', days: [{ name: 'C', exercises: [ex('E1'), ex('E2'), ex('E3')] }] }, cands, 60);
    expect(ok.adjustments).toEqual([]);
  });

  it('fits: a muscle over its MRV a week loses sets on its own exercises, biggest first', () => {
    const chesty: ProgrammeDraft = {
      name: 'P',
      why: '',
      days: [
        { name: 'A', exercises: [ex('E1', 6), ex('E4', 6), ex('E2', 2)] },
        { name: 'B', exercises: [ex('E1', 6), ex('E4', 6), ex('E2', 2)] },
      ],
    };
    expect(draftVolume(chesty, cands).get('chest')).toBe(24);
    const r = fitProgramme(chesty, cands, 120);
    expect(draftVolume(r.draft, cands).get('chest')).toBe(20);
    expect(r.adjustments).toEqual(['Chest kept to about 20 sets a week, the most FITOS plans.']);
    // A muscle whose exercises are all at the floor stays over, said all the same.
    const floor: ProgrammeDraft = { name: 'P', why: '', days: Array.from({ length: 11 }, (_, i) => ({ name: `D${i}`, exercises: [ex('E4', 2), ex('E2', 2), ex('E3', 2)] })) };
    expect(fitProgramme(floor, cands, 120).adjustments).toContain('Chest kept to about 20 sets a week, the most FITOS plans.');
  });
});
