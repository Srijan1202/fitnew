/**
 * Environment parsing. Validated once at boot with Zod so a misconfigured
 * deploy fails immediately and loudly rather than at the first request.
 */
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  DATABASE_URL: z.string().url('DATABASE_URL must be a valid postgres connection string'),

  // Phase 1 — Firebase Admin. The project id is required; credentials are
  // optional because Cloud Run supplies them through Application Default
  // Credentials with no file at all. Locally, point this at the key in
  // apps/api/.secrets/ (§24: never in the repo, never in the Flutter binary).
  FIREBASE_PROJECT_ID: z.string().min(1, 'FIREBASE_PROJECT_ID is required'),
  GOOGLE_APPLICATION_CREDENTIALS: z.string().min(1).optional(),

  // Phase 2 — salt for the consent-record IP hash (§23). Any value works for
  // development; production sets a real secret via Secret Manager so hashes
  // cannot be brute-forced against the IPv4 space.
  CONSENT_IP_SALT: z.string().min(8).default('dev-only-salt-not-secret'),

  // Phase 6.6 — FITOS AI through the backend (owner B2). The key is optional
  // so every environment boots; without it the AI routes answer 503
  // "AI is not set up on this server" and nothing else changes. Never
  // logged, never echoed, never sent to a client.
  // Compose passes '' when docker/.env has no key: treat empty as absent.
  GEMINI_API_KEY: z.preprocess((v) => (v === '' ? undefined : v), z.string().min(1).optional()),
  GEMINI_MODEL: z.string().min(1).default('gemini-2.5-flash'),
  AI_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(25_000),
  AI_MAX_OUTPUT_TOKENS: z.coerce.number().int().min(64).max(8192).default(1024),
});

export type Env = z.infer<typeof envSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = envSchema.safeParse(source);
  if (!parsed.success) {
    const detail = parsed.error.issues
      .map((issue) => `  ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${detail}`);
  }
  return parsed.data;
}
