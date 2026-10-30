/**
 * Running (beta 4.0, ADR-038): a finished run comes in once, with the
 * phone's client id; the server works out every figure from the track with
 * packages/core and keeps the run. The phone's own figures were its live
 * view; what is kept and shown afterwards is this.
 */
import { EFFORT_KEYS, type CreateRunRequest, type EffortKey, type PatchRunRequest, type RunDetail, type RunGoal, type RunList, type RunSummary, type RunWorkout, type RunningRecords } from '@fitos/contracts';
import { localDateOf, addDays } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';
import { summarizeTrack, summarizeTreadmill, type RunSummary as CoreSummary } from '@fitos/core/running/summary';
import { EFFORTS_VERSION, bestEfforts } from '@fitos/core/running/efforts';
import { LapError, checkMarks, lapsOf } from '@fitos/core/running/laps';
import { TrackError, decodeTrack, type EncodedTrack } from '@fitos/core/running/track';

import type { RunRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { EffortsRepository, RankedEffort } from './efforts-repository.js';
import type { PlanRepository } from './plan-repository.js';
import type { RunningRepository } from './repository.js';

export const RUN_PAGE_SIZE = 20;

/** Beta 4.2: older runs worked out a batch a records request, so no request runs long. */
export const EFFORTS_BATCH = 200;

const num = (v: string | null): number | null => (v === null ? null : Number(v));

function trackOf(row: RunRow): EncodedTrack | null {
  if (row.trackPoints === null || row.trackBreaks === null || row.trackElevation === null) return null;
  return { v: 1, points: row.trackPoints, breaks: row.trackBreaks, elevation: row.trackElevation };
}

export function toSummary(row: RunRow, recordKeys: readonly EffortKey[] = []): RunSummary {
  return {
    id: row.clientRunId,
    kind: row.kind,
    name: row.name,
    startedAt: row.startedAt.toISOString(),
    endedAt: row.endedAt.toISOString(),
    durationSeconds: row.durationSeconds,
    distanceM: Number(row.distanceM),
    avgPaceSecPerKm: num(row.avgPaceSecPerKm),
    elevationGainM: num(row.elevationGainM),
    calories: row.calories,
    effort: row.effort,
    outline: row.outline,
    recordKeys: [...recordKeys],
    source: row.source,
    hrAvg: row.hrAvg,
    hrMax: row.hrMax,
    cadenceAvg: row.cadenceAvg,
    cadenceMax: row.cadenceMax,
  };
}

export function toDetail(row: RunRow, plannedRunId: string | null = null, efforts: readonly RankedEffort[] = []): RunDetail {
  const track = trackOf(row);
  // Splits, the chart and the laps are computed on read, from the kept track.
  const decoded = track === null ? null : decodeTrack(track);
  const computed = decoded === null ? null : summarizeTrack(decoded, row.durationSeconds, null);
  const goal: RunGoal =
    row.goalKind === 'free'
      ? { kind: 'free', value: null }
      : row.goalKind === 'race'
        ? { kind: 'race', value: row.goalValue, targetSeconds: row.goalTargetSeconds!, split: row.goalSplit as 'even' | 'negative' }
        : { kind: row.goalKind, value: row.goalValue };
  return {
    ...toSummary(row, efforts.filter((e) => e.rank === 1).map((e) => e.key)),
    note: row.note,
    goal,
    track: track === null ? null : { ...track, breaks: [...track.breaks] },
    splitsKm: computed === null ? [] : [...computed.splitsKm],
    splitsMi: computed === null ? [] : [...computed.splitsMi],
    series: computed === null ? [] : [...computed.series],
    workout: (row.workout as RunWorkout | null) ?? null,
    laps: decoded === null || row.lapMarks === null ? [] : lapsOf(decoded, row.lapMarks),
    plannedRunId,
    efforts: efforts.map((e) => ({ key: e.key, seconds: e.seconds, startM: e.startM, rank: e.rank })),
  };
}

export class RunningService {
  constructor(
    private readonly repo: RunningRepository,
    private readonly plans: PlanRepository,
    private readonly efforts: EffortsRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /**
   * Beta 4.2: a run's best efforts by the current rules (worked out now if
   * missing or older), ranked among the user's.
   */
  private async effortsOf(row: RunRow): Promise<RankedEffort[]> {
    const track = trackOf(row);
    if (track === null) return [];
    if (row.effortsVersion < EFFORTS_VERSION) {
      await this.efforts.replace(row.id, row.userId, bestEfforts(decodeTrack(track)), EFFORTS_VERSION);
    }
    return this.efforts.ranked(row.userId, row.id);
  }

  private async detail(row: RunRow): Promise<RunDetail> {
    const plannedRunId = await this.plans.plannedFor(row.id);
    return toDetail(row, plannedRunId, await this.effortsOf(row));
  }

  /** 201 with the run the first time; 200 with the same run on a replay. */
  async create(userId: string, req: CreateRunRequest): Promise<{ created: boolean; body: RunDetail }> {
    const existing = await this.repo.byClientId(req.clientRunId);
    if (existing !== null) return this.replay(userId, existing);
    // Beta 4.5: a watch run already imported (another phone, a reinstall) is that run.
    if (req.externalId !== undefined) {
      const imported = await this.repo.byExternalId(userId, req.externalId);
      if (imported !== null) return this.replay(userId, imported);
    }

    const tz = await this.repo.timezoneOf(userId);
    const startedAt = new Date(req.startedAt);
    const weightKg = await this.repo.weightOn(userId, localDateOf(startedAt, tz));
    let summary: CoreSummary;
    if (req.track !== undefined) {
      try {
        summary = summarizeTrack(decodeTrack(req.track), req.durationSeconds, weightKg);
      } catch (e) {
        if (e instanceof TrackError) throw new AppError('VALIDATION_FAILED', e.message, [{ path: 'track', issue: e.message }]);
        throw e;
      }
    } else {
      summary = summarizeTreadmill(req.distanceM!, req.durationSeconds, weightKg);
    }
    if (req.laps !== undefined) {
      try {
        checkMarks(req.laps, req.workout!.steps.length);
      } catch (e) {
        if (e instanceof LapError) throw new AppError('VALIDATION_FAILED', e.message, [{ path: 'laps', issue: e.message }]);
        throw e;
      }
    }
    // Beta 4.1: the plan's run this one did — the one named, else the day's still-planned run.
    let plannedId: string | null;
    if (req.plannedRunId !== undefined) {
      const planned = await this.plans.mine(userId, req.plannedRunId);
      if (planned === null) throw new AppError('NOT_FOUND', 'No such planned run.', [{ path: 'plannedRunId', issue: 'not found' }]);
      plannedId = planned.status === 'planned' ? planned.id : null;
    } else {
      plannedId = (await this.plans.on(userId, localDateOf(startedAt, tz))).find((p) => p.status === 'planned')?.id ?? null;
    }

    const row = await this.repo.insert({
      userId,
      clientRunId: req.clientRunId,
      kind: req.kind,
      name: req.name,
      note: req.note ?? null,
      effort: req.effort ?? null,
      startedAt,
      endedAt: new Date(req.endedAt),
      durationSeconds: req.durationSeconds,
      goalKind: req.goal.kind,
      goalValue: req.goal.value,
      goalTargetSeconds: req.goal.targetSeconds ?? null,
      goalSplit: req.goal.split ?? null,
      trackPoints: req.track?.points ?? null,
      trackBreaks: req.track === undefined ? null : [...req.track.breaks],
      trackElevation: req.track?.elevation ?? null,
      distanceM: summary.distanceM.toFixed(1),
      avgPaceSecPerKm: summary.avgPaceSecPerKm === null ? null : summary.avgPaceSecPerKm.toFixed(1),
      elevationGainM: summary.elevationGainM === null ? null : summary.elevationGainM.toFixed(1),
      calories: summary.calories,
      outline: summary.outline.map(([lat, lon]) => [lat, lon] as [number, number]),
      workout: req.workout === undefined ? null : { name: req.workout.name, steps: [...req.workout.steps] },
      lapMarks: req.laps === undefined ? null : [...req.laps],
      source: req.source ?? 'phone',
      externalId: req.externalId ?? null,
      hrAvg: req.hrAvg ?? null,
      hrMax: req.hrMax ?? null,
      cadenceAvg: req.cadenceAvg ?? null,
      cadenceMax: req.cadenceMax ?? null,
    });
    // Two uploads racing on one id: the loser reads the winner's row.
    if (row === null) return this.replay(userId, (await this.repo.byClientId(req.clientRunId))!);
    const linked = plannedId !== null && (await this.plans.link(plannedId, row.id)) ? plannedId : null;
    // Beta 4.2: its best efforts, and any distance first it reached.
    const efforts = await this.effortsOf(row);
    await this.efforts.awardBadges(userId);
    return { created: true, body: toDetail(row, linked, efforts) };
  }

  private async replay(userId: string, row: RunRow): Promise<{ created: boolean; body: RunDetail }> {
    if (row.userId !== userId) throw new AppError('CONFLICT', 'That run id is already taken.', [{ path: 'clientRunId', issue: 'taken' }]);
    return { created: false, body: await this.detail(row) };
  }

  async get(userId: string, id: string): Promise<RunDetail> {
    const row = await this.repo.mine(userId, id);
    if (row === null) throw new AppError('NOT_FOUND', 'No such run.');
    return this.detail(row);
  }

  async list(userId: string, before: string | undefined, limit: number | undefined): Promise<RunList> {
    const size = limit ?? RUN_PAGE_SIZE;
    const tz = await this.repo.timezoneOf(userId);
    const today = localDateOf(this.now(), tz);
    const weekStart = addDays(today, 1 - isoWeekday(today));
    const monthStart = `${today.slice(0, 7)}-01`;
    const [rows, week, month] = await Promise.all([
      this.repo.page(userId, before === undefined ? null : new Date(before), size + 1),
      this.repo.totalsSince(userId, tz, weekStart),
      this.repo.totalsSince(userId, tz, monthStart),
    ]);
    const more = rows.length > size;
    const pageRows = more ? rows.slice(0, size) : rows;
    const records = await this.efforts.recordKeys(userId, pageRows.map((r) => r.id));
    return {
      runs: pageRows.map((r) => toSummary(r, records.get(r.id) ?? [])),
      nextBefore: more ? pageRows[pageRows.length - 1]!.startedAt.toISOString() : null,
      totals: {
        week: { ...week, distanceM: Math.round(week.distanceM * 10) / 10 },
        month: { ...month, distanceM: Math.round(month.distanceM * 10) / 10 },
      },
    };
  }

  async patch(userId: string, id: string, req: PatchRunRequest): Promise<RunDetail> {
    const set: Partial<Pick<RunRow, 'name' | 'note' | 'effort'>> = {};
    if (req.name !== undefined) set.name = req.name;
    if (req.note !== undefined) set.note = req.note === null || req.note === '' ? null : req.note;
    if (req.effort !== undefined) set.effort = req.effort;
    const row = await this.repo.patch(userId, id, set);
    if (row === null) throw new AppError('NOT_FOUND', 'No such run.');
    return this.detail(row);
  }

  /**
   * Beta 4.2: the best three at each distance. Older runs are worked out
   * first, [EFFORTS_BATCH] at a time (`pending` says how many remain), and
   * the distance firsts are checked, so past runs count (owner).
   */
  async records(userId: string): Promise<RunningRecords> {
    for (const row of await this.efforts.stale(userId, EFFORTS_VERSION, EFFORTS_BATCH)) {
      await this.efforts.replace(row.id, userId, bestEfforts(decodeTrack(trackOf(row)!)), EFFORTS_VERSION);
    }
    await this.efforts.awardBadges(userId);
    const [top, pending, longestM, totalM] = await Promise.all([
      this.efforts.top3(userId),
      this.efforts.staleCount(userId, EFFORTS_VERSION),
      this.efforts.longest(userId),
      this.efforts.total(userId),
    ]);
    return {
      records: EFFORT_KEYS.map((key) => ({
        key,
        best: top
          .filter((r) => r.key === key)
          .map((r) => ({ runId: r.clientRunId, name: r.name, startedAt: r.startedAt.toISOString(), seconds: r.seconds })),
      })),
      pending,
      longestM,
      totalM,
    };
  }

  /** Deletes a run; the planned run it did, if any, is planned again. */
  async remove(userId: string, id: string): Promise<void> {
    const row = await this.repo.mine(userId, id);
    if (row === null) throw new AppError('NOT_FOUND', 'No such run.');
    await this.plans.unlink(row.id);
    if (!(await this.repo.remove(userId, id))) throw new AppError('NOT_FOUND', 'No such run.');
  }
}
