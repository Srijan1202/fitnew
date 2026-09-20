/**
 * /v1/onboarding/* — HTTP and Zod only (§8.3).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  errorEnvelopeSchema,
  onboardingAnswerSchema,
  onboardingCompleteResponseSchema,
  onboardingStateSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { UserRepository } from '../user/repository.js';
import { OnboardingService } from './service.js';

export interface OnboardingRouteOptions {
  readonly ipSalt: string;
}

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function onboardingRoutes(app: FastifyInstance, opts: OnboardingRouteOptions): Promise<void> {
  const service = new OnboardingService(new UserRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 409: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/onboarding/state',
    {
      schema: {
        summary: 'Where the user is in onboarding, with every stored answer for pre-filling',
        tags: ['onboarding'],
        security: [{ bearerAuth: [] }],
        response: { 200: onboardingStateSchema, ...errors },
      },
    },
    async (request) => service.getState(requireUserId(request.userId)),
  );

  typed.post(
    '/onboarding/answer',
    {
      schema: {
        summary: 'Submit one step. Any step may be (re-)answered at any time; the response is the new state.',
        tags: ['onboarding'],
        security: [{ bearerAuth: [] }],
        body: onboardingAnswerSchema,
        response: { 200: onboardingStateSchema, ...errors },
      },
    },
    async (request) =>
      service.answer(requireUserId(request.userId), request.body, { ip: request.ip, ipSalt: opts.ipSalt }),
  );

  typed.post(
    '/onboarding/complete',
    {
      schema: {
        summary: 'Screen 7: compute real targets from the engine. 409 with the missing steps if not ready.',
        tags: ['onboarding'],
        security: [{ bearerAuth: [] }],
        response: { 200: onboardingCompleteResponseSchema, ...errors },
      },
    },
    async (request) => service.complete(requireUserId(request.userId)),
  );
}
