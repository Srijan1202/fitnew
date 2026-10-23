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

/* -------------------------------------------------- community foods -- */

/** POST /nutrition/foods/:id/report — "these numbers look wrong" on someone else's shared food. */
export const reportFoodRequestSchema = z
  .object({ note: z.string().trim().min(1).max(300).optional() })
  .strict();

export const COMMUNITY_VISIBILITIES = ['community', 'hidden'] as const;

export const adminCommunityFoodQuerySchema = z
  .object({
    filter: z.enum(['reported', 'community', 'hidden', 'all']).default('reported'),
    limit: z.coerce.number().int().min(1).max(200).default(100),
  })
  .strict();

/** A shared food as the admin panel lists it: never who added it. */
export const adminCommunityFoodSchema = z
  .object({
    id: z.string().uuid(),
    name: z.string(),
    brand: z.string().nullable(),
    visibility: z.enum(COMMUNITY_VISIBILITIES),
    /** The label's first row as entered: basis, serving and macros. */
    basis: z.string(),
    servingLabel: z.string().nullable(),
    kcal: z.number(),
    proteinG: z.number(),
    carbG: z.number(),
    fatG: z.number(),
    reports: z.number().int(),
    /** The latest notes, newest first, at most three. */
    notes: z.array(z.string()),
    createdAt: iso,
  })
  .strict();

export const adminCommunityFoodListSchema = z.object({ items: z.array(adminCommunityFoodSchema) }).strict();

export const setCommunityFoodVisibilityRequestSchema = z
  .object({ visibility: z.enum(COMMUNITY_VISIBILITIES) })
  .strict();

export type ReportFoodRequest = z.infer<typeof reportFoodRequestSchema>;
export type AdminCommunityFood = z.infer<typeof adminCommunityFoodSchema>;
export type AdminCommunityFoodList = z.infer<typeof adminCommunityFoodListSchema>;
