/**
 * Running (beta 4.0, ADR-038): a finished run comes in once, with the
 * phone's client id; the server works out every figure from the track with
 * packages/core and keeps the run. The phone's own figures were its live
 * view; what is kept and shown afterwards is this.
 */
import type { CreateRunRequest, PatchRunRequest, RunDetail, RunGoal, RunList, RunSummary } from '@fitos/contracts';
import { localDateOf, addDays } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';
import { summarizeTrack, summarizeTreadmill, type RunSummary as CoreSummary } from '@fitos/core/running/summary';
import { TrackError, decodeTrack, type EncodedTrack } from '@fitos/core/running/track';

import type { RunRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { RunningRepository } from './repository.js';

export const RUN_PAGE_SIZE = 20;

const num = (v: string | null): number | null => (v === null ? null : Number(v));

function trackOf(row: RunRow): EncodedTrack | null {
  if (row.trackPoints === null || row.trackBreaks === null || row.trackElevation === null) return null;
  return { v: 1, points: row.trackPoints, breaks: row.trackBreaks, elevation: row.trackElevation };
}

export function toSummary(row: RunRow): RunSummary {
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
  };
}

export function toDetail(row: RunRow): RunDetail {
  const track = trackOf(row);
  // Splits and the chart are computed on read, from the kept track.
  const computed = track === null ? null : summarizeTrack(decodeTrack(track), row.durationSeconds, null);
  const goal: RunGoal = row.goalKind === 'free' ? { kind: 'free', value: null } : { kind: row.goalKind, value: row.goalValue };
  return {
    ...toSummary(row),
    note: row.note,
    goal,
    track: track === null ? null : { ...track, breaks: [...track.breaks] },
    splitsKm: computed === null ? [] : [...computed.splitsKm],
    splitsMi: computed === null ? [] : [...computed.splitsMi],
    series: computed === null ? [] : [...computed.series],
  };
}

export class RunningService {
  constructor(
    private readonly repo: RunningRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** 201 with the run the first time; 200 with the same run on a replay. */
  async create(userId: string, req: CreateRunRequest): Promise<{ created: boolean; body: RunDetail }> {
    const existing = await this.repo.byClientId(req.clientRunId);
    if (existing !== null) return this.replay(userId, existing);

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
      trackPoints: req.track?.points ?? null,
      trackBreaks: req.track === undefined ? null : [...req.track.breaks],
      trackElevation: req.track?.elevation ?? null,
      distanceM: summary.distanceM.toFixed(1),
      avgPaceSecPerKm: summary.avgPaceSecPerKm === null ? null : summary.avgPaceSecPerKm.toFixed(1),
      elevationGainM: summary.elevationGainM === null ? null : summary.elevationGainM.toFixed(1),
      calories: summary.calories,
      outline: summary.outline.map(([lat, lon]) => [lat, lon] as [number, number]),
    });
    // Two uploads racing on one id: the loser reads the winner's row.
    if (row === null) return this.replay(userId, (await this.repo.byClientId(req.clientRunId))!);
    return { created: true, body: toDetail(row) };
  }

  private replay(userId: string, row: RunRow): { created: boolean; body: RunDetail } {
    if (row.userId !== userId) throw new AppError('CONFLICT', 'That run id is already taken.', [{ path: 'clientRunId', issue: 'taken' }]);
    return { created: false, body: toDetail(row) };
  }

  async get(userId: string, id: string): Promise<RunDetail> {
    const row = await this.repo.mine(userId, id);
    if (row === null) throw new AppError('NOT_FOUND', 'No such run.');
    return toDetail(row);
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
    return {
      runs: pageRows.map(toSummary),
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
    return toDetail(row);
  }

  async remove(userId: string, id: string): Promise<void> {
    if (!(await this.repo.remove(userId, id))) throw new AppError('NOT_FOUND', 'No such run.');
  }
}
