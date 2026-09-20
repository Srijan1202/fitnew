/**
 * /v1/training/program* — HTTP and Zod only (§8.3). All protected by default-deny.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  errorEnvelopeSchema,
  generateProgramRequestSchema,
  patchProgramDayRequestSchema,
  programDayIdParamsSchema,
  programSchema,
  putProgramRequestSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { TrainingRepository } from './repository.js';
import { TrainingService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function trainingRoutes(app: FastifyInstance): Promise<void> {
  const service = new TrainingService(new TrainingRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = {
    401: errorEnvelopeSchema,
    404: errorEnvelopeSchema,
    409: errorEnvelopeSchema,
    422: errorEnvelopeSchema,
  };

  typed.get(
    '/training/program',
    {
      schema: {
        summary: 'Active programme with its week',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        response: { 200: programSchema, ...errors },
      },
    },
    async (request) => service.getProgram(requireUserId(request.userId)),
  );

  typed.post(
    '/training/program/generate',
    {
      schema: {
        summary: 'Generate from the profile (goal, experience, days, equipment, limitations); replaces the active programme',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        body: generateProgramRequestSchema.optional(),
        response: { 200: programSchema, ...errors },
      },
    },
    async (request) => service.generate(requireUserId(request.userId), request.body ?? {}),
  );

  typed.put(
    '/training/program',
    {
      schema: {
        summary: 'Replace the active programme with a custom one',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        body: putProgramRequestSchema,
        response: { 200: programSchema, ...errors },
      },
    },
    async (request) => service.putCustom(requireUserId(request.userId), request.body),
  );

  typed.patch(
    '/training/program/days/:id',
    {
      schema: {
        summary: 'Edit one day of the active programme (name and/or exercises)',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        params: programDayIdParamsSchema,
        body: patchProgramDayRequestSchema,
        response: { 200: programSchema, ...errors },
      },
    },
    async (request) => service.patchDay(requireUserId(request.userId), request.params.id, request.body),
  );
}
