/**
 * /v1/exercises — HTTP and Zod only (§8.3). Protected by default-deny like
 * everything under /v1; the library is not secret, but an unauthenticated
 * scrape is not a use case either.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  errorEnvelopeSchema,
  exerciseDetailSchema,
  exerciseIdParamsSchema,
  exerciseListQuerySchema,
  exerciseListResponseSchema,
} from '@fitos/contracts';

import { ExerciseRepository } from './repository.js';
import { ExerciseService } from './service.js';

export async function exerciseRoutes(app: FastifyInstance): Promise<void> {
  const service = new ExerciseService(new ExerciseRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/exercises',
    {
      schema: {
        summary: 'Search the library. `equipment` is what you have; results are what you can perform with it.',
        tags: ['exercise'],
        security: [{ bearerAuth: [] }],
        querystring: exerciseListQuerySchema,
        response: { 200: exerciseListResponseSchema, ...errors },
      },
    },
    async (request) => service.list(request.query),
  );

  typed.get(
    '/exercises/:id',
    {
      schema: {
        summary: 'Detail with muscles, alternatives and contraindications',
        tags: ['exercise'],
        security: [{ bearerAuth: [] }],
        params: exerciseIdParamsSchema,
        response: { 200: exerciseDetailSchema, ...errors },
      },
    },
    async (request) => service.detail(request.params.id),
  );
}
