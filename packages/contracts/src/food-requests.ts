/**
 * Beta 3.2 (ADR-032): foods people searched for and did not find. The app
 * reports an empty search (and "Ask us to add it"); the admin panel lists
 * them, most-wanted first, and marks each one. Nothing here names a person.
 */
import { z } from 'zod';

const iso = z.string().datetime({ offset: true });

/** POST /nutrition/foods/requests — the text as typed; the server normalises it. */
export const reportMissingFoodRequestSchema = z
  .object({
    query: z.string().trim().min(2).max(120),
    /** True when the person tapped "Ask us to add it". */
    asked: z.boolean().default(false),
  })
  .strict();

export const FOOD_REQUEST_STATUSES = ['open', 'added', 'already-there', 'ignored'] as const;
export const foodRequestStatusSchema = z.enum(FOOD_REQUEST_STATUSES);

export const adminFoodRequestQuerySchema = z
  .object({
    status: z.enum([...FOOD_REQUEST_STATUSES, 'all']).default('open'),
    limit: z.coerce.number().int().min(1).max(200).default(100),
  })
  .strict();

export const adminFoodRequestSchema = z
  .object({
    id: z.string().uuid(),
    /** The normalised text people searched. */
    query: z.string(),
    /** Distinct person-days that found nothing. */
    searches: z.number().int(),
    /** Distinct people. */
    people: z.number().int(),
    /** Distinct people who asked for it outright. */
    asked: z.number().int(),
    status: foodRequestStatusSchema,
    firstSeenAt: iso,
    lastSeenAt: iso,
    resolvedAt: iso.nullable(),
  })
  .strict();

export const adminFoodRequestListSchema = z.object({ items: z.array(adminFoodRequestSchema) }).strict();

export const setFoodRequestStatusRequestSchema = z.object({ status: foodRequestStatusSchema }).strict();

export type ReportMissingFoodRequest = z.infer<typeof reportMissingFoodRequestSchema>;
export type FoodRequestStatus = z.infer<typeof foodRequestStatusSchema>;
export type AdminFoodRequest = z.infer<typeof adminFoodRequestSchema>;
export type AdminFoodRequestList = z.infer<typeof adminFoodRequestListSchema>;
