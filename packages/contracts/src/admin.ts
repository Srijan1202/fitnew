/**
 * Admin (Phase 16, MASTER-SPEC §20, §10.1; ADR-022). Every route is
 * /v1/admin/* behind the Firebase custom claim `role: admin`, checked on the
 * server for every request; every change writes `audit_logs`. The support
 * lookup never shows body photos or raw food logs (§20).
 */
import { z } from 'zod';

import { exerciseSeedSchema, movementPatternSchema, slugSchema } from './exercise.js';
import { foodNutritionSchema, foodSourceSchema } from './food.js';
import { equipmentSchema } from './profile.js';

const iso = z.string().datetime({ offset: true });
const isoOrNull = iso.nullable();

export const adminMeSchema = z.object({ userId: z.string().uuid().nullable(), email: z.string().nullable(), isAdmin: z.literal(true) }).strict();

/* ------------------------------------------------------ provider health -- */

export const ENDPOINT_STATES = ['ok', 'stale', 'failing', 'never'] as const;

export const endpointHealthSchema = z
  .object({
    code: z.string(),
    label: z.string(),
    sourceUrl: z.string(),
    lastAttemptAt: isoOrNull,
    lastSuccessAt: isoOrNull,
    lastChangedAt: isoOrNull,
    lastError: z.string().nullable(),
    consecutiveFailures: z.number().int().nonnegative(),
    state: z.enum(ENDPOINT_STATES),
    hoursSinceSuccess: z.number().nullable(),
  })
  .strict();

export const recommendationRateSchema = z
  .object({
    kind: z.string(),
    shown: z.number().int(),
    opened: z.number().int(),
    accepted: z.number().int(),
    dismissed: z.number().int(),
    completed: z.number().int(),
    acceptRate: z.number().nullable(),
    dismissRate: z.number().nullable(),
    completeRate: z.number().nullable(),
  })
  .strict();

export const notificationRateSchema = z
  .object({ kind: z.string(), sent: z.number().int(), opened: z.number().int(), cancelled: z.number().int(), openRate: z.number().nullable() })
  .strict();

export const adminOverviewQuerySchema = z.object({ days: z.coerce.number().int().min(1).max(90).default(30) }).strict();
export const adminOverviewSchema = z
  .object({
    generatedAt: iso,
    days: z.number().int(),
    endpoints: z.array(endpointHealthSchema),
    pendingCorrections: z.number().int(),
    users: z.object({ total: z.number().int(), active7d: z.number().int() }).strict(),
    recommendations: z.array(recommendationRateSchema),
    notifications: z.array(notificationRateSchema),
  })
  .strict();

/* ------------------------------------------------------ dish corrections -- */

export const CORRECTION_STATUSES = ['pending', 'accepted', 'rejected'] as const;
export const DIETS = ['veg', 'egg', 'nonveg'] as const;
export const MACRO_FIELDS = ['kcal', 'protein', 'carb', 'fat'] as const;

const dishEstimateSchema = z
  .object({
    name: z.string(),
    servingLabel: z.string(),
    kcalLow: z.number(),
    kcalHigh: z.number(),
    proteinLow: z.number(),
    proteinHigh: z.number(),
    carbLow: z.number(),
    carbHigh: z.number(),
    fatLow: z.number(),
    fatHigh: z.number(),
    confidence: z.string(),
  })
  .strict();

export const correctionReportSchema = z
  .object({
    id: z.string().uuid(),
    field: z.enum(['kcal', 'protein', 'carb', 'fat', 'diet', 'other']),
    valueLow: z.number().nullable(),
    valueHigh: z.number().nullable(),
    dietValue: z.enum(DIETS).nullable(),
    note: z.string().nullable(),
    status: z.enum(CORRECTION_STATUSES),
    createdAt: iso,
    reviewedAt: isoOrNull,
  })
  .strict();

/** One dish with its reports: the queue groups by slug, the unit a correction applies to. */
export const correctionGroupSchema = z
  .object({
    dishSlug: slugSchema,
    estimate: dishEstimateSchema.nullable(),
    dietOverride: z.enum(DIETS).nullable(),
    reports: z.array(correctionReportSchema),
  })
  .strict();

export const correctionQueueQuerySchema = z.object({ status: z.enum(CORRECTION_STATUSES).default('pending') }).strict();
export const correctionQueueSchema = z.object({ items: z.array(correctionGroupSchema) }).strict();

/**
 * Accept applies the report's own value (or the reviewer's adjusted one) to
 * the dish, by slug, for every future menu; reject changes nothing.
 * A free-text report ('other') can only be accepted as resolved.
 */
export const reviewCorrectionRequestSchema = z
  .object({
    decision: z.enum(['accept', 'reject']),
    valueLow: z.number().nonnegative().optional(),
    valueHigh: z.number().nonnegative().optional(),
    diet: z.enum(DIETS).optional(),
    note: z.string().trim().max(500).optional(),
  })
  .strict();

export const editDishEstimateRequestSchema = z
  .object({ field: z.enum(MACRO_FIELDS), low: z.number().nonnegative(), high: z.number().nonnegative(), reason: z.string().trim().min(3).max(500) })
  .strict();
export const dishDietRequestSchema = z.object({ diet: z.enum(DIETS).nullable(), reason: z.string().trim().min(3).max(500) }).strict();
export const adminDishParamsSchema = z.object({ slug: slugSchema }).strict();

/* ----------------------------------------------------------------- foods -- */

export const adminFoodQuerySchema = z.object({ q: z.string().trim().max(80).default('') }).strict();
export const adminFoodSummarySchema = z
  .object({ id: z.string().uuid(), slug: z.string(), name: z.string(), source: foodSourceSchema, isVerified: z.boolean(), adminEditedAt: isoOrNull })
  .strict();
export const adminFoodListSchema = z.object({ items: z.array(adminFoodSummarySchema) }).strict();
export const adminFoodSchema = adminFoodSummarySchema
  .extend({ sourceRef: z.string().nullable(), aliases: z.array(z.string()), nutrition: z.array(foodNutritionSchema) })
  .strict();
/** A FITOS food corrected by hand: the seed leaves it alone from then on (ADR-022 D5). */
export const editFoodRequestSchema = z
  .object({
    name: z.string().trim().min(1).max(160),
    aliases: z.array(z.string().trim().min(1).max(80)).max(30),
    isVerified: z.boolean(),
    nutrition: z.array(foodNutritionSchema).min(1).max(12),
    reason: z.string().trim().min(3).max(500),
  })
  .strict();

/* ------------------------------------------------------------- exercises -- */

export const adminExerciseQuerySchema = z.object({ q: z.string().trim().max(80).default(''), retired: z.coerce.boolean().default(false) }).strict();
export const adminExerciseSummarySchema = z
  .object({
    id: z.string().uuid(),
    slug: z.string(),
    name: z.string(),
    movementPattern: movementPatternSchema,
    equipment: z.array(equipmentSchema),
    retiredAt: isoOrNull,
    adminEditedAt: isoOrNull,
  })
  .strict();
export const adminExerciseListSchema = z.object({ items: z.array(adminExerciseSummarySchema) }).strict();
/** The seed's shape without alternatives (kept as they are). */
export const exerciseInputSchema = exerciseSeedSchema.omit({ alternatives: true });
export type ExerciseInput = z.infer<typeof exerciseInputSchema>;
export const adminExerciseSchema = exerciseInputSchema.extend({ id: z.string().uuid(), retiredAt: isoOrNull, adminEditedAt: isoOrNull }).strict();
export const editExerciseRequestSchema = exerciseInputSchema.omit({ slug: true });

/* ------------------------------------------------------------------ flags -- */

export const flagKeySchema = z.string().regex(/^[a-z][a-z0-9-]{1,48}$/, 'lower-case words joined by hyphens');

/**
 * Beta 3.3 (ADR-033): the app features the admin panel can switch off. Each
 * is ON unless its flag row says otherwise; the app hides what is off and the
 * server refuses it (403 `feature-off`). The app keeps the same list
 * (lib/core/config/app_features.dart), checked by a test.
 */
export const APP_FEATURES = {
  'share-programme': { name: 'Share your programme', description: 'Sharing a programme as a code, and using a shared one.' },
  'mess-ratings': { name: 'Mess ratings', description: 'Rating mess dishes up or down and seeing the results.' },
  streaks: { name: 'Streak and goal ring', description: 'The streak and the weekly goal ring on Home.' },
  'community-foods': { name: 'Community foods', description: "Sharing a food with everyone, reporting one, and other people's shared foods in search." },
  'food-requests': { name: 'Missing-food requests', description: 'Counting searches that find nothing, and "Ask us to add it".' },
  'weekly-report': { name: 'Weekly report', description: 'The premium weekly report on Progress.' },
  'progress-photos': { name: 'Progress photos', description: 'Taking and comparing progress photos (they never leave the phone).' },
  'food-guide': { name: 'AI food guide', description: '"What should I eat?" from what you have and the mess menu (premium FITOS AI).' },
  running: { name: 'Running', description: 'Recording runs with GPS, the run history, sharing and GPX (beta 4).' },
} as const;
export type AppFeature = keyof typeof APP_FEATURES;
export const APP_FEATURE_KEYS = Object.keys(APP_FEATURES) as AppFeature[];

/** A flag; an app feature carries its plain `name`, and `updatedAt` is null while it was never changed (on). */
export const featureFlagSchema = z
  .object({ key: z.string(), name: z.string().nullable(), enabled: z.boolean(), description: z.string(), updatedAt: isoOrNull })
  .strict();
export const featureFlagListSchema = z.object({ items: z.array(featureFlagSchema) }).strict();
export const putFlagRequestSchema = z.object({ enabled: z.boolean(), description: z.string().trim().max(300).optional() }).strict();
export const flagParamsSchema = z.object({ key: flagKeySchema }).strict();
/** Beta 3.5: "a new version is out" as a push, once per build. */
export const adminUpdatePushStatusSchema = z
  .object({
    latest: z.object({ version: z.string(), build: z.number().int(), label: z.string() }).strict().nullable(),
    /** Phones with a push token (notifications on). */
    devices: z.number().int().min(0),
    /** When everyone was told about this build; null when not yet. */
    sentAt: isoOrNull,
  })
  .strict();
export const adminUpdatePushResultSchema = z
  .object({
    build: z.number().int(),
    label: z.string(),
    devices: z.number().int(),
    sent: z.number().int(),
    removed: z.number().int(),
    /** Phones not reached, and why (FCM's error codes with their counts). */
    failed: z.number().int(),
    errors: z.record(z.string(), z.number().int()),
    /** The first failure's own words (an uninstalled phone is not one). */
    detail: z.string().nullable(),
  })
  .strict();
export type AdminUpdatePushStatus = z.infer<typeof adminUpdatePushStatusSchema>;
export type AdminUpdatePushResult = z.infer<typeof adminUpdatePushResultSchema>;

/** GET /meta/config (§10.1, public): what the app may switch on. The minimum app version is not served yet (BACKLOG E1). */
/**
 * The app's start-up config (public, §10.1). `minimumBuild` (Phase 19, E1): a
 * build below it shows "Update FITOS" and nothing else; 0 asks nothing.
 */
export const metaConfigSchema = z.object({ flags: z.record(z.string(), z.boolean()), minimumBuild: z.number().int().min(0) }).strict();

/* ---------------------------------------------------------- support view -- */

export const userLookupQuerySchema = z
  .object({ email: z.string().trim().email().optional(), id: z.string().uuid().optional() })
  .strict()
  .refine((q) => (q.email === undefined) !== (q.id === undefined), { message: 'give exactly one of email or id' });

/** Counts and dates only: no body photos, no food log contents, no weights (§20). */
export const userSupportSchema = z
  .object({
    userId: z.string().uuid(),
    email: z.string().nullable(),
    displayName: z.string().nullable(),
    createdAt: iso,
    timezone: z.string(),
    onboardingStage: z.string().nullable(),
    goal: z.string().nullable(),
    programme: z.object({ name: z.string(), splitType: z.string() }).strict().nullable(),
    counts: z
      .object({ sessions: z.number().int(), foodLogs: z.number().int(), weighIns: z.number().int(), checkIns: z.number().int(), aiCalls7d: z.number().int() })
      .strict(),
    lastActivity: z.object({ session: isoOrNull, foodLog: isoOrNull, weighIn: z.string().nullable(), checkIn: z.string().nullable() }).strict(),
    notifications: z.object({ enabled: z.boolean(), tone: z.string() }).strict(),
    /** Premium by approval (admins have it by role); the unlock-all test switch. */
    premium: z.boolean(),
    rewardsUnlocked: z.boolean(),
  })
  .strict();

/* --------------------------------------------------------- administrators -- */

/**
 * An account with the admin claim (ADR-022 D2 amendment). Granted and taken
 * away in the panel by another administrator; both audited.
 */
export const adminAccountSchema = z
  .object({
    firebaseUid: z.string(),
    email: z.string().nullable(),
    /** Our user row, once the account has used FITOS. */
    userId: z.string().uuid().nullable(),
    lastSignInAt: isoOrNull,
    /** The administrator asking. They cannot remove themselves. */
    isYou: z.boolean(),
  })
  .strict();
export const adminAccountListSchema = z.object({ items: z.array(adminAccountSchema) }).strict();
export const grantAdminRequestSchema = z.object({ email: z.string().trim().toLowerCase().email().max(254) }).strict();
export const adminAccountParamsSchema = z.object({ uid: z.string().regex(/^[A-Za-z0-9_-]{1,128}$/) }).strict();

/* ------------------------------------------------------------------ audit -- */

export const auditQuerySchema = z.object({ limit: z.coerce.number().int().min(1).max(200).default(50), before: iso.optional() }).strict();
export const auditEntrySchema = z
  .object({
    id: z.string().uuid(),
    actorUserId: z.string().uuid().nullable(),
    actorEmail: z.string().nullable(),
    action: z.string(),
    entity: z.string(),
    entityId: z.string().nullable(),
    metadata: z.record(z.string(), z.unknown()),
    occurredAt: iso,
  })
  .strict();
export const auditListSchema = z.object({ items: z.array(auditEntrySchema), next: isoOrNull }).strict();

export type AdminOverview = z.infer<typeof adminOverviewSchema>;
export type EndpointHealth = z.infer<typeof endpointHealthSchema>;
export type CorrectionGroup = z.infer<typeof correctionGroupSchema>;
export type CorrectionReport = z.infer<typeof correctionReportSchema>;
export type AdminFoodSummary = z.infer<typeof adminFoodSummarySchema>;
export type AdminFood = z.infer<typeof adminFoodSchema>;
export type AdminExerciseSummary = z.infer<typeof adminExerciseSummarySchema>;
export type AdminExercise = z.infer<typeof adminExerciseSchema>;
export type FeatureFlag = z.infer<typeof featureFlagSchema>;
export type UserSupport = z.infer<typeof userSupportSchema>;
export type AdminAccount = z.infer<typeof adminAccountSchema>;
export type AdminAccountList = z.infer<typeof adminAccountListSchema>;
export type AuditEntry = z.infer<typeof auditEntrySchema>;
export type AuditList = z.infer<typeof auditListSchema>;
