/**
 * Beta 6.1 (E19): the rules for an exercise's alternatives when the admin
 * panel edits them — the same rules the seed's tests hold (§12.6):
 *
 * - an alternative is another exercise, listed once per reason;
 * - it shares the movement pattern and at least one primary muscle;
 * - a retired exercise is not added (one already linked may stay);
 * - `equipment` and `preference` links go both ways, so the other exercise
 *   gains or loses the reverse link; `injury` links point one way, from the
 *   exercise to avoid toward the gentler one;
 * - no exercise ends with more than `max` alternatives.
 *
 * The API gathers the facts and applies the result in one transaction.
 */

export type AlternativeReason = 'equipment' | 'injury' | 'preference';

export interface AlternativeLink {
  readonly id: string;
  readonly reason: AlternativeReason;
}

export interface ExerciseFacts {
  readonly id: string;
  readonly slug: string;
  readonly movementPattern: string;
  readonly primaryMuscles: readonly string[];
  readonly retired: boolean;
  /** How many alternatives it lists now. */
  readonly alternatives: number;
}

export interface AlternativeProblem {
  readonly path: string;
  readonly issue: string;
}

export interface AlternativePlan {
  /** The reverse links to add on other exercises: `exerciseId` gains `alternativeId`. */
  readonly addReverse: readonly { exerciseId: string; alternativeId: string; reason: AlternativeReason }[];
  /** The reverse links to remove from other exercises. */
  readonly removeReverse: readonly { exerciseId: string; alternativeId: string; reason: AlternativeReason }[];
  /** Every exercise whose list changes (this one first), to mark as edited in the panel. */
  readonly touched: readonly string[];
}

const symmetric = (r: AlternativeReason): boolean => r !== 'injury';
const key = (l: AlternativeLink): string => `${l.id}:${l.reason}`;

export function planAlternatives(
  self: ExerciseFacts,
  before: readonly AlternativeLink[],
  after: readonly AlternativeLink[],
  facts: ReadonlyMap<string, ExerciseFacts>,
  max: number,
): { ok: true; plan: AlternativePlan } | { ok: false; problems: AlternativeProblem[] } {
  const problems: AlternativeProblem[] = [];
  const had = new Set(before.map(key));
  const seen = new Set<string>();
  if (after.length > max) problems.push({ path: 'items', issue: `at most ${max} alternatives` });
  after.forEach((link, i) => {
    const path = `items.${i}`;
    if (link.id === self.id) return void problems.push({ path, issue: 'an exercise cannot be its own alternative' });
    if (seen.has(key(link))) return void problems.push({ path, issue: 'listed twice for the same reason' });
    seen.add(key(link));
    const alt = facts.get(link.id);
    if (alt === undefined) return void problems.push({ path, issue: 'no such exercise' });
    if (alt.retired && !had.has(key(link))) return void problems.push({ path, issue: `${alt.slug} is retired` });
    if (alt.movementPattern !== self.movementPattern) return void problems.push({ path, issue: `${alt.slug} is a different movement (${alt.movementPattern}, not ${self.movementPattern})` });
    if (!alt.primaryMuscles.some((m) => self.primaryMuscles.includes(m))) problems.push({ path, issue: `${alt.slug} shares no primary muscle` });
  });
  if (problems.length > 0) return { ok: false, problems };

  const now = new Set(after.map(key));
  const added = after.filter((l) => symmetric(l.reason) && !had.has(key(l)));
  const removed = before.filter((l) => symmetric(l.reason) && !now.has(key(l)));
  // The other exercise's count after its reverse links change.
  const delta = new Map<string, number>();
  for (const l of added) delta.set(l.id, (delta.get(l.id) ?? 0) + 1);
  for (const l of removed) delta.set(l.id, (delta.get(l.id) ?? 0) - 1);
  for (const [id, d] of delta) {
    const other = facts.get(id)!;
    if (other.alternatives + d > max) problems.push({ path: 'items', issue: `${other.slug} would have more than ${max} alternatives` });
  }
  if (problems.length > 0) return { ok: false, problems };

  const changedOthers = [...new Set([...added, ...removed].map((l) => l.id))];
  const ownChanged = before.length !== after.length || after.some((l) => !had.has(key(l)));
  return {
    ok: true,
    plan: {
      addReverse: added.map((l) => ({ exerciseId: l.id, alternativeId: self.id, reason: l.reason })),
      removeReverse: removed.map((l) => ({ exerciseId: l.id, alternativeId: self.id, reason: l.reason })),
      touched: ownChanged ? [self.id, ...changedOthers] : changedOthers,
    },
  };
}
