/**
 * Environment parsing. Validated once at boot with Zod so a misconfigured
 * deploy fails immediately and loudly rather than at the first request.
 */
import { z } from 'zod';

/** The development fallback for CONSENT_IP_SALT. Refused in hosted environments. */
export const DEV_CONSENT_IP_SALT = 'dev-only-salt-not-secret';

/**
 * Phase 6.7 — which proxies Fastify may believe about the client address.
 *
 * `true` trusts the whole X-Forwarded-For chain, whose first entry the client
 * writes itself; Google's front end APPENDS to a client-supplied header rather
 * than replacing it. Behind Cloud Run that let a caller pick its own
 * rate-limit key. Hosted environments therefore set a hop count (or an address
 * list); unset keeps the Phase 6.6 behaviour for the LAN compose, which has no
 * proxy in front at all.
 */
export type TrustProxy = boolean | number | string[];

const TRUST_PROXY_KEYWORDS = new Set(['loopback', 'linklocal', 'uniquelocal']);

function trustProxyEntryValid(entry: string): boolean {
  return TRUST_PROXY_KEYWORDS.has(entry) || /^[0-9a-fA-F:.]+(\/\d{1,3})?$/.test(entry);
}

export function parseTrustProxy(raw: string | undefined): TrustProxy {
  if (raw === undefined) return true;
  const value = raw.trim();
  if (value === 'true') return true;
  if (value === 'false') return false;
  if (/^\d+$/.test(value)) return Number(value);
  return value.split(',').map((entry) => entry.trim());
}

function trustProxyValid(raw: string): boolean {
  const value = raw.trim();
  if (value === 'true' || value === 'false' || /^\d+$/.test(value)) return true;
  const entries = value.split(',').map((entry) => entry.trim());
  return entries.length > 0 && entries.every(trustProxyEntryValid);
}

/** Environments reachable from the internet (Cloud Run): stricter boot rules. */
export function isHostedEnvironment(nodeEnv: string): boolean {
  return nodeEnv === 'production' || nodeEnv === 'staging';
}

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
  CONSENT_IP_SALT: z.string().min(8).default(DEV_CONSENT_IP_SALT),

  // Phase 6.7 — see parseTrustProxy. `true` | `false` | a hop count | a
  // comma-separated list of addresses / CIDRs. Required when hosted.
  TRUST_PROXY: z
    .string()
    .refine(trustProxyValid, 'TRUST_PROXY must be true, false, a hop count, or a comma-separated list of addresses')
    .optional(),

  // Phase 6.6 — FITOS AI through the backend (owner B2). The key is optional
  // so every environment boots; without it the AI routes answer 503
  // "AI is not set up on this server" and nothing else changes. Never
  // logged, never echoed, never sent to a client.
  // Compose passes '' when docker/.env has no key: treat empty as absent.
  GEMINI_API_KEY: z.preprocess((v) => (v === '' ? undefined : v), z.string().min(1).optional()),
  GEMINI_MODEL: z.string().min(1).default('gemini-3.6-flash'),
  AI_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(25_000),
  // Gemini 3 spends part of this budget thinking; 2048 leaves room to answer.
  AI_MAX_OUTPUT_TOKENS: z.coerce.number().int().min(64).max(8192).default(2048),

  // Phase 9 - the in-process MessIT mirror timer, in hours (0 = off). Unset:
  // 12 in development, off elsewhere (hosted, Cloud Scheduler is the trigger:
  // deferred while GCP work is paused). The job itself is dist/jobs/mirror-mess.js.
  MESS_MIRROR_INTERVAL_HOURS: z.coerce.number().min(0).max(168).optional(),
}).superRefine((env, ctx) => {
  // Phase 6.7 — a hosted server must not boot on development fallbacks.
  if (!isHostedEnvironment(env.NODE_ENV)) return;
  if (env.CONSENT_IP_SALT === DEV_CONSENT_IP_SALT || env.CONSENT_IP_SALT.length < 16) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['CONSENT_IP_SALT'],
      message: `a real secret of at least 16 characters is required when NODE_ENV=${env.NODE_ENV}`,
    });
  }
  if (env.TRUST_PROXY === undefined) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['TRUST_PROXY'],
      message: `required when NODE_ENV=${env.NODE_ENV} (the proxy hop count in front of the API)`,
    });
  }
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
