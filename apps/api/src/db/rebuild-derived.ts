/**
 * Rebuild every derived cache from its source rows (Phase 12; MASTER-SPEC
 * §9.4, ADR-018 — the spec names `scripts/rebuild-derived.ts`; it lives
 * beside the other database scripts because `scripts/` is not a workspace
 * package, owner D15). Deterministic and idempotent: running it twice
 * writes the same rows. The weight trend is not a cache — it is computed on
 * read and never stored — so there is nothing to rebuild for it.
 *
 *   - `daily_nutrition`       from live food-log item snapshots (Phase 8's rebuild);
 *   - `muscle_volume_weekly`  for EVERY ISO week with sets or a cached row
 *                             (the Phase 6 script covers only the last four);
 *   - `exercise_prs` + `set_logs.is_pr`  by replaying each user's completed
 *                             sessions in completion order through the same
 *                             core `detectPRs` the completion path uses, with
 *                             the same inputs in the same order.
 *
 *   pnpm --filter @fitos/api db:rebuild-derived
 */
import { and, asc, eq, inArray, isNull } from 'drizzle-orm';
import { isoWeekKey } from '@fitos/core/training/mesocycle';
import { detectPRs, type LoggedSet, type PriorSession } from '@fitos/core/training/records';
import type { VolumeSet } from '@fitos/core/training/volume';

import { createDatabase, type DatabaseHandle } from './client.js';
import { exercisePrs, muscleVolumeWeekly, sessionExercises, setLogs, users, workoutSessions, type SetLogRow } from './schema.js';
import { rebuildDailyNutrition } from '../modules/nutrition/log-repository.js';
import { TrainingRepository } from '../modules/training/repository.js';
import { ProgressionAssembler, localDate } from '../modules/workout/progression.js';
import { WorkoutRepository } from '../modules/workout/repository.js';

type Db = DatabaseHandle['db'];

export interface RebuildReport {
  readonly nutritionDays: number;
  readonly volumeWeeks: number;
  readonly prs: number;
}

const num = (s: string | null): number | null => (s === null ? null : Number(s));
const toLogged = (row: SetLogRow): LoggedSet => ({ id: row.id, setType: row.setType, weightKg: num(row.weightKg), reps: row.reps, rir: row.rir });

/** Every ISO week with sets or a cached row, rebuilt through the same `cacheWeek` the completion path uses. */
async function rebuildVolumeFor(db: Db, userId: string, timeZone: string): Promise<number> {
  const repo = new WorkoutRepository(db);
  const assembler = new ProgressionAssembler(repo, new TrainingRepository(db));
  const rows = await repo.volumeSets(userId, new Date(0));
  // The same mapping as ProgressionAssembler.volumeSets, over the whole history.
  const sets: VolumeSet[] = rows.map((r) => ({
    localDate: localDate(r.completedAt, timeZone),
    exerciseId: r.exerciseId,
    primaryMuscles: r.primaryMuscles,
    secondaryMuscles: r.secondaryMuscles,
    setType: r.setType,
    weightKg: num(r.weightKg),
    reps: r.reps,
  }));
  const cached = await db.selectDistinct({ w: muscleVolumeWeekly.isoWeek }).from(muscleVolumeWeekly).where(eq(muscleVolumeWeekly.userId, userId));
  const weeks = [...new Set([...cached.map((c) => c.w), ...sets.map((s) => isoWeekKey(s.localDate))])].sort();
  for (const week of weeks) await assembler.cacheWeek(userId, week, sets);
  return weeks.length;
}

/** PR rows for one user, replaying completed sessions in (completed_at, id) order. */
async function rebuildPrsFor(db: Db, userId: string): Promise<number> {
  const sessions = await db
    .select({ id: workoutSessions.id, completedAt: workoutSessions.completedAt })
    .from(workoutSessions)
    .where(and(eq(workoutSessions.userId, userId), eq(workoutSessions.status, 'completed'), isNull(workoutSessions.deletedAt)))
    .orderBy(asc(workoutSessions.completedAt), asc(workoutSessions.id));
  const ids = sessions.map((s) => s.id);
  const exerciseRows =
    ids.length === 0
      ? []
      : await db
          .select({ id: sessionExercises.id, sessionId: sessionExercises.sessionId, exerciseId: sessionExercises.exerciseId, orderIndex: sessionExercises.orderIndex })
          .from(sessionExercises)
          .where(and(inArray(sessionExercises.sessionId, ids), isNull(sessionExercises.removedAt)))
          .orderBy(asc(sessionExercises.orderIndex));
  const exIds = exerciseRows.map((x) => x.id);
  const setRows =
    exIds.length === 0
      ? []
      : await db
          .select()
          .from(setLogs)
          .where(and(inArray(setLogs.sessionExerciseId, exIds), isNull(setLogs.deletedAt)))
          .orderBy(asc(setLogs.sessionExerciseId), asc(setLogs.setIndex), asc(setLogs.loggedAt));

  const setsOf = new Map<string, SetLogRow[]>();
  for (const s of setRows) setsOf.set(s.sessionExerciseId, [...(setsOf.get(s.sessionExerciseId) ?? []), s]);

  // Prior work per lift: earlier sessions' WORKING sets, newest session first (as priorWork returns them).
  const prior = new Map<string, PriorSession[]>();
  const rows: (typeof exercisePrs.$inferInsert)[] = [];
  const prSetIds = new Set<string>();
  for (const session of sessions) {
    const mine = exerciseRows.filter((x) => x.sessionId === session.id);
    const lifts = [...new Set(mine.map((x) => x.exerciseId))];
    for (const exerciseId of lifts) {
      const current = mine.filter((x) => x.exerciseId === exerciseId).flatMap((x) => setsOf.get(x.id) ?? []).map(toLogged);
      for (const pr of detectPRs({ prior: prior.get(exerciseId) ?? [], current })) {
        rows.push({
          userId,
          exerciseId,
          prType: pr.prType,
          value: pr.value.toFixed(2),
          previous: pr.previous.toFixed(2),
          reason: pr.reason,
          achievedAt: session.completedAt!,
          setLogId: pr.setLogId,
        });
        prSetIds.add(pr.setLogId);
      }
    }
    for (const exerciseId of lifts) {
      const working = mine
        .filter((x) => x.exerciseId === exerciseId)
        .flatMap((x) => setsOf.get(x.id) ?? [])
        .filter((s) => s.setType === 'working')
        .sort((a, b) => a.setIndex - b.setIndex);
      if (working.length > 0) prior.set(exerciseId, [{ sessionId: session.id, sets: working.map(toLogged) }, ...(prior.get(exerciseId) ?? [])]);
    }
  }

  await db.transaction(async (tx) => {
    await tx.delete(exercisePrs).where(eq(exercisePrs.userId, userId));
    const allSetIds = setRows.map((s) => s.id);
    if (allSetIds.length > 0) await tx.update(setLogs).set({ isPr: false }).where(inArray(setLogs.id, allSetIds));
    if (rows.length > 0) {
      await tx.insert(exercisePrs).values(rows).onConflictDoNothing({ target: [exercisePrs.setLogId, exercisePrs.prType] });
      await tx.update(setLogs).set({ isPr: true }).where(inArray(setLogs.id, [...prSetIds]));
    }
  });
  return rows.length;
}

export async function rebuildDerivedOn(db: Db, log: (line: string) => void = () => undefined): Promise<RebuildReport> {
  const { days } = await rebuildDailyNutrition(db);
  const people = await db.select({ id: users.id, timezone: users.timezone }).from(users).orderBy(asc(users.id));
  let volumeWeeks = 0;
  let prs = 0;
  for (const u of people) {
    volumeWeeks += await rebuildVolumeFor(db, u.id, u.timezone);
    prs += await rebuildPrsFor(db, u.id);
  }
  const report = { nutritionDays: days, volumeWeeks, prs };
  log(`rebuilt ${days} daily_nutrition day(s), ${volumeWeeks} muscle_volume_weekly week(s), ${prs} exercise_prs row(s) for ${people.length} user(s)`);
  return report;
}

export async function rebuildDerived(connectionString: string, log: (line: string) => void = () => undefined): Promise<RebuildReport> {
  const handle = createDatabase(connectionString);
  try {
    return await rebuildDerivedOn(handle.db, log);
  } finally {
    await handle.client.end({ timeout: 5 });
  }
}

const invokedDirectly = process.argv[1]?.endsWith('rebuild-derived.ts') === true || process.argv[1]?.endsWith('rebuild-derived.js') === true;
if (invokedDirectly) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  rebuildDerived(url, console.log).catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
