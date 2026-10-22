/**
 * Feedback (Phase 19, MASTER-SPEC §31 "feedback channel"; owner 2026-10-22:
 * an in-app form, read in the admin panel). A tester writes a message under a
 * category; the app adds its version. Nothing else about the phone is sent.
 * The rows belong to the user: exported with their data and deleted with
 * their account (Phase 17's foreign-key graph).
 */
import { z } from 'zod';

const iso = z.string().datetime({ offset: true });

export const FEEDBACK_CATEGORIES = ['bug', 'idea', 'food', 'training', 'other'] as const;
export const FEEDBACK_STATUSES = ['new', 'read', 'done'] as const;
/** The owner's triage tag, most urgent first: red, then yellow, then green. */
export const FEEDBACK_PRIORITIES = ['red', 'yellow', 'green'] as const;
export const FEEDBACK_MAX_LENGTH = 2000;
/** Per user per hour: enough for a tester, too few for a flood. */
export const FEEDBACK_PER_HOUR = 5;

export const feedbackCategorySchema = z.enum(FEEDBACK_CATEGORIES);
export const feedbackStatusSchema = z.enum(FEEDBACK_STATUSES);
export const feedbackPrioritySchema = z.enum(FEEDBACK_PRIORITIES);

export const sendFeedbackRequestSchema = z
  .object({
    category: feedbackCategorySchema,
    message: z.string().trim().min(1).max(FEEDBACK_MAX_LENGTH),
    // e.g. "1.0.0-beta.1+4": the app's own version and build number.
    appVersion: z.string().trim().min(1).max(40),
  })
  .strict();

export const sendFeedbackResponseSchema = z.object({ id: z.string().uuid(), createdAt: iso }).strict();

export const adminFeedbackQuerySchema = z
  .object({
    status: feedbackStatusSchema.optional(),
    /** One tag, or `none` for feedback not tagged yet. */
    priority: z.enum([...FEEDBACK_PRIORITIES, 'none']).optional(),
    limit: z.coerce.number().int().min(1).max(200).default(50),
    before: iso.optional(),
  })
  .strict();

/** The sender is an id only: the admin looks them up through the audited support view if needed. */
export const adminFeedbackItemSchema = z
  .object({
    id: z.string().uuid(),
    userId: z.string().uuid(),
    category: feedbackCategorySchema,
    message: z.string(),
    appVersion: z.string(),
    status: feedbackStatusSchema,
    priority: feedbackPrioritySchema.nullable(),
    createdAt: iso,
  })
  .strict();

export const adminFeedbackListSchema = z.object({ items: z.array(adminFeedbackItemSchema), next: iso.nullable() }).strict();

/** A status, a priority (null clears it), or both; each change audited. */
export const updateFeedbackRequestSchema = z
  .object({ status: feedbackStatusSchema.optional(), priority: feedbackPrioritySchema.nullable().optional() })
  .strict()
  .refine((b) => b.status !== undefined || b.priority !== undefined, { message: 'give a status, a priority, or both' });

export type FeedbackCategory = z.infer<typeof feedbackCategorySchema>;
export type FeedbackStatus = z.infer<typeof feedbackStatusSchema>;
export type FeedbackPriority = z.infer<typeof feedbackPrioritySchema>;
export type UpdateFeedbackRequest = z.infer<typeof updateFeedbackRequestSchema>;
export type SendFeedbackRequest = z.infer<typeof sendFeedbackRequestSchema>;
export type AdminFeedbackItem = z.infer<typeof adminFeedbackItemSchema>;
export type AdminFeedbackList = z.infer<typeof adminFeedbackListSchema>;
