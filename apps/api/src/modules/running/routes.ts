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
  createRunRequestSchema,
  errorEnvelopeSchema,
  patchRunRequestSchema,
  runDetailSchema,
  runListQuerySchema,
  runListSchema,
  runParamsSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { RunningRepository } from './repository.js';
import { RunningService } from './service.js';

/** A marathon at one fix a second is about 200 KB encoded; this leaves room for 14 hours. */
export const RUN_BODY_LIMIT = 2 * 1024 * 1024;

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function runningRoutes(app: FastifyInstance): Promise<void> {
  const service = new RunningService(new RunningRepository(app.database.db));
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
}
