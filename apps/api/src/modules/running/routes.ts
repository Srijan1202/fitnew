/**
 * /v1/running/runs — runs (beta 4.0, ADR-038). HTTP and Zod only (§8.3).
 * Default-deny like every /v1 route. A run is addressed by the phone's
 * client id. The admin's `running` switch stops new runs and edits; the
 * history, a run and deleting one always work (the runner's own data).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  createPlanRequestSchema,
  createRunRequestSchema,
  currentPlanSchema,
  errorEnvelopeSchema,
  patchPlannedRunRequestSchema,
  plannedRunParamsSchema,
  plannedRunSchema,
  runningPlanSchema,
  workoutPresetsSchema,
  patchRunRequestSchema,
  runDetailSchema,
  runListQuerySchema,
  runListSchema,
  runParamsSchema,
  runningRecordsSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { ProgressRepository } from '../progress/repository.js';
import { EffortsRepository } from './efforts-repository.js';
import { PlanRepository } from './plan-repository.js';
import { PlanService } from './plan-service.js';
import { RunningRepository } from './repository.js';
import { RunningService } from './service.js';

/** A marathon at one fix a second is about 200 KB encoded; this leaves room for 14 hours. */
export const RUN_BODY_LIMIT = 2 * 1024 * 1024;

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function runningRoutes(app: FastifyInstance): Promise<void> {
  const runsRepo = new RunningRepository(app.database.db);
  const plansRepo = new PlanRepository(app.database.db);
  const service = new RunningService(runsRepo, plansRepo, new EffortsRepository(app.database.db));
  const progress = new ProgressRepository(app.database.db);
  const plans = new PlanService(plansRepo, runsRepo, (userId) => progress.plannedDays(userId));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const tags = ['running'];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 409: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.post(
    '/running/runs',
    {
      bodyLimit: RUN_BODY_LIMIT,
      schema: {
        summary: 'Save a finished run (idempotent on clientRunId)',
        description:
          '201 the first time, 200 with the same run when the phone sends it again. Every figure is computed here from ' +
          'the track (packages/core); the phone keeps only its timer (durationSeconds). A track that does not decode is 422.',
        tags,
        security,
        body: createRunRequestSchema,
        response: { 200: runDetailSchema, 201: runDetailSchema, ...errors },
      },
    },
    async (request, reply) => {
      await app.features.require('running');
      const { created, body } = await service.create(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(body);
    },
  );

  typed.get(
    '/running/records',
    {
      schema: {
        summary: 'Your best efforts: the best three at each distance (beta 4.2)',
        description:
          'The fastest stretch of 400 m, 1 km, 1 mile, 5 km, 10 km, half and marathon inside any outdoor run, on moving time ' +
          '(packages/core running/efforts). Older runs are worked out a batch a request; `pending` says how many remain. ' +
          'Also records the distance firsts your runs reached (in GET /user/rewards).',
        tags,
        security,
        response: { 200: runningRecordsSchema, ...errors },
      },
    },
    async (request) => service.records(requireUserId(request.userId)),
  );

  typed.get(
    '/running/runs',
    {
      schema: {
        summary: 'Your runs, newest first, with this week and this month',
        tags,
        security,
        querystring: runListQuerySchema,
        response: { 200: runListSchema, ...errors },
      },
    },
    async (request) => service.list(requireUserId(request.userId), request.query.before, request.query.limit),
  );

  typed.get(
    '/running/runs/:id',
    {
      schema: { summary: 'One run: the track, splits and the chart', tags, security, params: runParamsSchema, response: { 200: runDetailSchema, ...errors } },
    },
    async (request) => service.get(requireUserId(request.userId), request.params.id),
  );

  typed.patch(
    '/running/runs/:id',
    {
      schema: {
        summary: "Change a run's name, note or effort",
        tags,
        security,
        params: runParamsSchema,
        body: patchRunRequestSchema,
        response: { 200: runDetailSchema, ...errors },
      },
    },
    async (request) => {
      await app.features.require('running');
      return service.patch(requireUserId(request.userId), request.params.id, request.body);
    },
  );

  typed.delete(
    '/running/runs/:id',
    {
      schema: { summary: 'Delete a run, track and all', tags, security, params: runParamsSchema, response: { 204: z.null(), ...errors } },
    },
    async (request, reply) => {
      await service.remove(requireUserId(request.userId), request.params.id);
      return reply.code(204).send(null);
    },
  );

  /* ---------------------------------------------- beta 4.1: plans -- */

  typed.get(
    '/running/plans/current',
    { schema: { summary: 'The active running plan, with every planned run (null without one)', tags, security, response: { 200: currentPlanSchema, ...errors } } },
    async (request) => ({ plan: await plans.current(requireUserId(request.userId)) }),
  );

  typed.post(
    '/running/plans',
    {
      schema: {
        summary: 'Make a running plan (5K, 10K, half, marathon); the active one stops',
        description:
          'Built by packages/core from the goal, the level, a recent race (or a goal time) and the running days. Paces are ' +
          "Daniels' VDOT zones; a beginner 5K is run/walk with no paces. 422 for a plan that cannot be made.",
        tags,
        security,
        body: createPlanRequestSchema,
        response: { 201: runningPlanSchema, ...errors },
      },
    },
    async (request, reply) => {
      await app.features.require('running');
      return reply.code(201).send(await plans.create(requireUserId(request.userId), request.body));
    },
  );

  typed.delete(
    '/running/plans/current',
    { schema: { summary: 'Stop the active plan; its runs still to come go', tags, security, response: { 204: z.null(), ...errors } } },
    async (request, reply) => {
      await plans.stop(requireUserId(request.userId));
      return reply.code(204).send(null);
    },
  );

  typed.patch(
    '/running/planned/:id',
    {
      schema: {
        summary: 'Skip, un-skip, or move a planned run within its week',
        tags,
        security,
        params: plannedRunParamsSchema,
        body: patchPlannedRunRequestSchema,
        response: { 200: plannedRunSchema, ...errors },
      },
    },
    async (request) => {
      await app.features.require('running');
      return plans.patch(requireUserId(request.userId), request.params.id, request.body);
    },
  );

  typed.get(
    '/running/workouts',
    { schema: { summary: "FITOS's ready-made sessions, paced from the plan's zones when there is one", tags, security, response: { 200: workoutPresetsSchema, ...errors } } },
    async (request) => plans.presets(requireUserId(request.userId)),
  );
}
