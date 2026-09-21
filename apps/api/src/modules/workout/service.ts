/**
 * Sessions: what the user actually did (Phase 5). The ONLY caller of
 * packages/core's records / summary / prefill / mesocycle modules (§7.3,
 * §30). Rows → contract shapes here; no training rules live here, and
 * nothing here recommends a load — that is Phase 6.
 */
import { randomUUID } from 'node:crypto';

import { isoWeekKey } from '@fitos/core/training/mesocycle';
import { prefillSet } from '@fitos/core/training/prefill';
import { recommendProgression, type SessionLog } from '@fitos/core/training/progression';
import type { BodyPart } from '@fitos/core/training/generator';
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
  ProgressionDetail,
  ProgressionRecommendation,
  DeloadState,
  VolumeResponse,
  SessionExercise,
  SetPrefill,
  SessionListQuery,
  SessionListResponse,
  SessionSummary,
  StartSessionRequest,
  TodayResponse,
  WorkoutSession,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { PlannedExerciseJoined, ProgramBundle, TrainingRepository } from '../training/repository.js';
import { ProgressionAssembler } from './progression.js';
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

/** The numbers a set row opens with: core's rule, one entry per target. */
function prefillFor(targets: readonly PlannedSet[], last: LastPerformance | null, recommendation: ProgressionRecommendation | null = null): SetPrefill[] {
  const lastSets = (last?.sets ?? []).map((s) => ({ id: String(s.setIndex), setType: 'working' as const, weightKg: s.weightKg, reps: s.reps, rir: s.rir }));
  return targets.map((t) => {
    const p = prefillSet({ planned: t, lastPerformance: lastSets, recommendation });
    return { setIndex: p.setIndex, reps: p.reps, weightKg: p.weightKg, rir: p.rir, weightSource: p.weightSource };
  });
}

function targetsFor(program: ProgramBundle | null, plannedExerciseId: string | null): PlannedSet[] {
  if (program === null || plannedExerciseId === null) return [];
  return program.sets
    .filter((s) => s.plannedExerciseId === plannedExerciseId)
    .map((s) => ({ id: s.id, setIndex: s.setIndex, repsMin: s.repsMin, repsMax: s.repsMax, weightKg: num(s.weightKg), rir: s.rir }));
}

/* ------------------------------------------------------------ service -- */

export class WorkoutService {
  private readonly progression: ProgressionAssembler;

  constructor(
    private readonly repo: WorkoutRepository,
    private readonly training: TrainingRepository,
  ) {
    this.progression = new ProgressionAssembler(repo, training);
  }

  /**
   * Phase 6, per planned exercise: the engine's recommendation from the
   * lift's history, the prior best (for the PR moment), and — during an
   * accepted deload week — lighter targets with the plan's originals kept.
   */
  private static plannedView(
    program: ProgramBundle | null,
    plannedExerciseId: string | null,
    exerciseId: string,
    prior: readonly PriorWork[],
    tz: string,
    deloadActive: boolean,
  ): { targets: PlannedSet[]; originalTargets: PlannedSet[] | null; recommendation: ProgressionRecommendation | null; prefill: SetPrefill[] } {
    const original = targetsFor(program, plannedExerciseId);
    const last = lastPerformanceOf(prior, exerciseId);
    const planned: PlannedExerciseJoined | undefined = program?.exercises.find((x) => x.id === plannedExerciseId);
    if (planned === undefined) return { targets: original, originalTargets: null, recommendation: null, prefill: prefillFor(original, last) };
    const window = ProgressionAssembler.deloadWindow(program);
    const recommendation = ProgressionAssembler.recommendation(ProgressionAssembler.toSessionLogs(prior, exerciseId, tz, window), planned);
    if (deloadActive) {
      // Owner 12.4: × 0.9 of what was last lifted — not of a recommendation that may already be a reduction.
      const lastLoad = last?.sets.map((s) => s.weightKg ?? 0).reduce((a, b) => Math.max(a, b), 0) ?? null;
      const targets = ProgressionAssembler.deloaded(original, lastLoad === 0 || lastLoad === null ? null : lastLoad);
      const deloadRec: ProgressionRecommendation = {
        ...recommendation,
        action: 'deload',
        weightKg: targets[0]?.weightKg ?? null,
        targetRir: targets[0]?.rir ?? recommendation.targetRir,
        reason: 'Deload week: sets × 0.6, load × 0.9, two more reps in reserve than usual. The block restarts at week 1 when it ends.',
      };
      return { targets, originalTargets: original, recommendation: deloadRec, prefill: prefillFor(targets, last, deloadRec) };
    }
    return { targets: original, originalTargets: null, recommendation, prefill: prefillFor(original, last, recommendation) };
  }

  /* ------------------------------------------------------ rows → wire -- */

  private async toWire(userId: string, b: SessionBundle): Promise<WorkoutSession> {
    const program = b.session.programId !== null ? await this.training.programById(userId, b.session.programId) : null;
    const prior = await this.repo.priorWork(userId, [...new Set(b.exercises.map((x) => x.exerciseId))], b.session.id);
    const tz = await this.repo.userTimezone(userId);
    const window = ProgressionAssembler.deloadWindow(program);
    // The session's own start decides whether it is a deload session.
    const deloadActive = window !== null && b.session.startedAt >= window.startedAt && b.session.startedAt < window.endsAt;
    const exercises: SessionExercise[] = b.exercises.map((x) => {
      const view = WorkoutService.plannedView(program, x.plannedExerciseId, x.exerciseId, prior, tz, deloadActive);
      return {
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
      targets: view.targets,
      prefill: view.prefill,
      lastPerformance: lastPerformanceOf(prior, x.exerciseId),
      recommendation: view.recommendation,
      priorBest: ProgressionAssembler.priorBest(prior, x.exerciseId),
      originalTargets: view.originalTargets,
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
      };
    });
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
    // A client that seeded the session offline sends its own exercise ids
    // so the sets it logged against them replay cleanly.
    if (req.exercises !== undefined) {
      for (const [i, x] of req.exercises.entries()) {
        if (!(await this.repo.exerciseExists(x.exerciseId))) {
          throw new AppError('VALIDATION_FAILED', 'Unknown exercise.', [{ path: `exercises.${i}.exerciseId`, issue: 'unknown' }]);
        }
      }
      seeded = req.exercises.map((x) => ({
        clientExerciseId: x.clientExerciseId,
        exerciseId: x.exerciseId,
        plannedExerciseId: x.plannedExerciseId ?? null,
        orderIndex: x.orderIndex,
        supersetGroup: null,
      }));
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
    // §12.6: dropping (or swapping away) a PLANNED lift is a rejection; twice and a substitute is offered.
    if ((patch.removed === true || (patch.exerciseId !== undefined && patch.exerciseId !== x.exerciseId)) && x.plannedExerciseId !== null) {
      await this.repo.recordRejection(userId, x.exerciseId);
    }
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

    const tz = await this.repo.userTimezone(userId);
    // Volume cache (§9.4) for the week this session lands in.
    const completedOn = localDate(completedAt, tz);
    await this.progression.cacheWeek(userId, isoWeekKey(completedOn), await this.progression.volumeSets(userId, completedOn, tz));
    // Mesocycle week (owner 8.2 + 12.4): distinct ISO weeks trained since the last reset, capped at 8;
    // a deload week that has run its course closes here and the block restarts at week 1.
    if (b.session.programId !== null) {
      const program = await this.training.programById(userId, b.session.programId);
      if (program !== null) {
        const closed = await this.progression.closeElapsedDeload(program, completedAt);
        if (!closed) {
          const fresh = (await this.training.programById(userId, b.session.programId))!;
          await this.repo.setMesocycleWeek(b.session.programId, await this.progression.mesocycleWeek(fresh, tz));
        }
      }
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
    // Phase 6: deload state, neglect, substitutions.
    const volumeSets = await this.progression.volumeSets(userId, date, tz);
    const leadPrior = program === null ? prior : await this.repo.priorWork(userId, [...new Set(program.exercises.map((x) => x.exerciseId))]);
    const deload = await this.progression.deloadState(program, leadPrior, volumeSets, date, tz);
    const owned = ProgressionAssembler.owned(program);
    const { profile, limitations } = await this.training.profileInputs(userId);
    const substitutions = await this.progression.substitutions(
      userId,
      planned,
      profile?.equipment ?? [],
      limitations as BodyPart[],
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
        difficulty: x.difficulty,
        primaryMuscles: x.primaryMuscles,
        secondaryMuscles: x.secondaryMuscles,
        orderIndex: x.orderIndex,
        incrementKg: Number(x.incrementKg),
        ...(() => {
          const view = WorkoutService.plannedView(program, x.id, x.exerciseId, prior, tz, deload.state === 'active');
          return {
            targets: view.targets,
            prefill: view.prefill,
            recommendation: view.recommendation,
            originalTargets: view.originalTargets,
          };
        })(),
        lastPerformance: lastPerformanceOf(prior, x.exerciseId),
        priorBest: ProgressionAssembler.priorBest(prior, x.exerciseId),
        substitution: substitutions.get(x.id) ?? null,
      })),
      activeSession: active === null ? null : await this.toWire(userId, active),
      completedSessionId: completedToday?.id ?? null,
      mesocycleWeek: program?.program.mesocycleWeek ?? null,
      deload,
      neglected: this.progression.neglected(volumeSets, owned, date),
    };
  }

  /* ---------------------------------------------- Phase 6 endpoints -- */

  async volume(userId: string): Promise<VolumeResponse> {
    const tz = await this.repo.userTimezone(userId);
    const today = localDate(new Date(), tz);
    const program = await this.training.activeProgram(userId);
    const prior = program === null ? [] : await this.repo.priorWork(userId, [...new Set(program.exercises.map((x) => x.exerciseId))]);
    return this.progression.volume(userId, program, prior, today, tz);
  }

  async progressionDetail(userId: string, exerciseId: string): Promise<ProgressionDetail> {
    const tz = await this.repo.userTimezone(userId);
    const program = await this.training.activeProgram(userId);
    const planned = program?.exercises.find((x) => x.exerciseId === exerciseId) ?? null;
    const prior = await this.repo.priorWork(userId, [exerciseId]);
    const window = ProgressionAssembler.deloadWindow(program);
    const history = ProgressionAssembler.toSessionLogs(prior, exerciseId, tz, window);
    const name = planned?.name ?? (await this.training.exercisesById([exerciseId])).get(exerciseId)?.name;
    if (name === undefined) throw new AppError('NOT_FOUND', 'Unknown exercise.');
    const target = planned === null
      ? null
      : { repMin: planned.repMin, repMax: planned.repMax, targetRir: planned.targetRir, sets: planned.setCount, incrementKg: Number(planned.incrementKg) };
    const recommendation = planned === null
      ? { ...recommendProgressionFallback(history), basis: 'calculated' as const, sessionsConsidered: history.length }
      : ProgressionAssembler.recommendation(history, planned);
    return {
      exerciseId,
      name,
      target,
      recommendation,
      history: prior
        .filter((p) => p.exerciseId === exerciseId)
        .slice(0, 3)
        .map((p) => ({ sessionId: p.sessionId, date: localDate(p.completedAt, tz), sets: p.sets.map((s) => ({ setIndex: s.setIndex, weightKg: num(s.weightKg), reps: s.reps, rir: s.rir })) })),
    };
  }

  async acceptDeload(userId: string): Promise<DeloadState> {
    const program = await this.training.activeProgram(userId);
    if (program === null) throw new AppError('NOT_FOUND', 'No active programme.');
    const tz = await this.repo.userTimezone(userId);
    const today = localDate(new Date(), tz);
    const prior = await this.repo.priorWork(userId, [...new Set(program.exercises.map((x) => x.exerciseId))]);
    const state = await this.progression.deloadState(program, prior, await this.progression.volumeSets(userId, today, tz), today, tz);
    if (state.state === 'active') return state;
    if (state.state !== 'offered') {
      throw new AppError('CONFLICT', 'No deload is on offer.', [{ path: 'deload', issue: state.state }]);
    }
    await this.progression.acceptDeload(program, new Date());
    return (await this.today(userId)).deload;
  }

  async declineDeload(userId: string): Promise<DeloadState> {
    const program = await this.training.activeProgram(userId);
    if (program === null) throw new AppError('NOT_FOUND', 'No active programme.');
    const tz = await this.repo.userTimezone(userId);
    await this.progression.declineDeload(program, localDate(new Date(), tz));
    return (await this.today(userId)).deload;
  }
}

/** An ad-hoc lift with no plan row: the engine still answers, against a neutral 8–12 target. */
function recommendProgressionFallback(history: SessionLog[]) {
  return recommendProgression({ history, target: { repMin: 8, repMax: 12, targetRir: 2, sets: 3, incrementKg: 2.5 } });
}
