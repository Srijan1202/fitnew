/**
 * Decorates the Fastify instance with the AI provider (Phase 6.6). Routes
 * and services read `app.ai`; nothing else constructs a provider. Tests
 * hand in a FakeAiProvider; production builds Gemini from the environment
 * and boots without it — the status route says so.
 */
import fp from 'fastify-plugin';
import type { FastifyInstance } from 'fastify';

import type { Env } from '../lib/env.js';
import { NotConfiguredAiProvider } from '../modules/ai/fake-provider.js';
import { GeminiProvider } from '../modules/ai/gemini-provider.js';
import type { AiProvider } from '../modules/ai/provider.js';

declare module 'fastify' {
  interface FastifyInstance {
    ai: AiProvider;
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

export default fp(
  async function aiPlugin(app: FastifyInstance, opts: AiPluginOptions) {
    const provider = opts.provider ?? (opts.env !== undefined ? providerFromEnv(opts.env) : new NotConfiguredAiProvider());
    app.decorate('ai', provider);
    // The key is never logged; the model and provider name are not secrets.
    app.log.info({ provider: provider.name, model: provider.model || null }, provider.name === 'none' ? 'ai: not configured (GEMINI_API_KEY absent)' : 'ai: configured');
  },
  { name: 'ai' },
);
