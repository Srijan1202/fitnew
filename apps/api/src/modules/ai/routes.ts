/**
 * /v1/ai/* — Phase 6.6. Gate 3 exposes status only; chat arrives in Gate
 * 4. Default-deny like every /v1 route.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import { aiStatusResponseSchema, errorEnvelopeSchema } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { AiService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function aiRoutes(app: FastifyInstance): Promise<void> {
  const service = new AiService(app.ai);
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = { 401: errorEnvelopeSchema, 503: errorEnvelopeSchema };

  typed.get(
    '/ai/status',
    {
      schema: {
        summary: 'Whether FITOS AI is set up on this server, and what it never sees',
        tags: ['ai'],
        security: [{ bearerAuth: [] }],
        response: { 200: aiStatusResponseSchema, ...errors },
      },
    },
    async (request) => {
      requireUserId(request.userId);
      return service.status();
    },
  );
}
