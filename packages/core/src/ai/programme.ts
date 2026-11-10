/**
 * Beta 6.1 (premium): the AI programme builder's rules, pure.
 *
 *   the catalogue ──FITOS──▶ only exercises this person can do: their
 *       equipment, nothing their limitations rule out, nothing they asked
 *       to leave out — each as a short id ("E12") with its pattern and muscles
 *   ──model──▶ a week of sessions as ids, sets, reps and RIR (JSON only)
 *   ──here──▶ read: known ids only, numbers within FITOS's bounds, the
 *       number of sessions asked for, 3–8 exercises each
 *   ──here──▶ fitted: a session over the minutes asked for (3.5 min a set,
 *       +15 %) loses sets, then exercises; a muscle over its MRV a week loses
 *       sets — each change said in a line
 *
 * The model is sent the answers, the equipment-filtered catalogue and one
 * optional line from the person — never their name, weight or history.
 * Weights are never part of a plan (§12.4).
 */
import { MINUTES_PER_WORKING_SET, SECONDARY_CONTRIBUTION, VOLUME_LANDMARKS, type MuscleGroup } from '../training/generator.js';

export const PROGRAMME_MIN_EXERCISES = 3;
export const PROGRAMME_MAX_EXERCISES = 8;
export const PROGRAMME_MAX_SETS = 6;
export const PROGRAMME_MIN_SETS = 2;
export const PROGRAMME_REP_BOUNDS = { min: 3, max: 30 } as const;
export const PROGRAMME_MAX_RIR = 4;
/** A session may run this much over the minutes asked for before it is trimmed. */
export const PROGRAMME_TIME_SLACK = 1.15;

export interface ProgrammeCandidate {
  /** "E12": what the model refers to. */
  readonly id: string;
  readonly name: string;
  readonly pattern: string;
  readonly primary: readonly MuscleGroup[];
  readonly secondary: readonly MuscleGroup[];
}

export interface ProgrammeAsk {
  readonly goal: string;
  readonly experience: string;
  readonly sessions: number;
  readonly minutes: number;
  readonly focus: readonly MuscleGroup[];
  /** One free line; it goes to the model as written. */
  readonly note: string | null;
}

export interface DraftExercise {
  readonly id: string;
  readonly sets: number;
  readonly repMin: number;
  readonly repMax: number;
  readonly rir: number;
}

export interface ProgrammeDraft {
  readonly name: string;
  readonly why: string;
  readonly days: readonly { readonly name: string; readonly exercises: readonly DraftExercise[] }[];
}

export function programmePrompt(ask: ProgrammeAsk, candidates: readonly ProgrammeCandidate[]): { readonly system: string; readonly user: string } {
  const system = [
    'You are a strength coach. Build one training week from a fixed list of exercises the person can do.',
    'Answer with JSON only, exactly this shape:',
    '{"name":"a short programme name","why":"two or three sentences on why this plan suits them","days":[{"name":"Push","exercises":[{"id":"E1","sets":3,"repMin":8,"repMax":12,"rir":2}]}]}',
    'Rules:',
    `- Exactly ${ask.sessions} days, each a training session. Use only ids from the list, each at most once a day.`,
    `- ${PROGRAMME_MIN_EXERCISES} to ${PROGRAMME_MAX_EXERCISES} exercises a day, compound movements first.`,
    `- sets ${PROGRAMME_MIN_SETS}–${PROGRAMME_MAX_SETS}; reps ${PROGRAMME_REP_BOUNDS.min}–${PROGRAMME_REP_BOUNDS.max} with repMin ≤ repMax; rir (reps in reserve) 0–${PROGRAMME_MAX_RIR}.`,
    `- A day should take about ${ask.minutes} minutes at ${MINUTES_PER_WORKING_SET} minutes a set.`,
    '- Spread the work over the week so each muscle gets trained about twice; keep weekly sets for a muscle under 20.',
    '- Never name a weight. Never give medical advice.',
  ].join('\n');
  const lines = candidates.map((c) => `${c.id}: ${c.name} (${c.pattern}; ${c.primary.join(', ')}${c.secondary.length > 0 ? `; also ${c.secondary.join(', ')}` : ''})`);
  const user = [
    `Goal: ${ask.goal}. Experience: ${ask.experience}.`,
    `Sessions a week: ${ask.sessions}. Minutes a session: ${ask.minutes}.`,
    ask.focus.length > 0 ? `Muscles to bring up: ${ask.focus.join(', ')}.` : 'No muscles to bring up.',
    ask.note === null ? 'Nothing else.' : `They add: ${ask.note}`,
    'Exercises:',
    ...lines,
  ].join('\n');
  return { system, user };
}

const text = (v: unknown, max: number): string | null => (typeof v === 'string' && v.trim() !== '' ? v.trim().slice(0, max) : null);
const int = (v: unknown, lo: number, hi: number): number | null => {
  const n = Math.round(Number(v));
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : null;
};

/**
 * The model's JSON, read: unknown ids and repeats are dropped, numbers are
 * put within the bounds. Null when it is not a week of [sessions] days with
 * at least PROGRAMME_MIN_EXERCISES usable exercises each.
 */
export function readProgrammeAnswer(json: unknown, candidates: readonly ProgrammeCandidate[], sessions: number): ProgrammeDraft | null {
  if (typeof json !== 'object' || json === null) return null;
  const o = json as { name?: unknown; why?: unknown; days?: unknown };
  if (!Array.isArray(o.days) || o.days.length !== sessions) return null;
  const known = new Set(candidates.map((c) => c.id));
  const days: ProgrammeDraft['days'][number][] = [];
  for (const [i, raw] of o.days.entries()) {
    const d = (typeof raw === 'object' && raw !== null ? raw : {}) as { name?: unknown; exercises?: unknown };
    const exercises: DraftExercise[] = [];
    for (const e of Array.isArray(d.exercises) ? d.exercises : []) {
      if (exercises.length === PROGRAMME_MAX_EXERCISES) break;
      const x = (typeof e === 'object' && e !== null ? e : {}) as Record<string, unknown>;
      const id = typeof x.id === 'string' ? x.id.trim() : '';
      if (!known.has(id) || exercises.some((y) => y.id === id)) continue;
      const sets = int(x.sets, PROGRAMME_MIN_SETS, PROGRAMME_MAX_SETS);
      const a = int(x.repMin, PROGRAMME_REP_BOUNDS.min, PROGRAMME_REP_BOUNDS.max);
      const b = int(x.repMax, PROGRAMME_REP_BOUNDS.min, PROGRAMME_REP_BOUNDS.max);
      const rir = int(x.rir, 0, PROGRAMME_MAX_RIR);
      if (sets === null || a === null || b === null || rir === null) continue;
      exercises.push({ id, sets, repMin: Math.min(a, b), repMax: Math.max(a, b), rir });
    }
    if (exercises.length < PROGRAMME_MIN_EXERCISES) return null;
    days.push({ name: text(d.name, 40) ?? `Day ${i + 1}`, exercises });
  }
  return { name: text(o.name, 60) ?? 'FITOS AI programme', why: text(o.why, 400) ?? '', days };
}

/** Weekly hard sets per muscle (primary 1, secondary 0.5), as the volume engine counts them. */
export function draftVolume(draft: ProgrammeDraft, candidates: readonly ProgrammeCandidate[]): Map<MuscleGroup, number> {
  const byId = new Map(candidates.map((c) => [c.id, c]));
  const volume = new Map<MuscleGroup, number>();
  for (const d of draft.days) {
    for (const x of d.exercises) {
      const c = byId.get(x.id)!;
      for (const m of c.primary) volume.set(m, (volume.get(m) ?? 0) + x.sets);
      for (const m of c.secondary) volume.set(m, (volume.get(m) ?? 0) + x.sets * SECONDARY_CONTRIBUTION);
    }
  }
  return volume;
}

/**
 * FITOS's checks on a read draft (§19.2): each session within the minutes
 * asked for (+15 %), each muscle at or under its MRV a week. Over either,
 * sets come off the biggest exercises first (never below
 * PROGRAMME_MIN_SETS), then — for time only — the last exercises (never
 * below PROGRAMME_MIN_EXERCISES). Every change is said in a line.
 */
export function fitProgramme(draft: ProgrammeDraft, candidates: readonly ProgrammeCandidate[], minutes: number): { draft: ProgrammeDraft; adjustments: string[] } {
  const adjustments: string[] = [];
  const byId = new Map(candidates.map((c) => [c.id, c]));
  const days = draft.days.map((d) => ({ name: d.name, exercises: d.exercises.map((x) => ({ ...x })) }));
  const limit = minutes * PROGRAMME_TIME_SLACK;

  for (const d of days) {
    const time = () => d.exercises.reduce((n, x) => n + x.sets, 0) * MINUTES_PER_WORKING_SET;
    if (time() <= limit) continue;
    while (time() > limit) {
      const biggest = d.exercises.reduce((a, x) => (x.sets > a.sets ? x : a));
      if (biggest.sets > PROGRAMME_MIN_SETS) biggest.sets -= 1;
      else if (d.exercises.length > PROGRAMME_MIN_EXERCISES) d.exercises.pop();
      else break;
    }
    adjustments.push(`${d.name} shortened to about ${Math.round(time())} minutes.`);
  }

  const volume = draftVolume({ ...draft, days }, candidates);
  for (const [muscle, sets] of [...volume].sort((a, b) => a[0].localeCompare(b[0]))) {
    const mrv = VOLUME_LANDMARKS[muscle].mrv;
    if (sets <= mrv) continue;
    let over = sets - mrv;
    const trimmable = days
      .flatMap((d) => d.exercises)
      .filter((x) => byId.get(x.id)!.primary.includes(muscle))
      .sort((a, b) => b.sets - a.sets);
    for (const x of trimmable) {
      while (over > 0 && x.sets > PROGRAMME_MIN_SETS) {
        x.sets -= 1;
        over -= 1;
      }
    }
    adjustments.push(`${muscle.charAt(0).toUpperCase()}${muscle.slice(1)} kept to about ${mrv} sets a week, the most FITOS plans.`);
  }
  return { draft: { ...draft, days }, adjustments };
}
