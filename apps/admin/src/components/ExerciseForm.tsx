'use client';

import { DIFFICULTIES, EQUIPMENT, MOVEMENT_PATTERNS, MUSCLE_GROUPS, bodyPartSchema, type AdminExercise } from '@fitos/contracts';
import { useState } from 'react';

import { api, errorText } from '@/lib/api';

export type ExerciseDraft = Omit<AdminExercise, 'id' | 'retiredAt' | 'adminEditedAt'>;

export const EMPTY_EXERCISE: ExerciseDraft = {
  slug: '',
  name: '',
  movementPattern: 'squat',
  equipment: ['barbell'],
  difficulty: 'beginner',
  isUnilateral: false,
  defaultIncrementKg: 2.5,
  instructions: ['', ''],
  videoUrl: null,
  primaryMuscles: [],
  secondaryMuscles: [],
  contraindications: [],
};

function Checks<T extends string>({ all, value, onChange }: { all: readonly T[]; value: readonly T[]; onChange: (v: T[]) => void }) {
  return (
    <div className="checks">
      {all.map((x) => (
        <label key={x} className="inline">
          <input
            type="checkbox"
            checked={value.includes(x)}
            onChange={(e) => onChange(e.target.checked ? [...value, x] : value.filter((v) => v !== x))}
          />{' '}
          {x}
        </label>
      ))}
    </div>
  );
}

/** Create (with a slug) or edit an exercise. The first primary muscle is the one the movement is for. */
export function ExerciseForm({ initial, id, onSaved }: { initial: ExerciseDraft; id: string | null; onSaved: (x: AdminExercise) => void }) {
  const [d, setD] = useState<ExerciseDraft>(initial);
  const [error, setError] = useState<string | null>(null);
  const set = <K extends keyof ExerciseDraft>(k: K, v: ExerciseDraft[K]) => setD((x) => ({ ...x, [k]: v }));

  const save = async () => {
    setError(null);
    // Exactly the editable fields (the API's schema is strict).
    const edit = {
      name: d.name,
      movementPattern: d.movementPattern,
      equipment: d.equipment,
      difficulty: d.difficulty,
      isUnilateral: d.isUnilateral,
      defaultIncrementKg: d.defaultIncrementKg,
      instructions: d.instructions.map((s) => s.trim()).filter((s) => s !== ''),
      videoUrl: d.videoUrl === '' ? null : d.videoUrl,
      primaryMuscles: d.primaryMuscles,
      secondaryMuscles: d.secondaryMuscles,
      contraindications: d.contraindications,
    };
    try {
      if (id === null) onSaved(await api<AdminExercise>('POST', '/admin/exercises', { slug: d.slug, ...edit }));
      else onSaved(await api<AdminExercise>('PUT', `/admin/exercises/${id}`, edit));
    } catch (e) {
      setError(errorText(e));
    }
  };

  return (
    <div className="stack">
      {id === null && (
        <label>Slug (lower-case words joined by hyphens; permanent) <input value={d.slug} onChange={(e) => set('slug', e.target.value)} /></label>
      )}
      <label>Name <input value={d.name} onChange={(e) => set('name', e.target.value)} /></label>
      <div className="row wrap">
        <label>Movement
          <select value={d.movementPattern} onChange={(e) => set('movementPattern', e.target.value as ExerciseDraft['movementPattern'])}>
            {MOVEMENT_PATTERNS.map((m) => <option key={m}>{m}</option>)}
          </select>
        </label>
        <label>Difficulty
          <select value={d.difficulty} onChange={(e) => set('difficulty', e.target.value as ExerciseDraft['difficulty'])}>
            {DIFFICULTIES.map((m) => <option key={m}>{m}</option>)}
          </select>
        </label>
        <label>Increment (kg) <input type="number" step="0.25" min="0.25" value={d.defaultIncrementKg} onChange={(e) => set('defaultIncrementKg', Number(e.target.value))} /></label>
        <label className="inline"><input type="checkbox" checked={d.isUnilateral} onChange={(e) => set('isUnilateral', e.target.checked)} /> One side at a time</label>
      </div>
      <fieldset><legend>Equipment</legend><Checks all={EQUIPMENT} value={d.equipment} onChange={(v) => set('equipment', v)} /></fieldset>
      <fieldset><legend>Primary muscles (the first one is what the movement is for)</legend><Checks all={MUSCLE_GROUPS} value={d.primaryMuscles} onChange={(v) => set('primaryMuscles', v)} /></fieldset>
      <fieldset><legend>Secondary muscles</legend><Checks all={MUSCLE_GROUPS} value={d.secondaryMuscles} onChange={(v) => set('secondaryMuscles', v)} /></fieldset>
      <fieldset><legend>Not for people with a limitation of</legend><Checks all={bodyPartSchema.options} value={d.contraindications} onChange={(v) => set('contraindications', v)} /></fieldset>
      <fieldset>
        <legend>Instructions (at least two steps)</legend>
        {d.instructions.map((s, i) => (
          <div key={i} className="row">
            <input className="grow" value={s} onChange={(e) => set('instructions', d.instructions.map((x, j) => (j === i ? e.target.value : x)))} />
            <button className="button small" onClick={() => set('instructions', d.instructions.filter((_, j) => j !== i))}>Remove</button>
          </div>
        ))}
        <button className="button small" onClick={() => set('instructions', [...d.instructions, ''])}>Add a step</button>
      </fieldset>
      <label>Video URL (optional) <input value={d.videoUrl ?? ''} onChange={(e) => set('videoUrl', e.target.value === '' ? null : e.target.value)} /></label>
      <div className="row"><button className="button primary" onClick={() => void save()}>{id === null ? 'Create exercise' : 'Save changes'}</button></div>
      {error !== null && <p className="error">{error}</p>}
    </div>
  );
}
