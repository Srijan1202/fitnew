/**
 * Feedback (Phase 19, MASTER-SPEC §31 "feedback channel"; owner 2026-10-22:
 * an in-app form, read in the admin panel). A tester writes a message under a
 * category; the app adds its version. Nothing else about the phone is sent.
 * The rows belong to the user: exported with their data and deleted with
 * their account (Phase 17's foreign-key graph).
 *
 * Beta 3.6 (owner): up to three pictures (deleted after six months), the
 * phone's model and Android version and the screen it was sent from (shown
 * before sending, and can be left out), and replies from the FITOS team,
 * which the sender reads in the app and is told about by a notification.
 */
import { z } from 'zod';

const iso = z.string().datetime({ offset: true });

export const FEEDBACK_CATEGORIES = ['bug', 'idea', 'food', 'training', 'other'] as const;
export const FEEDBACK_STATUSES = ['new', 'read', 'done'] as const;
/** The owner's triage tag, most urgent first: red, then yellow, then green. */
export const FEEDBACK_PRIORITIES = ['red', 'yellow', 'green'] as const;
export const FEEDBACK_MAX_LENGTH = 2000;
/** Per user per hour: enough for a tester, too few for a flood. */
/** Per person per hour (owner 2026-10-24: 5 stopped a keen tester); admins are not limited. */
export const FEEDBACK_PER_HOUR = 20;

/** Beta 3.6: pictures per message, each resized on the phone first. */
export const FEEDBACK_MAX_PICTURES = 3;
export const FEEDBACK_PICTURE_MAX_BYTES = 1_000_000;
export const FEEDBACK_PICTURE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
/** Pictures are deleted this long after they were sent; the text stays. */
export const FEEDBACK_PICTURE_DAYS = 180;
export const FEEDBACK_REPLY_MAX_LENGTH = 2000;

export const feedbackCategorySchema = z.enum(FEEDBACK_CATEGORIES);
export const feedbackStatusSchema = z.enum(FEEDBACK_STATUSES);
export const feedbackPrioritySchema = z.enum(FEEDBACK_PRIORITIES);

export const feedbackPictureTypeSchema = z.enum(FEEDBACK_PICTURE_TYPES);

/** The phone, when the sender leaves it in (beta 3.6). */
export const feedbackDeviceSchema = z
  .object({
    /** e.g. "Samsung SM-S921B". */
    model: z.string().trim().min(1).max(80),
    /** e.g. "Android 15". */
    os: z.string().trim().min(1).max(40),
    /** The screen feedback was opened from, e.g. "/plan/session". */
    screen: z.string().trim().min(1).max(80).nullable(),
  })
  .strict();

/** Base64 of at most FEEDBACK_PICTURE_MAX_BYTES bytes. */
const pictureData = z
  .string()
  .min(4)
  .max(Math.ceil(FEEDBACK_PICTURE_MAX_BYTES / 3) * 4)
  .regex(/^[A-Za-z0-9+/]+={0,2}$/, 'base64');

export const sendFeedbackRequestSchema = z
  .object({
    category: feedbackCategorySchema,
    message: z.string().trim().min(1).max(FEEDBACK_MAX_LENGTH),
    // e.g. "1.0.0-beta.1+4": the app's own version and build number.
    appVersion: z.string().trim().min(1).max(40),
    device: feedbackDeviceSchema.nullable().optional(),
    pictures: z
      .array(z.object({ type: feedbackPictureTypeSchema, data: pictureData }).strict())
      .max(FEEDBACK_MAX_PICTURES)
      .optional(),
  })
  .strict();

export const sendFeedbackResponseSchema = z.object({ id: z.string().uuid(), createdAt: iso }).strict();

export const adminFeedbackQuerySchema = z
  .object({
    /** A status, or `open` for everything not done yet (new or read): the to-do list. */
    status: z.enum([...FEEDBACK_STATUSES, 'open']).optional(),
    /** One tag, or `none` for feedback not tagged yet. */
    priority: z.enum([...FEEDBACK_PRIORITIES, 'none']).optional(),
    /** Beta 3.6: one type of feedback. */
    category: feedbackCategorySchema.optional(),
    limit: z.coerce.number().int().min(1).max(200).default(50),
    before: iso.optional(),
  })
  .strict();

/** A reply from the FITOS team (beta 3.6). */
export const feedbackReplySchema = z
  .object({ id: z.string().uuid(), message: z.string(), createdAt: iso, readAt: iso.nullable() })
  .strict();

export const feedbackPictureSchema = z.object({ id: z.string().uuid(), type: feedbackPictureTypeSchema, bytes: z.number().int() }).strict();

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
    device: feedbackDeviceSchema.nullable(),
    pictures: z.array(feedbackPictureSchema),
    replies: z.array(feedbackReplySchema),
  })
  .strict();

export const adminFeedbackListSchema = z.object({ items: z.array(adminFeedbackItemSchema), next: iso.nullable() }).strict();

/** How much is waiting (after beta 3.2): open feedback not tagged yet, open feedback per tag, and done. */
export const adminFeedbackCountsSchema = z
  .object({
    untagged: z.number().int().min(0),
    red: z.number().int().min(0),
    yellow: z.number().int().min(0),
    green: z.number().int().min(0),
    done: z.number().int().min(0),
  })
  .strict();

/** A status, a priority (null clears it), or both; each change audited. */
export const updateFeedbackRequestSchema = z
  .object({ status: feedbackStatusSchema.optional(), priority: feedbackPrioritySchema.nullable().optional() })
  .strict()
  .refine((b) => b.status !== undefined || b.priority !== undefined, { message: 'give a status, a priority, or both' });

/** An admin's reply; the sender is told by a notification. */
export const replyFeedbackRequestSchema = z.object({ message: z.string().trim().min(1).max(FEEDBACK_REPLY_MAX_LENGTH) }).strict();

/** GET /feedback/mine: the sender's own messages, newest first, with the replies. */
export const myFeedbackItemSchema = z
  .object({
    id: z.string().uuid(),
    category: feedbackCategorySchema,
    message: z.string(),
    status: feedbackStatusSchema,
    createdAt: iso,
    pictures: z.number().int().min(0),
    replies: z.array(feedbackReplySchema),
  })
  .strict();
export const myFeedbackListSchema = z
  .object({ items: z.array(myFeedbackItemSchema), unread: z.number().int().min(0) })
  .strict();

export type FeedbackCategory = z.infer<typeof feedbackCategorySchema>;
export type FeedbackDevice = z.infer<typeof feedbackDeviceSchema>;
export type FeedbackPictureType = z.infer<typeof feedbackPictureTypeSchema>;
export type FeedbackReply = z.infer<typeof feedbackReplySchema>;
export type ReplyFeedbackRequest = z.infer<typeof replyFeedbackRequestSchema>;
export type MyFeedbackList = z.infer<typeof myFeedbackListSchema>;
export type FeedbackStatus = z.infer<typeof feedbackStatusSchema>;
export type FeedbackPriority = z.infer<typeof feedbackPrioritySchema>;
export type UpdateFeedbackRequest = z.infer<typeof updateFeedbackRequestSchema>;
export type SendFeedbackRequest = z.infer<typeof sendFeedbackRequestSchema>;
export type AdminFeedbackItem = z.infer<typeof adminFeedbackItemSchema>;
export type AdminFeedbackList = z.infer<typeof adminFeedbackListSchema>;
export type AdminFeedbackCounts = z.infer<typeof adminFeedbackCountsSchema>;
export type AdminFeedbackStatusFilter = z.infer<typeof adminFeedbackQuerySchema>['status'];
