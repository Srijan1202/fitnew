/**
 * Auth contracts — the wire shape of /auth/session.
 *
 * These are the single source of truth: the API validates against them, the
 * OpenAPI document is generated from them, and the Dart client is generated
 * from that document (§10, §29). Change the schema here and everything
 * downstream either follows or fails to compile — nothing drifts silently.
 */
import { z } from 'zod';

/**
 * IANA time zone, e.g. "Asia/Kolkata". "Today" is computed in this zone
 * (§9.1), so a bad value silently shifts every day boundary for that user.
 *
 * TRAP — do not "simplify" this to `Intl.supportedValuesOf('timeZone')`.
 * That list is CLDR-canonical, which keeps the *old* names: it contains
 * `Asia/Calcutta` and not `Asia/Kolkata`, `Europe/Kiev` and not `Europe/Kyiv`.
 * An allowlist built from it rejects the modern IANA name every Indian device
 * actually sends. Found by the first test written against it.
 *
 * Two checks instead:
 *  1. Shape — `Area/Location`, capitalised, no whitespace. Rejects bare
 *     abbreviations like `IST` (ambiguous: India, Israel, Ireland) and
 *     lowercase variants ICU would quietly accept.
 *  2. `Intl.DateTimeFormat` must accept it — proves the runtime can compute a
 *     day boundary with it. ICU honours aliases, so both spellings pass.
 *
 * The value is stored exactly as sent. ICU's `resolvedOptions().timeZone`
 * would canonicalise `Asia/Kolkata` to `Asia/Calcutta`; we do not want that in
 * the database or on a screen.
 */
const TIME_ZONE_SHAPE = /^(UTC|[A-Z][A-Za-z_]*(\/[A-Za-z0-9_+-]+)+)$/;

function runtimeAcceptsTimeZone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat('en', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

export const timeZoneSchema = z
  .string()
  .min(1)
  .max(64)
  .refine((tz) => TIME_ZONE_SHAPE.test(tz) && runtimeAcceptsTimeZone(tz), {
    message: 'must be an IANA time zone in Area/Location form, e.g. Asia/Kolkata',
  });

/** BCP 47 language tag, restricted to the shapes we actually expect. */
export const localeSchema = z
  .string()
  .regex(/^[a-z]{2,3}(-[A-Z]{2})?$/, 'must be a BCP 47 tag like en or en-IN');

export const DEFAULT_TIME_ZONE = 'Asia/Kolkata';
export const DEFAULT_LOCALE = 'en-IN';

/**
 * POST /auth/session request body.
 *
 * Deliberately small. Identity comes from the verified Firebase token, never
 * from the body (§11, §24); the body only carries device context the token
 * cannot. Everything is optional so a first-launch client can send `{}`.
 * `.strict()` rejects unknown keys (§24) — a client that starts sending
 * `userId` here is a bug we want to see, not ignore.
 */
export const createSessionRequestSchema = z
  .object({
    timezone: timeZoneSchema.optional(),
    locale: localeSchema.optional(),
  })
  .strict();

export type CreateSessionRequest = z.infer<typeof createSessionRequestSchema>;

/**
 * The app-facing user profile. This is what the backend owns; Firebase owns
 * the credentials and is never mirrored here (§11: no passwords ever reach
 * our database).
 */
export const userProfileSchema = z.object({
  id: z.string().uuid(),
  /**
   * Not `.email()`. Firebase validated this address at sign-up with its own
   * rules; re-validating with Zod's regex on the way out created a failure
   * mode where a perfectly valid Firebase account could not create a session
   * (found by a test using `a@b.c`, which Firebase accepts and Zod rejects).
   * Firebase is the authority — we store it and echo it.
   */
  email: z.string().nullable(),
  /**
   * Phase 6.6: the canonical display name — asked on the onboarding "about"
   * step (pre-filled from Firebase when Google provides one), stored on
   * `users.display_name`. Null until answered; the client greets without it.
   */
  displayName: z.string().nullable(),
  timezone: timeZoneSchema,
  locale: localeSchema,
  createdAt: z.string().datetime(),
  /**
   * Next onboarding step, or 'complete'. Carried on the session so the
   * client can route at cold start with one round trip: a returning user who
   * abandoned onboarding goes back into it, not to TODAY. Phase 2.
   */
  onboardingStage: z.string(),
});

export type UserProfile = z.infer<typeof userProfileSchema>;

/**
 * POST /auth/session response.
 *
 * `isNewUser` is true exactly once — on the request that created the row. The
 * client uses it to route into onboarding (Phase 2) rather than TODAY.
 */
export const createSessionResponseSchema = z.object({
  user: userProfileSchema,
  isNewUser: z.boolean(),
});

export type CreateSessionResponse = z.infer<typeof createSessionResponseSchema>;
