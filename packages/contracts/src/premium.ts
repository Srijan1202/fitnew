/**
 * Premium (Phase 19, ADR-027; owner 2026-10-22). FITOS AI, the weekly report,
 * the colour themes and three of the ten profile pictures are premium. A user
 * asks for premium from the app; the owner approves it in the admin panel; it
 * lasts until revoked. Anyone with the admin role is premium without asking.
 */
import { z } from 'zod';

const iso = z.string().datetime({ offset: true });

/* ---------------------------------------------------------- the avatars -- */

/** The ten profile pictures, drawn in the app. The last three are premium. */
export const AVATARS = [
  { id: 'dumbbell', premium: false },
  { id: 'runner', premium: false },
  { id: 'yoga', premium: false },
  { id: 'cyclist', premium: false },
  { id: 'swimmer', premium: false },
  { id: 'boxer', premium: false },
  { id: 'hiker', premium: false },
  { id: 'crown', premium: true },
  { id: 'flame', premium: true },
  { id: 'trophy', premium: true },
] as const;
export const AVATAR_IDS = AVATARS.map((a) => a.id) as unknown as readonly [string, ...string[]];
export const PREMIUM_AVATAR_IDS: readonly string[] = AVATARS.filter((a) => a.premium).map((a) => a.id);
export const avatarIdSchema = z.enum(AVATAR_IDS as [string, ...string[]]);

export const setAvatarRequestSchema = z.object({ avatarId: avatarIdSchema.nullable() }).strict();
export const avatarResponseSchema = z.object({ avatarId: avatarIdSchema.nullable() }).strict();

/* -------------------------------------------------------------- status -- */

export const PREMIUM_REQUEST_STATUSES = ['pending', 'approved', 'denied'] as const;
export const premiumRequestStatusSchema = z.enum(PREMIUM_REQUEST_STATUSES);
export const PREMIUM_MESSAGE_MAX = 500;
export const PREMIUM_NOTE_MAX = 300;

export const premiumRequestSchema = z
  .object({
    id: z.string().uuid(),
    status: premiumRequestStatusSchema,
    message: z.string().nullable(),
    createdAt: iso,
    decidedAt: iso.nullable(),
    /** The owner's note when denying (or approving); shown to the user. */
    note: z.string().nullable(),
  })
  .strict();

/** GET /premium: what the app needs to lock or unlock. */
export const premiumStatusSchema = z
  .object({
    premium: z.boolean(),
    /** 'granted' (approved), 'admin' (the role), or null when not premium. */
    source: z.enum(['granted', 'admin']).nullable(),
    since: iso.nullable(),
    /** The latest request, if any. */
    request: premiumRequestSchema.nullable(),
  })
  .strict();

export const requestPremiumSchema = z
  .object({ message: z.string().trim().max(PREMIUM_MESSAGE_MAX).optional() })
  .strict();

/* --------------------------------------------------------------- admin -- */

export const adminPremiumQuerySchema = z
  .object({ status: premiumRequestStatusSchema.optional(), limit: z.coerce.number().int().min(1).max(200).default(50) })
  .strict();

/** The admin needs to know who is asking: the request shows the email and name. */
export const adminPremiumRequestSchema = premiumRequestSchema
  .extend({ userId: z.string().uuid(), email: z.string().nullable(), displayName: z.string().nullable(), userPremium: z.boolean() })
  .strict();
export const adminPremiumRequestListSchema = z.object({ items: z.array(adminPremiumRequestSchema) }).strict();

export const decidePremiumRequestSchema = z
  .object({ decision: z.enum(['approve', 'deny']), note: z.string().trim().max(PREMIUM_NOTE_MAX).optional() })
  .strict();

export const adminPremiumMemberSchema = z
  .object({ userId: z.string().uuid(), email: z.string().nullable(), displayName: z.string().nullable(), since: iso, grantedBy: z.string().nullable() })
  .strict();
export const adminPremiumMemberListSchema = z.object({ items: z.array(adminPremiumMemberSchema) }).strict();

export type AvatarId = z.infer<typeof avatarIdSchema>;
export type PremiumStatus = z.infer<typeof premiumStatusSchema>;
export type PremiumRequest = z.infer<typeof premiumRequestSchema>;
export type AdminPremiumRequest = z.infer<typeof adminPremiumRequestSchema>;
export type AdminPremiumMember = z.infer<typeof adminPremiumMemberSchema>;
