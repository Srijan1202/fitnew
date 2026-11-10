/**
 * Beta 3.3 (ADR-034): share your programme as a code, and use someone
 * else's. A share is a SNAPSHOT of the structure when it was made — days,
 * rest days, session names, exercises in order, sets, rep ranges and target
 * RIR — never weights, logs, notes or who shared it. Using a code makes a
 * copy that becomes the user's own active programme (source `custom`); their
 * history, records and last weights stay theirs.
 */
import { randomInt } from 'node:crypto';

import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { and, desc, eq, isNull } from 'drizzle-orm';
import { z } from 'zod';
import {
  SHARE_CODE_ALPHABET,
  SHARE_PAGE_URL,
  SHARED_LOOKUPS_PER_HOUR,
  SHARES_PER_DAY,
  errorEnvelopeSchema,
  myShareListSchema,
  myShareSchema,
  programSchema,
  putProgramRequestSchema,
  shareCodeParamsSchema,
  sharedProgrammeSchema,
  type Equipment,
  type MuscleGroup,
  type MyShare,
  type Program,
  type SharedProgramme,
} from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import { sharedProgrammes, userProfiles, users } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import { TrainingRepository, type ProgramBundle } from './repository.js';
import { TrainingService, programFrom } from './service.js';
import { trainingDays } from '@fitos/core/training/generator';
import { cycleLayout } from '@fitos/core/training/schedule';
import { localDateOf } from '@fitos/core/nutrition/log';

type Db = DatabaseHandle['db'];

/** What is stored: the structure only. */
interface Snapshot {
  /** Beta 6.1 (F2): a cycle's pattern; absent on codes from before and on weekday programmes. */
  readonly cycle?: { readonly on: number; readonly off: number } | null;
  readonly days: readonly {
    readonly dayOfWeek: number;
    readonly sessionName: string;
    readonly focus: MuscleGroup[];
    readonly isRest: boolean;
    readonly exercises: readonly {
      readonly exerciseId: string;
      readonly setCount: number;
      readonly repMin: number;
      readonly repMax: number;
      readonly targetRir: number;
      readonly sets: readonly { readonly repsMin: number; readonly repsMax: number; readonly rir: number }[];
    }[];
  }[];
}

export function newShareCode(pick: (n: number) => number = randomInt): string {
  return Array.from({ length: 6 }, () => SHARE_CODE_ALPHABET[pick(SHARE_CODE_ALPHABET.length)]).join('');
}

/** The structure of a programme, without a single weight. */
export function snapshotOf(bundle: ProgramBundle): Snapshot {
  return {
    cycle: bundle.program.schedule === 'cycle' ? cyclePattern(bundle.days) : null,
    days: bundle.days.map((d) => ({
      dayOfWeek: d.dayOfWeek,
      sessionName: d.sessionName,
      focus: [...d.focus],
      isRest: d.isRest,
      exercises: bundle.exercises
        .filter((x) => x.programDayId === d.id)
        .sort((a, b) => a.orderIndex - b.orderIndex)
        .map((x) => ({
          exerciseId: x.exerciseId,
          setCount: x.setCount,
          repMin: x.repMin,
          repMax: x.repMax,
          targetRir: x.targetRir,
          sets: bundle.sets
            .filter((s) => s.plannedExerciseId === x.id)
            .sort((a, b) => a.setIndex - b.setIndex)
            .map((s) => ({ repsMin: s.repsMin, repsMax: s.repsMax, rir: s.rir })),
        })),
    })),
  };
}

/**
 * Beta 6.1 (F2): a cycle's on/off from its days (it was made by core
 * `cycleLayout`): the training days before the first rest day, then the rest
 * days after them.
 */
export function cyclePattern(days: readonly { dayOfWeek: number; isRest: boolean }[]): { on: number; off: number } {
  const order = [...days].sort((a, b) => a.dayOfWeek - b.dayOfWeek);
  const on = order.findIndex((d) => d.isRest);
  if (on < 0) return { on: order.length, off: 0 };
  let off = 0;
  while (order[on + off]?.isRest === true) off += 1;
  return { on, off };
}

export class ShareService {
  constructor(
    private readonly db: Db,
    private readonly training: TrainingRepository,
    private readonly programs: TrainingService,
    private readonly code: () => string = () => newShareCode(),
  ) {}

  private myShare(r: { code: string; name: string; createdAt: Date }): MyShare {
    return { code: r.code, name: r.name, url: `${SHARE_PAGE_URL}${r.code}`, createdAt: r.createdAt.toISOString() };
  }

  /** Share the active programme as a new code. */
  async share(userId: string): Promise<MyShare> {
    const bundle = await this.training.activeProgram(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'Build a programme before sharing it.', [{ path: 'program', issue: 'none' }]);
    const snapshot = snapshotOf(bundle);
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const [row] = await this.db
        .insert(sharedProgrammes)
        .values({ code: this.code(), userId, name: bundle.program.name, snapshot })
        .onConflictDoNothing()
        .returning();
      if (row !== undefined) return this.myShare(row);
    }
    // Five collisions in a row among ~900 million codes: not in practice.
    throw new AppError('INTERNAL', 'Could not make a share code. Try again.');
  }

  async mine(userId: string): Promise<MyShare[]> {
    const rows = await this.db
      .select()
      .from(sharedProgrammes)
      .where(and(eq(sharedProgrammes.userId, userId), isNull(sharedProgrammes.stoppedAt)))
      .orderBy(desc(sharedProgrammes.createdAt));
    return rows.map((r) => this.myShare(r));
  }

  /** Stop sharing a code: it answers 404 from now on. */
  async stop(userId: string, code: string): Promise<void> {
    const stopped = await this.db
      .update(sharedProgrammes)
      .set({ stoppedAt: new Date() })
      .where(and(eq(sharedProgrammes.code, code), eq(sharedProgrammes.userId, userId), isNull(sharedProgrammes.stoppedAt)))
      .returning({ code: sharedProgrammes.code });
    if (stopped.length === 0) throw new AppError('NOT_FOUND', 'You are not sharing that code.');
  }

  private async live(code: string): Promise<{ name: string; snapshot: Snapshot }> {
    const [row] = await this.db
      .select({ name: sharedProgrammes.name, snapshot: sharedProgrammes.snapshot })
      .from(sharedProgrammes)
      .where(and(eq(sharedProgrammes.code, code), isNull(sharedProgrammes.stoppedAt)))
      .limit(1);
    if (row === undefined) throw new AppError('NOT_FOUND', 'No programme is shared with that code.', [{ path: 'code', issue: 'unknown' }]);
    return { name: row.name, snapshot: row.snapshot as Snapshot };
  }

  /** The preview; with `userId`, each exercise says what equipment that person lacks. */
  async preview(code: string, userId: string | null): Promise<SharedProgramme> {
    const { name, snapshot } = await this.live(code);
    const ids = [...new Set(snapshot.days.flatMap((d) => d.exercises.map((x) => x.exerciseId)))];
    const exercises = await this.training.exercisesById(ids);
    let have: ReadonlySet<Equipment> | null = null;
    if (userId !== null) {
      const [p] = await this.db.select({ equipment: userProfiles.equipment }).from(userProfiles).where(eq(userProfiles.userId, userId)).limit(1);
      have = new Set(p?.equipment ?? []);
    }
    const days = [...snapshot.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).map((d) => ({
      dayOfWeek: d.dayOfWeek,
      sessionName: d.sessionName,
      isRest: d.isRest,
      exercises: d.exercises.flatMap((x) => {
        const ex = exercises.get(x.exerciseId);
        // Exercises are never deleted (planned rows restrict it); skip rather than fail.
        if (ex === undefined) return [];
        const equipment = [...ex.equipment];
        return [{
          exerciseId: x.exerciseId,
          name: ex.name,
          equipment,
          setCount: x.setCount,
          repMin: x.repMin,
          repMax: x.repMax,
          targetRir: x.targetRir,
          missingEquipment: have === null ? [] : equipment.filter((q) => q !== 'bodyweight' && !have.has(q)),
        }];
      }),
    }));
    const cycle = snapshot.cycle ?? null;
    return {
      code,
      name,
      daysPerWeek: days.filter((d) => !d.isRest).length,
      schedule: cycle === null ? ('week' as const) : ('cycle' as const),
      cycleLength: cycle === null ? null : days.length,
      days,
    };
  }

  /** Use a code: a copy becomes this person's active programme (the old one is kept, inactive). */
  async use(userId: string, code: string): Promise<Program> {
    const { name, snapshot } = await this.live(code);
    const cycle = snapshot.cycle ?? null;
    const sessions = [...snapshot.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).filter((d) => !d.isRest && d.exercises.length > 0);
    // Beta 6.1 (F2): a cycle's sessions go on the usual weekdays first, then become the same cycle from today.
    const weekdays = cycle === null ? null : trainingDays(sessions.length);
    const body = putProgramRequestSchema.parse({
      name,
      days: sessions
        .map((d, i) => ({
          dayOfWeek: weekdays === null ? d.dayOfWeek : weekdays[i]!,
          sessionName: d.sessionName,
          focus: d.focus,
          exercises: d.exercises.map((x) => ({
            exerciseId: x.exerciseId,
            setCount: x.setCount,
            repMin: x.repMin,
            repMax: x.repMax,
            targetRir: x.targetRir,
            ...(x.sets.length === x.setCount ? { sets: x.sets.map((s) => ({ ...s, weightKg: null })) } : {}),
          })),
        })),
    });
    const program = await this.programs.putCustom(userId, body);
    if (cycle === null) return program;
    const layout = cycleLayout(sessions.length, cycle.on, cycle.off);
    // A stored pattern always fits: it was read off a cycle that cycleLayout made.
    if (layout === null) return program;
    const ordered = [...program.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek);
    const training = ordered.filter((d) => !d.isRest);
    const [u] = await this.db.select({ tz: users.timezone }).from(users).where(eq(users.id, userId)).limit(1);
    const today = localDateOf(new Date(), u?.tz ?? 'Asia/Kolkata');
    const bundle = await this.training.applySchedule(
      program.id,
      layout.map((i) => (i === null ? null : training[i]!.id)),
      ordered.filter((d) => d.isRest).map((d) => d.id),
      { schedule: 'cycle', cycleStart: today, cycleLength: layout.length },
    );
    return programFrom(bundle);
  }
}

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

const perAddress = {
  max: SHARED_LOOKUPS_PER_HOUR,
  timeWindow: '1 hour',
  hook: 'preHandler' as const,
  keyGenerator: (request: FastifyRequest): string => `shared-lookup:${request.ip}`,
};

export async function shareRoutes(app: FastifyInstance): Promise<void> {
  const training = new TrainingRepository(app.database.db);
  const service = new ShareService(app.database.db, training, new TrainingService(training));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };
  const feature = (request: FastifyRequest) => app.features.require('share-programme', request);

  typed.post('/training/program/share', {
    config: {
      rateLimit: {
        max: SHARES_PER_DAY,
        timeWindow: '1 day',
        hook: 'preHandler',
        keyGenerator: (request: FastifyRequest): string => (request.userId !== null ? `share:${request.userId}` : `share-ip:${request.ip}`),
      },
    },
    schema: {
      summary: 'Share your active programme as a code: a snapshot of its structure, never weights or who you are (beta 3.3)',
      tags: ['training'],
      security,
      response: { 201: myShareSchema, ...errors },
    },
  }, async (request, reply) => {
    const userId = requireUserId(request.userId);
    await feature(request);
    return reply.code(201).send(await service.share(userId));
  });

  typed.get('/training/program/shares', {
    schema: { summary: 'The codes you are sharing', tags: ['training'], security, response: { 200: myShareListSchema, ...errors } },
  }, async (request) => ({ items: await service.mine(requireUserId(request.userId)) }));

  typed.delete('/training/program/shares/:code', {
    schema: { summary: 'Stop sharing a code', tags: ['training'], security, params: shareCodeParamsSchema, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.stop(requireUserId(request.userId), request.params.code);
    return reply.code(204).send(null);
  });

  typed.get('/training/shared/:code', {
    config: { rateLimit: perAddress },
    schema: {
      summary: "Preview a shared programme, with the equipment YOUR setting lacks per exercise",
      tags: ['training'],
      security,
      params: shareCodeParamsSchema,
      response: { 200: sharedProgrammeSchema, ...errors },
    },
  }, async (request) => {
    const userId = requireUserId(request.userId);
    await feature(request);
    return service.preview(request.params.code, userId);
  });

  typed.post('/training/shared/:code/use', {
    schema: {
      summary: 'Use a shared programme: a copy replaces your active programme (kept, inactive); your history stays',
      tags: ['training'],
      security,
      params: shareCodeParamsSchema,
      response: { 200: programSchema, ...errors },
    },
  }, async (request) => {
    const userId = requireUserId(request.userId);
    await feature(request);
    return service.use(userId, request.params.code);
  });

  // The website's /p/<code> page reads this without signing in. A plain GET
  // with no custom headers needs no preflight; only tryfitos.me may read it.
  typed.get('/shared-programmes/:code', {
    config: { public: true, rateLimit: perAddress },
    schema: {
      summary: 'A shared programme, publicly, for the website preview: structure only (beta 3.3)',
      tags: ['training'],
      params: shareCodeParamsSchema,
      response: { 200: sharedProgrammeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema },
    },
  }, async (request, reply) => {
    void reply.header('Access-Control-Allow-Origin', 'https://tryfitos.me').header('Vary', 'Origin');
    await feature(request);
    return service.preview(request.params.code, null);
  });
}
