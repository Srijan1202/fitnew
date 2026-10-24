/**
 * /v1/ai/* — Phase 6.6. Status, and chat: the user's message plus the
 * recent exchange in; the assistant's text, navigation actions and the
 * tools it drew on out. Default-deny like every /v1 route; chat is rate
 * limited tighter than the rest (§10: AI routes tighten).
 *
 * Phase 14 (ADR-020): POST /nutrition/parse (a meal in words → a draft,
 * never stored) and POST /ai/explain (a TODAY reason reworded, numbers
 * checked). Every AI route sits behind the kill switch and the per-user
 * hourly limit and daily token budget, counted from `ai_usage`.
 *
 * Beta 3.6 (F15): POST /nutrition/guide, "What should I eat?" from what the
 * person has and the mess menu, behind the `food-guide` switch.
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  aiChatRequestSchema,
  aiChatResponseSchema,
  aiStatusResponseSchema,
  errorEnvelopeSchema,
  explainRequestSchema,
  explainResponseSchema,
  foodGuideRequestSchema,
  foodGuideResponseSchema,
  parseFoodRequestSchema,
  parseFoodResponseSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { ExerciseRepository } from '../exercise/repository.js';
import { ExerciseService } from '../exercise/service.js';
import { FoodRepository } from '../nutrition/repository.js';
import { FoodService } from '../nutrition/service.js';
import { TodayRepository } from '../today/repository.js';
import { TrainingRepository } from '../training/repository.js';
import { TrainingService } from '../training/service.js';
import { UserRepository } from '../user/repository.js';
import { messServiceFor } from '../mess/routes.js';
import { ReadinessAssembler } from '../recovery/readiness.js';
import { UserService } from '../user/service.js';
import { WorkoutRepository } from '../workout/repository.js';
import { WorkoutService } from '../workout/service.js';
import { UserContextAssembler } from './context-assembler.js';
import { ExplainService } from './explain.js';
import { FoodGuideService } from './guide.js';
import { FoodParseService } from './parse.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { MessRecommendService } from '../mess/recommend-service.js';
import { RecommendRepository } from '../mess/recommend-repository.js';
import { AiService } from './service.js';
import { ToolRegistry } from './tools.js';
import { PrivacyRepository } from '../privacy/repository.js';
import { PremiumRepository } from '../premium/repository.js';
import { PremiumService, premiumRequired } from '../premium/service.js';
import { AiBudget, AiUsageRepository } from './usage.js';

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
    user: new UserService(new UserRepository(db), async (ref) => (await messServiceFor(db).messForRef(ref)) !== null),
    training: new TrainingService(new TrainingRepository(db)),
    workout: new WorkoutService(new WorkoutRepository(db), new TrainingRepository(db), ReadinessAssembler.forDb(db)),
    exercise: new ExerciseService(new ExerciseRepository(db)),
  };
  const consents = new PrivacyRepository(db);
  const premium = new PremiumService(new PremiumRepository(db));
  /** Phase 19 (ADR-027): FITOS AI is premium — refused here, before any lookup or model call. */
  const premiumOf = async (request: FastifyRequest): Promise<boolean> => {
    budget.assertEnabled();
    if (!(await premium.isPremium(requireUserId(request.userId), request.identity?.claims))) throw premiumRequired('FITOS AI');
    return true;
  };
  const budget = new AiBudget(new AiUsageRepository(db), app.aiConfig, undefined, (userId) => consents.hasConsent(userId, 'ai-processing'));
  const service = new AiService(
    app.ai,
    {
      assembler: new UserContextAssembler(services),
      tools: new ToolRegistry(services),
      log: app.log,
      budget,
    },
    app.aiConfig.enabled,
  );
  const parser = new FoodParseService(app.ai, new FoodService(new FoodRepository(db)), budget, app.aiConfig, app.log);
  const explainer = new ExplainService(app.ai, new TodayRepository(db), budget, app.aiConfig, app.log);
  const messes = messServiceFor(db);
  const guide = new FoodGuideService(
    app.ai,
    {
      foods: new FoodService(new FoodRepository(db)),
      users: new UserRepository(db),
      logs: new FoodLogRepository(db),
      mess: messes,
      menus: new MessRecommendService(messes, new UserRepository(db), new FoodLogRepository(db), new RecommendRepository(db)),
    },
    budget,
    app.aiConfig,
    app.log,
  );
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
    async (request) => service.chat(requireUserId(request.userId), request.body, await premiumOf(request)),
  );

  typed.post(
    '/nutrition/parse',
    {
      config: { rateLimit: AI_CHAT_RATE_LIMIT },
      schema: {
        summary: 'A meal in your words → a draft of foods and portions to confirm (Phase 14; nothing is stored)',
        description:
          'Only the text is sent to the model. Each food is matched to the FITOS food database and a portion of its own ' +
          'rows, so the numbers are the database\'s; a food the database lacks is the model\'s estimate, kept only within ' +
          '§19.2\'s bounds. The answer is an AiDraft: requiresConfirmation is always true, and the app logs what the user ' +
          'confirms through POST /nutrition/logs. 503 when AI is switched off or not set up; 429 over the hourly limit.',
        tags: ['nutrition', 'ai'],
        security: [{ bearerAuth: [] }],
        body: parseFoodRequestSchema,
        response: { 200: parseFoodResponseSchema, ...errors },
      },
    },
    async (request) => parser.parse(requireUserId(request.userId), request.body.text, await premiumOf(request)),
  );

  typed.post(
    '/ai/explain',
    {
      config: { rateLimit: AI_CHAT_RATE_LIMIT },
      schema: {
        summary: 'A TODAY action\'s reason in plainer words — or the engine\'s own when the rewording adds a number (Phase 14)',
        tags: ['ai'],
        security: [{ bearerAuth: [] }],
        body: explainRequestSchema,
        response: { 200: explainResponseSchema, 404: errorEnvelopeSchema, ...errors },
      },
    },
    async (request) => explainer.explain(requireUserId(request.userId), request.body.actionId, await premiumOf(request)),
  );

  typed.post(
    '/nutrition/guide',
    {
      config: { rateLimit: AI_CHAT_RATE_LIMIT },
      schema: {
        summary: 'Beta 3.6: "What should I eat?" — up to 3 plates for one meal of today, from what you have and your mess menu (nothing is stored)',
        description:
          'What you have is matched to the FITOS food database (unknown things are listed, never guessed); the mess menu is ' +
          "filtered by Phase 10's diet and allergen rules. The model picks plates from those only; every number is the " +
          "database's or the mess table's. Sent to the model: the meal, the foods' names and rough numbers, what is left of " +
          "today's calories and protein, and what you feel like. Premium; needs the FITOS AI consent; behind the food-guide switch.",
        tags: ['nutrition', 'ai'],
        security: [{ bearerAuth: [] }],
        body: foodGuideRequestSchema,
        response: { 200: foodGuideResponseSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, ...errors },
      },
    },
    async (request) => {
      await app.features.require('food-guide');
      return guide.guide(requireUserId(request.userId), request.body, await premiumOf(request));
    },
  );
}
