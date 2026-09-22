/**
 * Fastify assembly. Kept separate from `server.ts` so tests can build an app
 * without binding a port.
 */
import Fastify, { type FastifyInstance, type RouteOptions } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import {
  serializerCompiler,
  validatorCompiler,
  jsonSchemaTransform,
} from 'fastify-type-provider-zod';

import type { Env } from './lib/env.js';
import type { DatabaseHandle } from './db/client.js';
import { loggerOptions } from './lib/logger.js';
import { FirebaseTokenVerifier, type TokenVerifier } from './lib/token-verifier.js';
import aiPlugin from './plugins/ai.js';
import authPlugin, { PROTECTED_PREFIX } from './plugins/auth.js';
import dbPlugin from './plugins/db.js';
import errorHandlerPlugin from './plugins/error-handler.js';
import { aiRoutes } from './modules/ai/routes.js';
import type { AiProvider } from './modules/ai/provider.js';
import { authRoutes } from './modules/auth/routes.js';
import { healthRoutes } from './modules/health/routes.js';
import { exerciseRoutes } from './modules/exercise/routes.js';
import { onboardingRoutes } from './modules/onboarding/routes.js';
import { trainingRoutes } from './modules/training/routes.js';
import { workoutRoutes } from './modules/workout/routes.js';
import { userRoutes } from './modules/user/routes.js';
import { users } from './db/schema.js';
import { eq } from 'drizzle-orm';

export interface BuildAppOptions {
  /** Supplied by tests to exercise routes without a live Postgres. */
  readonly database?: DatabaseHandle;
  /** Supplied by tests to verify scripted tokens without Firebase. */
  readonly tokenVerifier?: TokenVerifier;
  /** Supplied by tests that have no database to map uid → users.id. */
  readonly resolveUserId?: (firebaseUid: string) => Promise<string | null>;
  /**
   * Observes every route as it is registered. Used by the default-deny sweep
   * test so a route added in any later phase is checked automatically.
   */
  readonly onRoute?: (route: RouteOptions) => void;
  /** Supplied by tests to script the language model (Phase 6.6). */
  readonly aiProvider?: AiProvider;
}

export async function buildApp(env: Env, options: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({
    logger: loggerOptions(env.LOG_LEVEL, env.NODE_ENV === 'development'),
    // Cloud Run terminates TLS and forwards the client IP in X-Forwarded-For;
    // without this the rate limiter would see one proxy IP for every user.
    trustProxy: true,
    disableRequestLogging: false,
  });

  if (options.onRoute !== undefined) app.addHook('onRoute', options.onRoute);

  // Zod drives validation, serialisation and the OpenAPI document (§8.1).
  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  await app.register(errorHandlerPlugin);

  await app.register(swagger, {
    openapi: {
      openapi: '3.1.0',
      info: {
        title: 'FitOS API',
        description:
          'Deterministic fitness engine API. Every number is computed in packages/core, never by a language model (spec §19.1).',
        version: '0.1.0',
      },
      servers: [{ url: PROTECTED_PREFIX, description: 'Versioned base path' }],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'Firebase ID token',
            description: 'Required on every /v1 route except those marked public (§10).',
          },
        },
      },
    },
    transform: jsonSchemaTransform,
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  // §10: default 120 req/min/user. /auth/session tightens this to 10/min/IP on
  // its own routes; AI routes tighten further in Phase 14.
  await app.register(rateLimit, {
    max: 120,
    timeWindow: '1 minute',
  });

  await app.register(
    dbPlugin,
    options.database !== undefined
      ? { handle: options.database }
      : { connectionString: env.DATABASE_URL },
  );

  await app.register(authPlugin, {
    verifier:
      options.tokenVerifier ??
      new FirebaseTokenVerifier({
        projectId: env.FIREBASE_PROJECT_ID,
        credentialsPath: env.GOOGLE_APPLICATION_CREDENTIALS,
      }),
    resolveUserId:
      options.resolveUserId ??
      (async (firebaseUid) => {
        const [row] = await app.database.db
          .select({ id: users.id })
          .from(users)
          .where(eq(users.firebaseUid, firebaseUid))
          .limit(1);
        return row?.id ?? null;
      }),
  });

  await app.register(aiPlugin, options.aiProvider !== undefined ? { provider: options.aiProvider } : { env });

  // /health is intentionally unversioned — probes should not have to track
  // an API version to know whether the service is alive.
  await app.register(healthRoutes);

  // Everything under /v1 is authenticated by default (plugins/auth.ts).
  await app.register(
    async (v1) => {
      await v1.register(authRoutes);
      await v1.register(userRoutes);
      await v1.register(onboardingRoutes, { ipSalt: env.CONSENT_IP_SALT });
      await v1.register(exerciseRoutes);
      await v1.register(trainingRoutes);
      await v1.register(workoutRoutes);
      await v1.register(aiRoutes);
    },
    { prefix: PROTECTED_PREFIX },
  );

  return app;
}
