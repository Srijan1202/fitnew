/**
 * Route schemas for /auth/session. The wire shapes live in @fitos/contracts so
 * the Dart client is generated from the same source; this file only re-exports
 * them under the names the routes use.
 */
export {
  createSessionRequestSchema,
  createSessionResponseSchema,
  userProfileSchema,
  DEFAULT_LOCALE,
  DEFAULT_TIME_ZONE,
  type CreateSessionRequest,
  type CreateSessionResponse,
  type UserProfile,
} from '@fitos/contracts';
