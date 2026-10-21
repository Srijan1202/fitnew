/**
 * Privacy (Phase 17, MASTER-SPEC §23, §10.1; ADR-023): consent per purpose,
 * the data export (portability) and account deletion (erasure).
 */
import { z } from 'zod';

import { consentTypeSchema } from './onboarding.js';

const iso = z.string().datetime({ offset: true });

export const consentStateSchema = z
  .object({
    type: consentTypeSchema,
    /** The latest record for this purpose; false when never granted. */
    granted: z.boolean(),
    policyVersion: z.string().nullable(),
    at: iso.nullable(),
    /** Required purposes cannot be withdrawn here: deleting the account is the way out. */
    required: z.boolean(),
  })
  .strict();
export type ConsentState = z.infer<typeof consentStateSchema>;

export const consentsResponseSchema = z
  .object({
    currentPolicyVersion: z.string(),
    /** True when a required consent was given to an older policy version. */
    needsReconsent: z.boolean(),
    items: z.array(consentStateSchema),
  })
  .strict();
export type ConsentsResponse = z.infer<typeof consentsResponseSchema>;

/** Grant or withdraw one purpose; a required one can only be (re)granted, to the current policy. */
export const setConsentRequestSchema = z.object({ type: consentTypeSchema, granted: z.boolean() }).strict();
export type SetConsentRequest = z.infer<typeof setConsentRequestSchema>;

/** §23.4: everything FITOS holds about the user, machine-readable. */
export const exportResponseSchema = z
  .object({
    format: z.literal('fitos-export'),
    version: z.literal(1),
    exportedAt: iso,
    userId: z.string().uuid(),
    /** What the file is, for a person opening it. */
    notes: z.array(z.string()),
    /** Every table holding the user's rows, by table name; columns as stored. */
    tables: z.record(z.string(), z.array(z.record(z.string(), z.unknown()))),
  })
  .strict();
export type DataExport = z.infer<typeof exportResponseSchema>;

/** §23.3: erasure. Typing DELETE is the confirmation. */
export const deleteAccountRequestSchema = z.object({ confirm: z.literal('DELETE') }).strict();
export const deleteAccountResponseSchema = z
  .object({
    deleted: z.literal(true),
    /** Whether the Firebase sign-in account was removed too (false: it is retried by support, nothing of FITOS remains). */
    signInRemoved: z.boolean(),
  })
  .strict();
