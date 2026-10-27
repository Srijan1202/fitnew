/**
 * Running plans (beta 4.1, ADR-039): made by packages/core from what the
 * runner chose, kept as dated runs, shown back with today's zones. A run on
 * the plan's day does that day's run (the running service links it).
 */
import type { CreatePlanRequest, PatchPlannedRunRequest, PlannedRun, RunningPlan, WorkoutPresets, WorkoutStep } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';
import { PlanError, generatePlan, type PlanGoal } from '@fitos/core/running/plan';
import { RACE_DISTANCES_M, vdotForGoal, vdotFromRace, zones } from '@fitos/core/running/vdot';
import { presets } from '@fitos/core/running/workout';

import type { PlannedRunRow, RunningPlanRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import type { PlanRepository } from './plan-repository.js';
import type { RunningRepository } from './repository.js';

export function toPlannedRun(row: PlannedRunRow): PlannedRun {
  return {
    id: row.id,
    date: row.date,
    week: row.week,
    kind: row.kind,
    title: row.title,
    distanceM: row.distanceM === null ? null : Number(row.distanceM),
    seconds: row.seconds,
    pace: row.paceFast === null || row.paceSlow === null ? null : { fast: row.paceFast, slow: row.paceSlow },
    steps: row.steps as WorkoutStep[] | null,
    note: row.note,
    status: row.status,
    runId: row.runId,
    movedFrom: row.movedFrom,
  };
}

export class PlanService {
  constructor(
    private readonly plans: PlanRepository,
    private readonly runs: RunningRepository,
    /** The gym programme's training weekdays (null without one). */
    private readonly gymDays: (userId: string) => Promise<number[] | null>,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private async today(userId: string): Promise<string> {
    return localDateOf(this.now(), await this.runs.timezoneOf(userId));
  }

  private async toPlan(userId: string, row: RunningPlanRow): Promise<RunningPlan> {
    const [planned, gym] = await Promise.all([this.plans.runsOf(row.id), this.gymDays(userId)]);
    const gymSet = new Set(gym ?? []);
    return {
      id: row.id,
      goal: row.goal,
      level: row.level,
      status: row.status,
      daysPerWeek: row.daysPerWeek,
      weekdays: row.weekdays,
      longRunWeekday: row.longRunWeekday,
      startDate: row.startDate,
      weeks: row.weeks,
      zones: row.vdot === null ? null : zones(Number(row.vdot)),
      predictedSeconds: row.predictedSeconds,
      gymOverlap: row.weekdays.filter((d) => gymSet.has(d)),
      runs: planned.map(toPlannedRun),
    };
  }

  async current(userId: string): Promise<RunningPlan | null> {
    const row = await this.plans.active(userId);
    return row === null ? null : this.toPlan(userId, row);
  }

  /** Makes a plan; the active one, if any, is stopped and its future runs go. */
  async create(userId: string, req: CreatePlanRequest): Promise<RunningPlan> {
    const today = await this.today(userId);
    const startDate = req.startDate ?? today;
    if (startDate < today) {
      throw new AppError('VALIDATION_FAILED', 'A plan starts today or later.', [{ path: 'startDate', issue: 'in the past' }]);
    }
    const vdot =
      req.level === 'beginner'
        ? null
        : req.race !== null
          ? vdotFromRace(RACE_DISTANCES_M[req.race.distance], req.race.seconds)
          : vdotForGoal(RACE_DISTANCES_M[req.goal as PlanGoal], req.goalSeconds!);
    let plan;
    try {
      plan = generatePlan({
        goal: req.goal,
        level: req.level,
        vdot,
        daysPerWeek: req.daysPerWeek,
        weekdays: req.weekdays,
        longRunWeekday: req.longRunWeekday,
        startDate,
      });
    } catch (e) {
      if (e instanceof PlanError) throw new AppError('VALIDATION_FAILED', e.message, [{ path: '', issue: e.message }]);
      throw e;
    }
    const row = await this.plans.replace(
      userId,
      today,
      {
        userId,
        goal: req.goal,
        level: req.level,
        vdot: vdot === null ? null : vdot.toFixed(1),
        daysPerWeek: req.daysPerWeek,
        weekdays: [...req.weekdays].sort((a, b) => a - b),
        longRunWeekday: req.longRunWeekday,
        startDate,
        weeks: plan.weeks,
        predictedSeconds: plan.predictedSeconds,
      },
      plan.runs.map((r) => ({
        date: r.date,
        week: r.week,
        kind: r.kind,
        title: r.title,
        distanceM: r.distanceM === null ? null : r.distanceM.toFixed(1),
        seconds: r.seconds,
        paceFast: r.pace?.fast ?? null,
        paceSlow: r.pace?.slow ?? null,
        steps: r.steps === null ? null : [...r.steps],
        note: r.note,
      })),
    );
    return this.toPlan(userId, row);
  }

  async stop(userId: string): Promise<void> {
    if (!(await this.plans.stop(userId, await this.today(userId)))) throw new AppError('NOT_FOUND', 'No running plan to stop.');
  }

  /**
   * Skip, un-skip, or move a planned run to another day of its own week
   * (Monday to Sunday). A done run cannot be skipped or moved.
   */
  async patch(userId: string, id: string, req: PatchPlannedRunRequest): Promise<PlannedRun> {
    const row = await this.plans.mine(userId, id);
    if (row === null) throw new AppError('NOT_FOUND', 'No such planned run.');
    if (row.status === 'done') throw new AppError('CONFLICT', 'That run is done already.', [{ path: 'status', issue: 'done' }]);
    switch (req.action) {
      case 'skip':
        return toPlannedRun(await this.plans.update(id, { status: 'skipped' }));
      case 'unskip':
        return toPlannedRun(await this.plans.update(id, { status: 'planned' }));
      case 'move': {
        const date = req.date!;
        const monday = addDays(row.date, 1 - isoWeekday(row.date));
        if (date < monday || date > addDays(monday, 6)) {
          throw new AppError('VALIDATION_FAILED', 'A run moves within its own week.', [{ path: 'date', issue: 'another week' }]);
        }
        if (date < (await this.today(userId))) {
          throw new AppError('VALIDATION_FAILED', 'A run cannot move into the past.', [{ path: 'date', issue: 'in the past' }]);
        }
        return toPlannedRun(await this.plans.update(id, { date, movedFrom: row.movedFrom ?? row.date, status: 'planned' }));
      }
    }
  }

  /** The ready-made sessions, paced from the active plan's zones when there is one. */
  async presets(userId: string): Promise<WorkoutPresets> {
    const row = await this.plans.active(userId);
    const z = row === null || row.vdot === null ? null : zones(Number(row.vdot));
    return { zones: z, presets: presets(z).map((p) => ({ id: p.id, name: p.name, about: p.about, steps: [...p.steps] })) };
  }
}
