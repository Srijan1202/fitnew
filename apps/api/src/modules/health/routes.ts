/**
 * GET /livez — the process is up (Phase 6.7). Cloud Run's startup probe uses
 * this. It touches nothing else: a probe that pinged the database would keep
 * Neon's free compute awake around the clock and spend its CU-hours.
 *
 * GET /health — liveness plus a real database ping (§10.1).
 * A deployment and manual check, not a high-frequency uptime probe.
 *
 * Unauthenticated by design: deploy smoke checks and people call it. §8.4's
 * keep-warm ping is deliberately NOT scheduled for the hosted alpha (Phase
 * 6.7): it would spend Neon's free compute hours keeping an idle database up.
 *
 * It returns 200 ONLY when the database actually answers. A health check that
 * reports ok while the database is unreachable is worse than no health check —
 * it makes an outage look like a success.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import { pingDatabase } from '../../db/client.js';
import { healthResponseSchema, healthUnavailableSchema, livezResponseSchema } from './schemas.js';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.withTypeProvider<ZodTypeProvider>().get(
    '/livez',
    {
      schema: {
        summary: 'Process liveness only (no database)',
        tags: ['meta'],
        response: { 200: livezResponseSchema },
      },
    },
    async () => ({ status: 'ok' as const, uptimeSeconds: Math.round(process.uptime()) }),
  );

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
