/**
 * Decorates the Fastify instance with the AI provider (Phase 6.6) and, from
 * Phase 14, the AI configuration: the kill switch, the per-purpose models and
 * the cost limits (§19.3, ADR-020). Routes and services read `app.ai` and
 * `app.aiConfig`; nothing else constructs a provider. Tests hand in a
 * FakeAiProvider; production builds Gemini from the environment and boots
 * without it — the status route says so.
 */
import fp from 'fastify-plugin';
import type { FastifyInstance } from 'fastify';

import type { Env } from '../lib/env.js';
import { NotConfiguredAiProvider } from '../modules/ai/fake-provider.js';
import { GeminiProvider } from '../modules/ai/gemini-provider.js';
import type { AiProvider } from '../modules/ai/provider.js';

export interface AiConfig {
  /** The kill switch: false turns every AI route off (503). */
  readonly enabled: boolean;
  /** Per-purpose models; null = the provider's own. */
  readonly models: { readonly parse: string | null; readonly explain: string | null };
  /** Calls per user per hour, by purpose. */
  readonly perHour: { readonly chat: number; readonly parse: number; readonly explain: number };
  /** Tokens a user may spend in 24 hours, across every purpose. */
  readonly dailyTokens: number;
  /** Phase 19 (ADR-027): premium users' limits are the ones above times this. */
  readonly premiumMultiplier: number;
}

declare module 'fastify' {
  interface FastifyInstance {
    ai: AiProvider;
    aiConfig: AiConfig;
  }
}

export interface AiPluginOptions {
  readonly provider?: AiProvider;
  readonly env?: Env;
}

/** Builds the production provider from the environment, or the honest "none". */
export function providerFromEnv(env: Env): AiProvider {
  if (env.GEMINI_API_KEY === undefined) return new NotConfiguredAiProvider();
  return new GeminiProvider({
    apiKey: env.GEMINI_API_KEY,
    model: env.GEMINI_MODEL,
    timeoutMs: env.AI_TIMEOUT_MS,
    maxOutputTokens: env.AI_MAX_OUTPUT_TOKENS,
  });
}

export function aiConfigFromEnv(env: Env | undefined): AiConfig {
  return {
    enabled: env?.AI_ENABLED ?? true,
    models: { parse: env?.MODEL_FOOD_PARSE ?? null, explain: env?.MODEL_EXPLAIN ?? null },
    perHour: { chat: env?.AI_CHAT_PER_HOUR ?? 60, parse: env?.AI_PARSE_PER_HOUR ?? 20, explain: env?.AI_EXPLAIN_PER_HOUR ?? 20 },
    dailyTokens: env?.AI_DAILY_TOKEN_BUDGET ?? 200_000,
    premiumMultiplier: env?.AI_PREMIUM_LIMIT_MULTIPLIER ?? 2,
  };
}

export default fp(
  async function aiPlugin(app: FastifyInstance, opts: AiPluginOptions) {
    const provider = opts.provider ?? (opts.env !== undefined ? providerFromEnv(opts.env) : new NotConfiguredAiProvider());
    const config = aiConfigFromEnv(opts.env);
    app.decorate('ai', provider);
    app.decorate('aiConfig', config);
    // The key is never logged; the model and provider name are not secrets.
    app.log.info(
      { provider: provider.name, model: provider.model || null, enabled: config.enabled },
      !config.enabled ? 'ai: switched off (AI_ENABLED=false)' : provider.name === 'none' ? 'ai: not configured (GEMINI_API_KEY absent)' : 'ai: configured',
    );
  },
  { name: 'ai' },
);
