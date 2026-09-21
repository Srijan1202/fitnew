/**
 * Sessions: what the user actually did (Phase 5). The ONLY caller of
 * packages/core's records / summary / prefill / mesocycle modules (§7.3,
 * §30). Rows → contract shapes here; no training rules live here, and
 * nothing here recommends a load — that is Phase 6.
 */
import { randomUUID } from 'node:crypto';

import { mesocycleWeekFrom } from '@fitos/core/training/mesocycle';
import { detectPRs, type LoggedSet, type PriorSession } from '@fitos/core/training/records';
import { summarizeSession } from '@fitos/core/training/session-summary';
import type {
  AddSessionExerciseRequest,
  CompleteSessionRequest,
  LastPerformance,
  LogSetsRequest,
  MuscleGroup,
  PatchSessionExerciseRequest,
  PatchSetRequest,
  PersonalRecord,
  PlannedSet,
  SessionExercise,
  SessionListQuery,
  SessionListResponse,
  SessionSummary,
  StartSessionRequest,
  TodayResponse,
  WorkoutSession,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { ProgramBundle, TrainingRepository } from '../training/repository.js';
import {
  UniqueViolation,
  type NewSetLog,
  type PriorWork,
  type SessionBundle,
  type SessionExerciseJoined,
  type WorkoutRepository,
} from './repository.js';

/* ------------------------------------------------------------ helpers -- */

const num = (s: string | null): number | null => (s === null ? null : Number(s));

/** "yyyy-mm-dd" of an instant in an IANA zone. */
export function localDate(at: Date, timeZone: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(at);
}

/** ISO day of week (1 = Monday) of a local date. */
export function isoDayOfWeek(localDay: string): number {
  const [y, m, d] = localDay.split('-').map(Number) as [number, number, number];
  const dow = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return dow === 0 ? 7 : dow;
}

function toLogged(row: { id: string; setType: 'warmup' | 'working' | 'drop' | 'backoff'; weightKg: string | null; reps: number; rir: number | null }): LoggedSet {
  return { id: row.id, setType: row.setType, weightKg: num(row.weightKg), reps: row.reps, rir: row.rir };
}

function lastPerformanceOf(prior: readonly PriorWork[], exerciseId: string): LastPerformance | null {
  const first = prior.find((p) => p.exerciseId === exerciseId);
  if (first === undefined) return null;
  return {
    sessionId: first.sessionId,
    completedAt: first.completedAt.toISOString(),
    sets: first.sets.map((s) => ({ setIndex: s.setIndex, weightKg: num(s.weightKg), reps: s.reps, rir: s.rir })),
  };
}

function targetsFor(program: ProgramBundle | null, plannedExerciseId: string | null): PlannedSet[] {
  if (program === null || plannedExerciseId === null) return [];
  return program.sets
    .filter((s) => s.plannedExerciseId === plannedExerciseId)
    .map((s) => ({ setIndex: s.setIndex, repsMin: s.repsMin, repsMax: s.repsMax, weightKg: num(s.weightKg), rir: s.rir }));
}

/* ------------------------------------------------------------ service -- */

export class WorkoutService {
  constructor(
    private readonly repo: WorkoutRepository,
    private readonly training: TrainingRepository,
  ) {}

  /* ------------------------------------------------------ rows → wire -- */

  private async toWire(userId: string, b: SessionBundle): Promise<WorkoutSession> {
    const program = b.session.programId !== null ? await this.training.programById(userId, b.session.programId) : null;
    const prior = await this.repo.priorWork(userId, [...new Set(b.exercises.map((x) => x.exerciseId))], b.session.id);
    const exercises: SessionExercise[] = b.exercises.map((x) => ({
      id: x.id,
      clientExerciseId: x.clientExerciseId,
      exerciseId: x.exerciseId,
      slug: x.slug,
      name: x.name,
      movementPattern: x.movementPattern as SessionExercise['movementPattern'],
      equipment: x.equipment,
      difficulty: x.difficulty as SessionExercise['difficulty'],
      primaryMuscles: x.primaryMuscles,
      secondaryMuscles: x.secondaryMuscles,
      incrementKg: Number(x.defaultIncrementKg),
      orderIndex: x.orderIndex,
      supersetGroup: x.supersetGroup,
      plannedExerciseId: x.plannedExerciseId,
      targets: targetsFor(program, x.plannedExerciseId),
      lastPerformance: lastPerformanceOf(prior, x.exerciseId),
      sets: b.sets
        .filter((s) => s.sessionExerciseId === x.id)
        .map((s) => ({
          id: s.id,
          clientSetId: s.clientSetId,
          setIndex: s.setIndex,
          setType: s.setType,
          weightKg: num(s.weightKg),
          reps: s.reps,
          rir: s.rir,
          isPr: s.isPr,
          loggedAt: s.loggedAt.toISOString(),
          plannedSetId: s.plannedSetId,
        })),
    }));
    return {
      id: b.session.id,
      clientSessionId: b.session.clientSessionId,
      status: b.session.status,
      programId: b.session.programId,
      programDayId: b.session.programDayId,
      name: b.session.name,
      startedAt: b.session.startedAt.toISOString(),
      completedAt: b.session.completedAt?.toISOString() ?? null,
      durationSeconds: b.session.durationSeconds,
      notes: b.session.notes,
      exercises,
      summary: b.session.status === 'completed' ? this.summaryOf(b) : null,
    };
  }

  private summaryOf(b: SessionBundle): SessionSummary {
    const nameOf = new Map(b.exercises.map((x) => [x.exerciseId, x.name]));
    const core = summarizeSession({
      startedAt: b.session.startedAt.toISOString(),
      completedAt: (b.session.completedAt ?? b.session.startedAt).toISOString(),
      exercises: b.exercises.map((x) => ({
        exerciseId: x.exerciseId,
        name: x.name,
        primaryMuscles: x.primaryMuscles,
        secondaryMuscles: x.secondaryMuscles,
        sets: b.sets.filter((s) => s.sessionExerciseId === x.id).map(toLogged),
      })),
    });
    const prs: PersonalRecord[] = b.prs.map((p) => ({
      prType: p.prType as PersonalRecord['prType'],
      exerciseId: p.exerciseId,
      exerciseName: nameOf.get(p.exerciseId) ?? 'Exercise',
      value: Number(p.value),
      previous: Number(p.previous),
      setLogId: p.setLogId,
      reason: p.reason,
    }));
    return { ...core, hardSetsByMuscle: core.hardSetsByMuscle as Record<MuscleGroup, number>, prs };
  }

  private async owned(userId: string, id: string): Promise<SessionBundle> {
    const b = await this.repo.byId(userId, id);
    if (b === null) throw new AppError('NOT_FOUND', 'No such session.');
    return b;
  }

  private static assertOpen(b: SessionBundle, merge = false): void {
    if (b.session.status === 'active') return;
    if (b.session.status === 'completed' && merge) return;
    throw new AppError('CONFLICT', `This session is ${b.session.status}.`, [{ path: 'session', issue: b.session.status }]);
  }

  /* ---------------------------------------------------------- start -- */

  async start(userId: string, req: StartSessionRequest): Promise<{ session: WorkoutSession; created: boolean }> {
    let programId: string | null = null;
    let name = 'Session';
    let seeded: { clientExerciseId: string; exerciseId: string; plannedExerciseId: string | null; orderIndex: number; supersetGroup: number | null }[] = [];
    if (req.programDayId !== undefined) {
      const program = await this.training.activeProgram(userId);
      const day = program?.days.find((d) => d.id === req.programDayId);
      if (program === null || program === undefined || day === undefined) {
        throw new AppError('NOT_FOUND', 'That day is not in your active programme.');
      }
      programId = program.program.id;
      name = day.isRest ? 'Session' : day.sessionName;
      seeded = program.exercises
        .filter((x) => x.programDayId === day.id)
        .map((x) => ({ clientExerciseId: randomUUID(), exerciseId: x.exerciseId, plannedExerciseId: x.id, orderIndex: x.orderIndex, supersetGroup: null }));
    }
    try {
      const { bundle, created } = await this.repo.create(
        userId,
        { clientSessionId: req.clientSessionId, programId, programDayId: req.programDayId ?? null, name, startedAt: new Date(req.startedAt) },
        seeded,
      );
      return { session: await this.toWire(userId, bundle), created };
    } catch (error) {
      if (error instanceof UniqueViolation && error.constraint === 'one_active_session') {
        const active = await this.repo.active(userId);
        throw new AppError('CONFLICT', 'A session is already in progress. Finish or abandon it first.', [
          { path: 'activeSessionId', issue: active?.session.id ?? 'unknown' },
        ]);
      }
      throw error;
    }
  }

  async get(userId: string, id: string): Promise<WorkoutSession> {
    return this.toWire(userId, await this.owned(userId, id));
  }

  /* ----------------------------------------------------------- sets -- */

  async logSets(userId: string, id: string, req: LogSetsRequest): Promise<WorkoutSession> {
    const b = await this.owned(userId, id);
    WorkoutService.assertOpen(b, req.merge);
    const byId = new Map(b.exercises.map((x) => [x.id, x]));
    const byClient = new Map(b.exercises.map((x) => [x.clientExerciseId, x]));
    const rows: NewSetLog[] = req.sets.map((s, i) => {
      const x = s.sessionExerciseId !== undefined ? byId.get(s.sessionExerciseId) : byClient.get(s.clientExerciseId!);
      if (x === undefined) {
        throw new AppError('VALIDATION_FAILED', 'That exercise is not in this session.', [{ path: `sets.${i}`, issue: 'unknown exercise' }]);
      }
      return {
        clientSetId: s.clientSetId,
        sessionExerciseId: x.id,
        plannedSetId: s.plannedSetId ?? null,
        setIndex: s.setIndex,
        setType: s.setType,
        weightKg: s.weightKg === null ? null : s.weightKg.toFixed(2),
        reps: s.reps,
        rir: s.rir,
        loggedAt: new Date(s.loggedAt),
      };
    });
    try {
      await this.repo.insertSets(rows);
    } catch (error) {
      const e = error as { code?: string; constraint_name?: string };
      if (e?.code === '23505' && e.constraint_name === 'set_logs_live_position') {
        throw new AppError('CONFLICT', 'A set already exists at that position; correct it instead of logging it twice.', [
          { path: 'sets', issue: 'position taken' },
        ]);
      }
      throw error;
    }
    return this.get(userId, id);
  }

  private async ownedSet(userId: string, id: string, setId: string): Promise<SessionBundle> {
    const b = await this.owned(userId, id);
    if (!b.sets.some((s) => s.id === setId)) throw new AppError('NOT_FOUND', 'No such set in this session.');
    return b;
  }

  async patchSet(userId: string, id: string, setId: string, patch: PatchSetRequest): Promise<WorkoutSession> {
    const b = await this.ownedSet(userId, id, setId);
    WorkoutService.assertOpen(b, true);
    await this.repo.updateSet(setId, {
      ...(patch.setType !== undefined ? { setType: patch.setType } : {}),
      ...(patch.weightKg !== undefined ? { weightKg: patch.weightKg === null ? null : patch.weightKg.toFixed(2) } : {}),
      ...(patch.reps !== undefined ? { reps: patch.reps } : {}),
      ...(patch.rir !== undefined ? { rir: patch.rir } : {}),
    });
    return this.get(userId, id);
  }

  async deleteSet(userId: string, id: string, setId: string): Promise<WorkoutSession> {
    const b = await this.ownedSet(userId, id, setId);
    WorkoutService.assertOpen(b, true);
    await this.repo.softDeleteSet(setId);
    return this.get(userId, id);
  }

  /* ------------------------------------------------------ exercises -- */

  async addExercise(userId: string, id: string, req: AddSessionExerciseRequest): Promise<WorkoutSession> {
    const b = await this.owned(userId, id);
    WorkoutService.assertOpen(b);
    if (!(await this.repo.exerciseExists(req.exerciseId))) {
      throw new AppError('VALIDATION_FAILED', 'Unknown exercise.', [{ path: 'exerciseId', issue: 'unknown' }]);
    }
    const orderIndex = req.orderIndex ?? (b.exercises.length === 0 ? 0 : Math.max(...b.exercises.map((x) => x.orderIndex)) + 1);
    await this.repo.addExercise(id, {
      clientExerciseId: req.clientExerciseId,
      exerciseId: req.exerciseId,
      plannedExerciseId: req.plannedExerciseId ?? null,
      orderIndex,
      supersetGroup: req.supersetGroup ?? null,
    });
    // Insertion in the middle: renumber so order stays dense and unique.
    const after = await this.owned(userId, id);
    const inserted = after.exercises.find((x) => x.clientExerciseId === req.clientExerciseId);
    if (inserted !== undefined && req.orderIndex !== undefined) {
      const others = after.exercises.filter((x) => x.id !== inserted.id).sort((a, c) => a.orderIndex - c.orderIndex);
      const ordered = [...others.slice(0, req.orderIndex).map((x) => x.id), inserted.id, ...others.slice(req.orderIndex).map((x) => x.id)];
      await this.repo.reorder(id, ordered);
    }
    return this.get(userId, id);
  }

  async patchExercise(userId: string, id: string, exerciseId: string, patch: PatchSessionExerciseRequest): Promise<WorkoutSession> {
    const b = await this.owned(userId, id);
    WorkoutService.assertOpen(b);
    const x: SessionExerciseJoined | undefined = b.exercises.find((e) => e.id === exerciseId);
    if (x === undefined) throw new AppError('NOT_FOUND', 'No such exercise in this session.');
    if (patch.exerciseId !== undefined && !(await this.repo.exerciseExists(patch.exerciseId))) {
      throw new AppError('VALIDATION_FAILED', 'Unknown exercise.', [{ path: 'exerciseId', issue: 'unknown' }]);
    }
    await this.repo.updateExercise(exerciseId, {
      ...(patch.supersetGroup !== undefined ? { supersetGroup: patch.supersetGroup } : {}),
      ...(patch.exerciseId !== undefined ? { exerciseId: patch.exerciseId } : {}),
      ...(patch.removed === true ? { removed: true } : {}),
    });
    if (patch.orderIndex !== undefined) {
      const others = b.exercises.filter((e) => e.id !== exerciseId).map((e) => e.id);
      const at = Math.min(patch.orderIndex, others.length);
      await this.repo.reorder(id, [...others.slice(0, at), exerciseId, ...others.slice(at)]);
    } else if (patch.removed === true) {
      await this.repo.reorder(id, b.exercises.filter((e) => e.id !== exerciseId).map((e) => e.id));
    }
    return this.get(userId, id);
  }

  /* ------------------------------------------------------- finishing -- */

  async complete(userId: string, id: string, req: CompleteSessionRequest): Promise<WorkoutSession> {
    const b = await this.owned(userId, id);
    // Idempotent: completing again returns the same session and summary.
    if (b.session.status === 'completed') return this.toWire(userId, b);
    if (b.session.status === 'abandoned') {
      throw new AppError('CONFLICT', 'This session was abandoned.', [{ path: 'session', issue: 'abandoned' }]);
    }
    const completedAt = new Date(req.completedAt);
    const durationSeconds = Math.max(0, Math.round((completedAt.getTime() - b.session.startedAt.getTime()) / 1000));
    await this.repo.finish(id, { status: 'completed', completedAt, durationSeconds, notes: req.notes ?? null });

    // Records: this session's working sets against everything before it.
    const exerciseIds = [...new Set(b.exercises.map((x) => x.exerciseId))];
    const prior = await this.repo.priorWork(userId, exerciseIds, id);
    const prRows: { exerciseId: string; prType: 'weight' | 'reps' | '1rm_est' | 'volume'; value: number; previous: number; reason: string; setLogId: string }[] = [];
    for (const exerciseId of exerciseIds) {
      const priorSessions: PriorSession[] = prior
        .filter((p) => p.exerciseId === exerciseId)
        .map((p) => ({ sessionId: p.sessionId, sets: p.sets.map(toLogged) }));
      const current = b.exercises
        .filter((x) => x.exerciseId === exerciseId)
        .flatMap((x) => b.sets.filter((s) => s.sessionExerciseId === x.id))
        .map(toLogged);
      for (const pr of detectPRs({ prior: priorSessions, current })) {
        prRows.push({ exerciseId, prType: pr.prType, value: pr.value, previous: pr.previous, reason: pr.reason, setLogId: pr.setLogId });
      }
    }
    await this.repo.recordPrs(userId, completedAt, prRows);

    // Mesocycle week (owner 8.2): distinct ISO weeks trained, in the user's calendar, capped at 8.
    if (b.session.programId !== null) {
      const tz = await this.repo.userTimezone(userId);
      const dates = (await this.repo.completedAtOfProgram(b.session.programId)).map((d) => localDate(d, tz));
      await this.repo.setMesocycleWeek(b.session.programId, mesocycleWeekFrom(dates));
    }
    return this.get(userId, id);
  }

  async abandon(userId: string, id: string): Promise<WorkoutSession> {
    const b = await this.owned(userId, id);
    if (b.session.status === 'abandoned') return this.toWire(userId, b);
    if (b.session.status === 'completed') {
      throw new AppError('CONFLICT', 'This session is already completed.', [{ path: 'session', issue: 'completed' }]);
    }
    const now = new Date();
    await this.repo.finish(id, {
      status: 'abandoned',
      completedAt: now,
      durationSeconds: Math.max(0, Math.round((now.getTime() - b.session.startedAt.getTime()) / 1000)),
      notes: null,
    });
    return this.get(userId, id);
  }

  /* --------------------------------------------------------- history -- */

  async list(userId: string, q: SessionListQuery): Promise<SessionListResponse> {
    const rows = await this.repo.list(userId, {
      limit: q.limit,
      ...(q.before !== undefined ? { before: new Date(q.before) } : {}),
      ...(q.status !== undefined ? { status: q.status } : {}),
    });
    const items = rows.map((r) => ({
      id: r.id,
      status: r.status,
      name: r.name,
      startedAt: r.startedAt.toISOString(),
      completedAt: r.completedAt?.toISOString() ?? null,
      durationSeconds: r.durationSeconds,
      exerciseCount: r.exerciseCount,
      workingSets: r.workingSets,
      tonnageKg: Math.round(Number(r.tonnageKg) * 10) / 10,
      prCount: r.prCount,
    }));
    const last = items[items.length - 1];
    return { items, nextBefore: items.length === q.limit && last !== undefined ? last.startedAt : null };
  }

  /* ----------------------------------------------------------- today -- */

  async today(userId: string, dayOfWeek?: number): Promise<TodayResponse> {
    const tz = await this.repo.userTimezone(userId);
    const now = new Date();
    const date = localDate(now, tz);
    const dow = dayOfWeek ?? isoDayOfWeek(date);
    const program = await this.training.activeProgram(userId);
    const day = program?.days.find((d) => d.dayOfWeek === dow) ?? null;
    const planned = program !== null && day !== null ? program.exercises.filter((x) => x.programDayId === day.id) : [];
    const prior = await this.repo.priorWork(userId, [...new Set(planned.map((x) => x.exerciseId))]);
    const active = await this.repo.active(userId);
    // "Done for today": any session completed on this local date.
    const completedToday = (await this.repo.list(userId, { limit: 20, status: 'completed' })).find(
      (s) => s.completedAt !== null && localDate(s.completedAt, tz) === date,
    );
    return {
      date,
      dayOfWeek: dow,
      programId: program?.program.id ?? null,
      programDayId: day?.id ?? null,
      sessionName: day === null || day.isRest ? null : day.sessionName,
      isRest: day === null ? true : day.isRest,
      focus: day?.focus ?? [],
      exercises: planned.map((x) => ({
        plannedExerciseId: x.id,
        exerciseId: x.exerciseId,
        slug: x.slug,
        name: x.name,
        movementPattern: x.movementPattern,
        equipment: x.equipment,
        primaryMuscles: x.primaryMuscles,
        orderIndex: x.orderIndex,
        incrementKg: Number(x.incrementKg),
        targets: targetsFor(program, x.id),
        lastPerformance: lastPerformanceOf(prior, x.exerciseId),
      })),
      activeSession: active === null ? null : await this.toWire(userId, active),
      completedSessionId: completedToday?.id ?? null,
    };
  }
}
