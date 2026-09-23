/**
 * /v1/ai/* — Phase 6.6. Status, and chat: the user's message plus the
 * recent exchange in; the assistant's text, navigation actions and the
 * tools it drew on out. Default-deny like every /v1 route; chat is rate
 * limited tighter than the rest (§10: AI routes tighten).
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import { aiChatRequestSchema, aiChatResponseSchema, aiStatusResponseSchema, errorEnvelopeSchema } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { ExerciseRepository } from '../exercise/repository.js';
import { ExerciseService } from '../exercise/service.js';
import { TrainingRepository } from '../training/repository.js';
import { TrainingService } from '../training/service.js';
import { UserRepository } from '../user/repository.js';
import { UserService } from '../user/service.js';
import { WorkoutRepository } from '../workout/repository.js';
import { WorkoutService } from '../workout/service.js';
import { UserContextAssembler } from './context-assembler.js';
import { AiService } from './service.js';
import { ToolRegistry } from './tools.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

/**
 * Per user: a chat is a model call; 20 a minute is generous for a person.
 *
 * Keyed by the authenticated user (Phase 6.7, O7). Until then it fell back to
 * the plugin's default key, the client IP — people sharing a carrier NAT or
 * a Wi-Fi shared one allowance. It runs at preHandler because the user id is
 * only known once the auth hook (onRequest) has verified the token; a request
 * without a valid token is refused there and never reaches this limit.
 */
export const AI_CHAT_RATE_LIMIT = {
  max: 20,
  timeWindow: '1 minute',
  hook: 'preHandler',
  keyGenerator: (request: FastifyRequest): string =>
    request.userId !== null ? `user:${request.userId}` : `ip:${request.ip}`,
} as const;

export async function aiRoutes(app: FastifyInstance): Promise<void> {
  const db = app.database.db;
  const services = {
    user: new UserService(new UserRepository(db)),
    training: new TrainingService(new TrainingRepository(db)),
    workout: new WorkoutService(new WorkoutRepository(db), new TrainingRepository(db)),
    exercise: new ExerciseService(new ExerciseRepository(db)),
  };
  const service = new AiService(app.ai, {
    assembler: new UserContextAssembler(services),
    tools: new ToolRegistry(services),
    log: app.log,
  });
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = { 401: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema, 503: errorEnvelopeSchema };

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

  typed.post(
    '/ai/chat',
    {
      config: { rateLimit: AI_CHAT_RATE_LIMIT },
      schema: {
        summary: 'Ask FITOS AI; answered from the user\'s own FITOS data through allowlisted tools (stateless)',
        tags: ['ai'],
        security: [{ bearerAuth: [] }],
        body: aiChatRequestSchema,
        response: { 200: aiChatResponseSchema, ...errors },
      },
    },
    async (request) => service.chat(requireUserId(request.userId), request.body),
  );
}
