/**
 * Zod schemas for /health. One schema drives runtime validation, the TS types
 * and the OpenAPI document (§8.1) — there is no second source of truth.
 */
import { z } from 'zod';

export const healthResponseSchema = z.object({
  status: z.literal('ok'),
  uptimeSeconds: z.number().nonnegative(),
  database: z.object({
    reachable: z.literal(true),
    latencyMs: z.number().nonnegative(),
  }),
});

export const healthUnavailableSchema = z.object({
  error: z.object({
    code: z.literal('UPSTREAM_UNAVAILABLE'),
    message: z.string(),
    requestId: z.string(),
  }),
});

export type HealthResponse = z.infer<typeof healthResponseSchema>;
