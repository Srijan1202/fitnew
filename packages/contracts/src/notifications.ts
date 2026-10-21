/**
 * Notifications (Phase 15, MASTER-SPEC §21, §10.1; ADR-021).
 *
 * The server plans; the phone schedules. `POST /notifications/plan` takes
 * what happened to earlier notifications on the phone (shown, opened,
 * cancelled) and returns the next days' plan: when, in which words, where a
 * tap goes, and what cancels each one on the phone. Copy is FITOS's own
 * template bank (core `notify/copy.ts`), never an LLM.
 */
import { z } from 'zod';

import { isoDateSchema } from './profile.js';

/** Mirrors core `NOTIFY_KINDS` (the API test asserts they match). */
export const NOTIFY_KINDS = [
  'workout-reminder',
  'missed-session',
  'protein-gap',
  'streak-at-risk',
  'weigh-in',
  'recovery-checkin',
  'weekly-recap',
  'comeback',
] as const;
export const notifyKindSchema = z.enum(NOTIFY_KINDS);
export type NotifyKind = z.infer<typeof notifyKindSchema>;

export const NOTIFY_TONES = ['cheeky', 'gentle'] as const;
export const notifyToneSchema = z.enum(NOTIFY_TONES);

export const NOTIFY_SCREENS = ['today', 'plan', 'food-log', 'progress'] as const;
export const CANCEL_EVENTS = ['workout-started', 'workout-completed', 'food-logged', 'protein-reached', 'weight-logged', 'checkin-logged', 'any-activity', 'app-opened'] as const;
export const NOTIFY_OUTCOMES = ['delivered', 'opened', 'cancelled'] as const;

const clock = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'HH:MM, 24-hour');

export const notifySettingsSchema = z
  .object({
    enabled: z.boolean(),
    tone: notifyToneSchema,
    /** §21: every kind individually toggleable. */
    kinds: z.object(Object.fromEntries(NOTIFY_KINDS.map((k) => [k, z.boolean()])) as Record<NotifyKind, z.ZodBoolean>).strict(),
    quietStart: clock,
    quietEnd: clock,
  })
  .strict();
export type NotifySettings = z.infer<typeof notifySettingsSchema>;

/** PATCH semantics: any subset, kinds too. */
export const notifySettingsPatchSchema = z
  .object({
    enabled: z.boolean().optional(),
    tone: notifyToneSchema.optional(),
    kinds: z.object(Object.fromEntries(NOTIFY_KINDS.map((k) => [k, z.boolean().optional()])) as Record<NotifyKind, z.ZodOptional<z.ZodBoolean>>).strict().optional(),
    quietStart: clock.optional(),
    quietEnd: clock.optional(),
  })
  .strict();
export type NotifySettingsPatch = z.infer<typeof notifySettingsPatchSchema>;

export const cancelRuleSchema = z
  .object({
    event: z.enum(CANCEL_EVENTS),
    localDate: isoDateSchema,
    /** protein-reached only: today's protein (high end) that makes the nudge pointless. */
    grams: z.number().nonnegative().nullable(),
  })
  .strict();

export const plannedNotificationSchema = z
  .object({
    /** Stable for (user, kind, local date): the phone reports outcomes by it. */
    id: z.string().uuid(),
    kind: notifyKindSchema,
    localDate: isoDateSchema,
    /** The instant to show it. */
    at: z.string().datetime({ offset: true }),
    title: z.string().min(1),
    body: z.string().min(1),
    variant: z.string().min(1),
    tone: notifyToneSchema,
    /** Where a tap goes; `slot` for food-log. */
    screen: z.enum(NOTIFY_SCREENS),
    slot: z.enum(['dinner']).nullable(),
    actions: z.array(z.enum(['snooze'])),
    cancelOn: z.array(cancelRuleSchema),
    /** Why this time — shown in settings. */
    why: z.string().min(1),
  })
  .strict();
export type PlannedNotification = z.infer<typeof plannedNotificationSchema>;

export const notifyEventSchema = z
  .object({
    id: z.string().uuid(),
    event: z.enum(NOTIFY_OUTCOMES),
    at: z.string().datetime({ offset: true }),
  })
  .strict();

export const notifyPlanRequestSchema = z
  .object({
    /** What happened on the phone since the last plan; best effort, replay-safe. */
    events: z.array(notifyEventSchema).max(200).default([]),
  })
  .strict();
export type NotifyPlanRequest = z.infer<typeof notifyPlanRequestSchema>;

export const notifyPlanResponseSchema = z
  .object({
    generatedAt: z.string().datetime({ offset: true }),
    timeZone: z.string(),
    settings: notifySettingsSchema,
    items: z.array(plannedNotificationSchema),
  })
  .strict();
export type NotifyPlanResponse = z.infer<typeof notifyPlanResponseSchema>;

/** FCM registration (§31 Phase 15): stored for server push after hosting; nothing is sent by push yet. */
export const pushTokenRequestSchema = z
  .object({
    token: z.string().min(10).max(4096),
    platform: z.literal('android'),
  })
  .strict();

/** A preview of one kind in the user's tone, with their data — the settings "try it" button. */
export const notifyPreviewRequestSchema = z.object({ kind: notifyKindSchema }).strict();
export const notifyPreviewResponseSchema = z.object({ title: z.string().min(1), body: z.string().min(1) }).strict();
