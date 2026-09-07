/**
 * GET /health — liveness plus a real database ping (§10.1).
 *
 * Unauthenticated by design: Cloud Scheduler pings this every few minutes
 * during Indian waking hours to keep both Cloud Run and Neon warm (§8.4).
 *
 * It returns 200 ONLY when the database actually answers. A health check that
 * reports ok while the database is unreachable is worse than no health check —
 * it makes an outage look like a success.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import { pingDatabase } from '../../db/client.js';
import { healthResponseSchema, healthUnavailableSchema } from './schemas.js';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.withTypeProvider<ZodTypeProvider>().get(
    '/health',
    {
      schema: {
        summary: 'Liveness and database reachability',
        tags: ['meta'],
        response: {
          200: healthResponseSchema,
          503: healthUnavailableSchema,
        },
      },
    },
    async (request, reply) => {
      try {
        const latencyMs = await pingDatabase(app.database.client);
        return reply.status(200).send({
          status: 'ok' as const,
          uptimeSeconds: Math.round(process.uptime()),
          database: { reachable: true as const, latencyMs },
        });
      } catch (error) {
        request.log.error({ err: error }, 'Health check failed: database unreachable');
        return reply.status(503).send({
          error: {
            code: 'UPSTREAM_UNAVAILABLE' as const,
            message: 'The database is not reachable.',
            requestId: request.id,
          },
        });
      }
    },
  );
}
