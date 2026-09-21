/**
 * /v1/training/sessions* and /v1/training/today — HTTP and Zod only (§8.3).
 * All protected by default-deny. Idempotent where §10.1 says so: a replayed
 * start or set batch answers 200 with the same rows.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  addSessionExerciseRequestSchema,
  completeSessionRequestSchema,
  errorEnvelopeSchema,
  logSetsRequestSchema,
  patchSessionExerciseRequestSchema,
  patchSetRequestSchema,
  sessionExerciseParamsSchema,
  sessionListQuerySchema,
  sessionListResponseSchema,
  sessionParamsSchema,
  sessionSetParamsSchema,
  startSessionRequestSchema,
  todayQuerySchema,
  todayResponseSchema,
  workoutSessionSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { TrainingRepository } from '../training/repository.js';
import { WorkoutRepository } from './repository.js';
import { WorkoutService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function workoutRoutes(app: FastifyInstance): Promise<void> {
  const service = new WorkoutService(new WorkoutRepository(app.database.db), new TrainingRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = {
    401: errorEnvelopeSchema,
    404: errorEnvelopeSchema,
    409: errorEnvelopeSchema,
    422: errorEnvelopeSchema,
  };
  const tags = ['workout'];
  const security = [{ bearerAuth: [] }];

  typed.get(
    '/training/today',
    {
      schema: {
        summary: "Today's day (or rest) with per-set targets and last performance, plus any active session",
        tags,
        security,
        querystring: todayQuerySchema,
        response: { 200: todayResponseSchema, ...errors },
      },
    },
    async (request) => service.today(requireUserId(request.userId), request.query.dayOfWeek),
  );

  typed.post(
    '/training/sessions',
    {
      schema: {
        summary: 'Start a session (idempotent on clientSessionId); 409 if another is active',
        tags,
        security,
        body: startSessionRequestSchema,
        response: { 200: workoutSessionSchema, 201: workoutSessionSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { session, created } = await service.start(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(session);
    },
  );

  typed.get(
    '/training/sessions',
    {
      schema: {
        summary: 'History, newest first, cursor-paginated',
        tags,
        security,
        querystring: sessionListQuerySchema,
        response: { 200: sessionListResponseSchema, ...errors },
      },
    },
    async (request) => service.list(requireUserId(request.userId), request.query),
  );

  typed.get(
    '/training/sessions/:id',
    {
      schema: {
        summary: 'One session with its sets and, once completed, its summary',
        tags,
        security,
        params: sessionParamsSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.get(requireUserId(request.userId), request.params.id),
  );

  typed.post(
    '/training/sessions/:id/sets',
    {
      schema: {
        summary: 'Log 1–50 sets (idempotent on clientSetId); merge:true adds to a completed session (§33)',
        tags,
        security,
        params: sessionParamsSchema,
        body: logSetsRequestSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.logSets(requireUserId(request.userId), request.params.id, request.body),
  );

  typed.patch(
    '/training/sessions/:id/sets/:setId',
    {
      schema: {
        summary: 'Correct a set',
        tags,
        security,
        params: sessionSetParamsSchema,
        body: patchSetRequestSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.patchSet(requireUserId(request.userId), request.params.id, request.params.setId, request.body),
  );

  typed.delete(
    '/training/sessions/:id/sets/:setId',
    {
      schema: {
        summary: 'Remove a mis-logged set (soft delete)',
        tags,
        security,
        params: sessionSetParamsSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.deleteSet(requireUserId(request.userId), request.params.id, request.params.setId),
  );

  typed.post(
    '/training/sessions/:id/exercises',
    {
      schema: {
        summary: 'Add an exercise mid-session (idempotent on clientExerciseId)',
        tags,
        security,
        params: sessionParamsSchema,
        body: addSessionExerciseRequestSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.addExercise(requireUserId(request.userId), request.params.id, request.body),
  );

  typed.patch(
    '/training/sessions/:id/exercises/:exerciseId',
    {
      schema: {
        summary: 'Reorder, superset, replace or remove a session exercise',
        tags,
        security,
        params: sessionExerciseParamsSchema,
        body: patchSessionExerciseRequestSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) =>
      service.patchExercise(requireUserId(request.userId), request.params.id, request.params.exerciseId, request.body),
  );

  typed.post(
    '/training/sessions/:id/complete',
    {
      schema: {
        summary: 'Finish: records, mesocycle week, summary (idempotent)',
        tags,
        security,
        params: sessionParamsSchema,
        body: completeSessionRequestSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.complete(requireUserId(request.userId), request.params.id, request.body),
  );

  typed.post(
    '/training/sessions/:id/abandon',
    {
      schema: {
        summary: 'Abandon an active session (kept for history, never counts toward records)',
        tags,
        security,
        params: sessionParamsSchema,
        response: { 200: workoutSessionSchema, ...errors },
      },
    },
    async (request) => service.abandon(requireUserId(request.userId), request.params.id),
  );
}
