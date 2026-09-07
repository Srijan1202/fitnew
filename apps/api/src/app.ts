/**
 * Fastify assembly. Kept separate from `server.ts` so tests can build an app
 * without binding a port.
 */
import Fastify, { type FastifyInstance } from 'fastify';
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
import dbPlugin from './plugins/db.js';
import errorHandlerPlugin from './plugins/error-handler.js';
import { healthRoutes } from './modules/health/routes.js';

export interface BuildAppOptions {
  /** Supplied by tests to exercise routes without a live Postgres. */
  readonly database?: DatabaseHandle;
}

export async function buildApp(env: Env, options: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({
    logger: loggerOptions(env.LOG_LEVEL, env.NODE_ENV === 'development'),
    // Cloud Run terminates TLS and forwards the client IP in X-Forwarded-For;
    // without this the rate limiter would see one proxy IP for every user.
    trustProxy: true,
    disableRequestLogging: false,
  });

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
      servers: [{ url: '/v1', description: 'Versioned base path' }],
    },
    transform: jsonSchemaTransform,
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  // §10: default 120 req/min/user. Stricter buckets land with the routes that
  // need them (auth 10/min/IP, AI 20/hour/user) in Phases 1 and 14.
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

  // /health is intentionally unversioned — probes should not have to track
  // an API version to know whether the service is alive.
  await app.register(healthRoutes);

  return app;
}
