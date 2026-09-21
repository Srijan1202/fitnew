/**
 * /v1/training/program* — HTTP and Zod only (§8.3). All protected by default-deny.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  errorEnvelopeSchema,
  generateProgramRequestSchema,
  patchProgramDayRequestSchema,
  patchProgramRequestSchema,
  programDayIdParamsSchema,
  programSchema,
  putProgramRequestSchema,
  templateListResponseSchema,
  templatePreviewQuerySchema,
  templatePreviewSchema,
  templateSlugParamsSchema,
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
    '/training/program',
    {
      schema: {
        summary: 'Rename the active programme',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        body: patchProgramRequestSchema,
        response: { 200: programSchema, ...errors },
      },
    },
    async (request) => service.rename(requireUserId(request.userId), request.body.name),
  );

  typed.get(
    '/training/templates',
    {
      schema: {
        summary: 'The professional structure library (no exercises until previewed)',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        response: { 200: templateListResponseSchema, ...errors },
      },
    },
    async () => ({ items: service.listTemplates() }),
  );

  typed.get(
    '/training/templates/:slug',
    {
      schema: {
        summary: 'Preview a template with exercises for THIS profile; nothing is stored',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        params: templateSlugParamsSchema,
        querystring: templatePreviewQuerySchema,
        response: { 200: templatePreviewSchema, ...errors },
      },
    },
    async (request) => service.previewTemplate(requireUserId(request.userId), request.params.slug, request.query),
  );

  typed.post(
    '/training/program/from-template/:slug',
    {
      schema: {
        summary: 'Apply a template as the active programme (same materialisation as the preview)',
        tags: ['training'],
        security: [{ bearerAuth: [] }],
        params: templateSlugParamsSchema,
        body: generateProgramRequestSchema.optional(),
        response: { 200: programSchema, ...errors },
      },
    },
    async (request) => service.applyTemplate(requireUserId(request.userId), request.params.slug, request.body ?? {}),
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
