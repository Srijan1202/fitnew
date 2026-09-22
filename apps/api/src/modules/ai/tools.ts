/**
 * Phase 6.6 — the allowlisted tools (ADR-010). Every tool is a named,
 * Zod-validated call into an existing FITOS service with the authenticated
 * user's id closed over: the model never names a user, a table or a query.
 * Unknown tools and invalid arguments become a tool *result* the model can
 * read ("unknown tool" / "invalid arguments"), never an execution. Every
 * tool is read-only; nothing here writes.
 */
import { z } from 'zod';

import { exerciseListQuerySchema } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { ExerciseService } from '../exercise/service.js';
import type { TrainingService } from '../training/service.js';
import type { UserService } from '../user/service.js';
import type { WorkoutService } from '../workout/service.js';
import { UserContextAssembler } from './context-assembler.js';
import type { AiToolDeclaration } from './provider.js';

export interface ToolServices {
  readonly user: UserService;
  readonly training: TrainingService;
  readonly workout: WorkoutService;
  readonly exercise: ExerciseService;
}

export interface ToolDefinition<A extends z.ZodTypeAny = z.ZodTypeAny> {
  readonly name: string;
  readonly description: string;
  readonly args: A;
  /** JSON schema for the model; kept by hand so it never leaks Zod internals. */
  readonly parameters: Record<string, unknown>;
  readonly execute: (userId: string, args: z.infer<A>, s: ToolServices) => Promise<Record<string, unknown>>;
}

const noArgs = z.object({}).strict();
const noParams = { type: 'object', properties: {} };
const uuid = z.string().uuid();

export const TOOLS: readonly ToolDefinition[] = [
  {
    name: 'get_user_profile',
    description: "The user's profile: name, sex, age, height, latest weight, experience, activity level, training days, session length, location, equipment, timezone.",
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => ({ profile: UserContextAssembler.profileOf(await s.user.getProfile(userId), new Date()) }),
  },
  {
    name: 'get_active_goal',
    description: "The user's active goal and the nutrition targets FITOS computed for it (kcal, protein, carbs, fat, fibre) with the reason.",
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => {
      const g = await s.user.getGoal(userId);
      return { goal: g.goal, targets: g.targets };
    },
  },
  {
    name: 'get_nutrition_targets',
    description: "The user's nutrition targets. Food intake is NOT logged in this version: the tool says so.",
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => {
      const g = await s.user.getGoal(userId);
      return { targets: g.targets, loggingAvailable: false, intakeToday: 'unknown — food logging is not available in this version' };
    },
  },
  {
    name: 'get_today',
    description: "Today's day on the programme: session name, whether it is rest / ready / in progress / completed, every planned exercise with sets, reps, RIR, the progression recommendation with its reason, last time's sets, any substitution; plus mesocycle week, deload state and neglected muscles.",
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => ({ today: UserContextAssembler.todayOf(await s.workout.today(userId)) }),
  },
  {
    name: 'get_current_workout',
    description: 'The session in progress right now, with the sets logged so far. Empty when none is in progress.',
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => {
      const t = await s.workout.today(userId);
      if (t.activeSession === null) return { inProgress: false };
      return { inProgress: true, session: UserContextAssembler.sessionOf(t.activeSession) };
    },
  },
  {
    name: 'get_recent_workouts',
    description: 'The most recent completed sessions (newest first) with every working set, tonnage and records. limit 1–10.',
    args: z.object({ limit: z.number().int().min(1).max(10).default(3) }).strict(),
    parameters: { type: 'object', properties: { limit: { type: 'integer', minimum: 1, maximum: 10, description: 'How many sessions, newest first (default 3).' } } },
    execute: async (userId, args, s) => {
      const list = await s.workout.list(userId, { limit: args.limit, status: 'completed' });
      const sessions = [];
      for (const item of list.items.slice(0, args.limit)) {
        const full = await s.workout.get(userId, item.id);
        sessions.push(UserContextAssembler.sessionOf(full));
      }
      return { sessions };
    },
  },
  {
    name: 'get_workout',
    description: 'One completed session by its id (from get_recent_workouts), in full.',
    args: z.object({ sessionId: uuid }).strict(),
    parameters: { type: 'object', properties: { sessionId: { type: 'string', description: 'The session id.' } }, required: ['sessionId'] },
    execute: async (userId, args, s) => ({ session: UserContextAssembler.sessionOf(await s.workout.get(userId, args.sessionId)) }),
  },
  {
    name: 'get_exercise',
    description: 'One exercise from the library by id: pattern, equipment, muscles, difficulty, instructions and its alternatives.',
    args: z.object({ exerciseId: uuid }).strict(),
    parameters: { type: 'object', properties: { exerciseId: { type: 'string', description: 'The exercise id.' } }, required: ['exerciseId'] },
    execute: async (_userId, args, s) => ({ exercise: await s.exercise.detail(args.exerciseId) }),
  },
  {
    name: 'search_exercises',
    description: 'Search the exercise library by name, equipment (comma-separated: barbell, dumbbell, machine, cable, kettlebell, resistance-band, pull-up-bar, bodyweight), muscle group or movement pattern. Returns up to `limit` matches.',
    args: z
      .object({
        q: z.string().trim().min(1).max(64).optional(),
        equipment: z.string().max(120).optional(),
        muscle: z.string().max(20).optional(),
        pattern: z.string().max(30).optional(),
        limit: z.number().int().min(1).max(20).default(8),
      })
      .strict(),
    parameters: {
      type: 'object',
      properties: {
        q: { type: 'string', description: 'Name search.' },
        equipment: { type: 'string', description: 'Comma-separated equipment the user has.' },
        muscle: { type: 'string', description: 'chest, back, quads, hamstrings, glutes, shoulders, biceps, triceps, calves or abs.' },
        pattern: { type: 'string', description: 'Movement pattern, e.g. horizontal-push, vertical-pull, squat, hinge.' },
        limit: { type: 'integer', minimum: 1, maximum: 20 },
      },
    },
    execute: async (_userId, args, s) => {
      // The library's own query schema decides what is valid; a bad enum
      // becomes an "invalid arguments" result, not a 422 to the user.
      const parsed = exerciseListQuerySchema.safeParse({ ...args, limit: args.limit, offset: 0 });
      if (!parsed.success) {
        return { error: 'invalid arguments', issues: parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`) };
      }
      const r = await s.exercise.list(parsed.data);
      return {
        total: r.total,
        items: r.items.map((x) => ({ exerciseId: x.id, name: x.name, pattern: x.movementPattern, equipment: x.equipment, primaryMuscles: x.primaryMuscles, difficulty: x.difficulty })),
      };
    },
  },
  {
    name: 'get_training_volume',
    description: "This week's hard sets per muscle against the landmarks (MEV / MAV / MRV) with a status each, plus the three previous weeks, neglected muscles and the deload state.",
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => {
      const v = await s.workout.volume(userId);
      return {
        current: UserContextAssembler.volumeOf(v),
        previousWeeks: v.weeks.slice(0, -1).map((w) => ({ isoWeek: w.isoWeek, muscles: w.muscles.filter((m) => m.hardSets > 0).map((m) => ({ muscle: m.muscle, hardSets: m.hardSets })) })),
        neglected: v.neglected,
        mesocycleWeek: v.mesocycleWeek,
        deload: v.deload,
      };
    },
  },
  {
    name: 'get_progression',
    description: "One lift's progression: the target rep range, the recommendation with its reason, and the last three sessions of that lift. Needs the exerciseId (from get_today or search_exercises).",
    args: z.object({ exerciseId: uuid }).strict(),
    parameters: { type: 'object', properties: { exerciseId: { type: 'string', description: 'The exercise id.' } }, required: ['exerciseId'] },
    execute: async (userId, args, s) => ({ progression: await s.workout.progressionDetail(userId, args.exerciseId) }),
  },
  {
    name: 'get_active_program',
    description: "The user's active programme: name, split, days per week, mesocycle week, and each day's session with its exercises, sets, reps and RIR.",
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => {
      const p = await s.training.getProgram(userId);
      return {
        programme: {
          ...UserContextAssembler.programmeOf(p),
          days: p.days.map((d) => ({
            dayOfWeek: d.dayOfWeek,
            sessionName: d.sessionName,
            isRest: d.isRest,
            exercises: d.exercises.map((x) => ({ exerciseId: x.exerciseId, name: x.name, sets: x.setCount, reps: `${x.repMin}–${x.repMax}`, rir: x.targetRir, reason: x.reason })),
          })),
        },
      };
    },
  },
  {
    name: 'get_deload_state',
    description: 'Whether a deload is offered or active on the programme, its trigger and reason, and when it ends.',
    args: noArgs,
    parameters: noParams,
    execute: async (userId, _a, s) => {
      const t = await s.workout.today(userId);
      return { deload: t.deload, mesocycleWeek: t.mesocycleWeek };
    },
  },
];

export const TOOL_NAMES: readonly string[] = TOOLS.map((t) => t.name);

/** Hard cap on model → tool → model rounds per chat request. */
export const MAX_TOOL_ROUNDS = 4;

export class ToolRegistry {
  private readonly byName = new Map<string, ToolDefinition>(TOOLS.map((t) => [t.name, t]));

  constructor(private readonly services: ToolServices) {}

  declarations(): AiToolDeclaration[] {
    return TOOLS.map((t) => ({ name: t.name, description: t.description, parameters: t.parameters }));
  }

  has(name: string): boolean {
    return this.byName.has(name);
  }

  /**
   * Validate and run one call for the given user. Never throws for a bad
   * name or bad arguments — the model gets a result it can read. Service
   * errors (404 "no programme") become results too; anything else is a
   * bug and propagates.
   */
  async execute(userId: string, name: string, rawArgs: unknown): Promise<Record<string, unknown>> {
    const tool = this.byName.get(name);
    if (tool === undefined) return { error: `unknown tool: ${name}` };
    const parsed = tool.args.safeParse(rawArgs ?? {});
    if (!parsed.success) {
      return { error: 'invalid arguments', issues: parsed.error.issues.map((i) => `${i.path.join('.') || '(root)'}: ${i.message}`) };
    }
    try {
      return await tool.execute(userId, parsed.data, this.services);
    } catch (e) {
      if (e instanceof AppError && (e.code === 'NOT_FOUND' || e.code === 'VALIDATION_FAILED' || e.code === 'CONFLICT')) {
        return { error: e.message };
      }
      throw e;
    }
  }
}
