/**
 * Phase 6.6 Gate 3 — the AI foundation without a network: the Gemini
 * provider against a scripted fetch (request shape, the key only in a
 * header, every failure kind), the service's error mapping, the
 * environment, the plugin's provider choice, and the status route.
 */
import { describe, expect, it } from 'vitest';

import { loadEnv } from '../../lib/env.js';
import { AppError } from '../../lib/errors.js';
import { providerFromEnv } from '../../plugins/ai.js';
import { buildStubApp, testEnv } from '../../test/build-test-app.js';
import { FakeAiProvider, NotConfiguredAiProvider } from './fake-provider.js';
import { GeminiProvider } from './gemini-provider.js';
import { AiProviderError, type AiRequest } from './provider.js';
import { AI_EXCLUDES, AiService } from './service.js';

const KEY = 'AIza-test-key-never-logged';

/** A fetch that records the request and answers as scripted. */
function scriptedFetch(status: number, body: unknown, calls: { url: string; init: RequestInit }[]) {
  return (async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return new Response(typeof body === 'string' ? body : JSON.stringify(body), {
      status,
      headers: { 'content-type': 'application/json' },
    });
  }) as typeof fetch;
}

function gemini(status: number, body: unknown, calls: { url: string; init: RequestInit }[] = []) {
  return new GeminiProvider({
    apiKey: KEY,
    model: 'gemini-2.5-flash',
    timeoutMs: 1000,
    maxOutputTokens: 256,
    fetchImpl: scriptedFetch(status, body, calls),
  });
}

const request: AiRequest = {
  system: 'You are FITOS.',
  messages: [
    { role: 'user', content: 'What should I train today?' },
    { role: 'assistant', content: 'Let me check.' },
    { role: 'user', content: 'Go on.' },
  ],
  tools: [{ name: 'get_today', description: "Today's session", parameters: { type: 'object', properties: {} } }],
};

describe('GeminiProvider', () => {
  it('sends the key in a header only, the system instruction, roles mapped, tools declared; parses text + usage', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const p = gemini(
      200,
      {
        candidates: [{ content: { parts: [{ text: 'Pull day. ' }, { text: 'Four movements.' }] }, finishReason: 'STOP' }],
        usageMetadata: { promptTokenCount: 120, candidatesTokenCount: 18 },
      },
      calls,
    );
    const r = await p.generate(request);
    expect(r).toEqual({ text: 'Pull day. Four movements.', toolCalls: [], finishReason: 'stop', usage: { inputTokens: 120, outputTokens: 18 } });
    expect(calls).toHaveLength(1);
    const { url, init } = calls[0]!;
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent');
    expect(url).not.toContain(KEY);
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe(KEY);
    const body = JSON.parse(init.body as string) as Record<string, unknown>;
    expect(JSON.stringify(body)).not.toContain(KEY);
    expect(body['systemInstruction']).toEqual({ parts: [{ text: 'You are FITOS.' }] });
    expect(body['contents']).toEqual([
      { role: 'user', parts: [{ text: 'What should I train today?' }] },
      { role: 'model', parts: [{ text: 'Let me check.' }] },
      { role: 'user', parts: [{ text: 'Go on.' }] },
    ]);
    expect(body['tools']).toEqual([{ functionDeclarations: [{ name: 'get_today', description: "Today's session", parameters: { type: 'object', properties: {} } }] }]);
    expect(body['generationConfig']).toEqual({ maxOutputTokens: 256, temperature: 0.3 });
  });

  it('parses tool calls, feeds tool results back as functionResponse parts, honours jsonMode', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const p = gemini(200, { candidates: [{ content: { parts: [{ functionCall: { name: 'get_today', args: { dayOfWeek: 2 } } }] } }] }, calls);
    const r = await p.generate({ ...request, toolResults: [{ name: 'get_today', result: { sessionName: 'Pull' } }], jsonMode: true, maxOutputTokens: 64 });
    expect(r.finishReason).toBe('tool');
    expect(r.toolCalls).toEqual([{ name: 'get_today', args: { dayOfWeek: 2 } }]);
    const body = JSON.parse(calls[0]!.init.body as string) as { contents: unknown[]; generationConfig: Record<string, unknown> };
    expect(body.contents.at(-1)).toEqual({ role: 'user', parts: [{ functionResponse: { name: 'get_today', response: { sessionName: 'Pull' } } }] });
    expect(body.generationConfig).toEqual({ maxOutputTokens: 64, temperature: 0.3, responseMimeType: 'application/json' });
  });

  it('carries the call id and thought signature back on the next turn (Gemini 3 requirement)', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const p = gemini(200, { candidates: [{ content: { parts: [{ functionCall: { name: 'get_today', args: {}, id: 'call_1' }, thoughtSignature: 'sig-abc' }] } }] }, calls);
    const r = await p.generate(request);
    expect(r.toolCalls).toEqual([{ name: 'get_today', args: {}, id: 'call_1', signature: 'sig-abc' }]);
    await p.generate({ ...request, messages: [...request.messages, { role: 'assistant', content: '', toolCalls: r.toolCalls }], toolResults: [{ name: 'get_today', id: 'call_1', result: { ok: true } }] });
    const body = JSON.parse(calls[1]!.init.body as string) as { contents: unknown[] };
    expect(body.contents.at(-2)).toEqual({ role: 'model', parts: [{ functionCall: { name: 'get_today', args: {}, id: 'call_1' }, thoughtSignature: 'sig-abc' }] });
    expect(body.contents.at(-1)).toEqual({ role: 'user', parts: [{ functionResponse: { name: 'get_today', response: { ok: true }, id: 'call_1' } }] });
  });

  it.each([
    [429, {}, 'rate_limited'],
    [401, {}, 'not_configured'],
    [403, {}, 'not_configured'],
    [500, {}, 'unavailable'],
    [503, {}, 'unavailable'],
    [200, 'not json {', 'malformed'],
    [200, { candidates: [] }, 'empty'],
    [200, { candidates: [{ content: { parts: [] }, finishReason: 'STOP' }] }, 'empty'],
    [200, { candidates: [{ content: { parts: [] }, finishReason: 'SAFETY' }] }, 'blocked'],
    [200, { promptFeedback: { blockReason: 'SAFETY' } }, 'blocked'],
  ])('HTTP %s with %j → %s, and the key is not in the message', async (status, body, kind) => {
    const p = gemini(status as number, body);
    const err = await p.generate(request).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiProviderError);
    expect((err as AiProviderError).kind).toBe(kind);
    expect((err as AiProviderError).message).not.toContain(KEY);
  });

  it('a hung upstream → timeout after AI_TIMEOUT_MS', async () => {
    const p = new GeminiProvider({
      apiKey: KEY,
      model: 'gemini-2.5-flash',
      timeoutMs: 50,
      maxOutputTokens: 256,
      fetchImpl: ((_url: unknown, init?: RequestInit) =>
        new Promise<Response>((_, reject) => {
          init?.signal?.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' })));
        })) as typeof fetch,
    });
    const err = await p.generate(request).catch((e: unknown) => e);
    expect((err as AiProviderError).kind).toBe('timeout');
  });

  it('a network failure → unavailable', async () => {
    const p = new GeminiProvider({
      apiKey: KEY,
      model: 'gemini-2.5-flash',
      timeoutMs: 1000,
      maxOutputTokens: 256,
      fetchImpl: (async () => {
        throw new TypeError('fetch failed');
      }) as typeof fetch,
    });
    const err = await p.generate(request).catch((e: unknown) => e);
    expect((err as AiProviderError).kind).toBe('unavailable');
  });

  it('refuses to be built without a key or a model', () => {
    expect(() => new GeminiProvider({ apiKey: '', model: 'm', timeoutMs: 1, maxOutputTokens: 64 })).toThrow(/API key/);
    expect(() => new GeminiProvider({ apiKey: 'k', model: ' ', timeoutMs: 1, maxOutputTokens: 64 })).toThrow(/model/);
  });

  it('MAX_TOKENS → length; an unknown finish reason → other', () => {
    expect(GeminiProvider.fromBody({ candidates: [{ content: { parts: [{ text: 'x' }] }, finishReason: 'MAX_TOKENS' }] }).finishReason).toBe('length');
    expect(GeminiProvider.fromBody({ candidates: [{ content: { parts: [{ text: 'x' }] }, finishReason: 'RECITATION' }] }).finishReason).toBe('other');
  });
});

describe('AiService', () => {
  it('status: configured provider vs none; the excludes are stated', () => {
    expect(new AiService(new FakeAiProvider()).status()).toEqual({ configured: true, provider: 'fake', model: 'fake-1', excludes: AI_EXCLUDES });
    expect(new AiService(new NotConfiguredAiProvider()).status()).toEqual({ configured: false, provider: 'none', model: null, excludes: ['health-connect', 'food-log'] });
  });

  it.each([
    ['not_configured', 'UPSTREAM_UNAVAILABLE', 503, /not set up/],
    ['rate_limited', 'RATE_LIMITED', 429, /busy/],
    ['timeout', 'UPSTREAM_UNAVAILABLE', 503, /too long/],
    ['unavailable', 'UPSTREAM_UNAVAILABLE', 503, /unavailable/],
    ['malformed', 'UPSTREAM_UNAVAILABLE', 503, /unavailable/],
    ['empty', 'UPSTREAM_UNAVAILABLE', 503, /unavailable/],
    ['blocked', 'VALIDATION_FAILED', 422, /cannot answer/],
  ] as const)('%s → %s %s', (kind, code, status, message) => {
    const err = AiService.toAppError(new AiProviderError(kind, 'upstream said: secret detail sk-123', 500));
    expect(err).toBeInstanceOf(AppError);
    expect(err.code).toBe(code);
    expect(err.statusCode).toBe(status);
    expect(err.message).toMatch(message);
    expect(err.message).not.toContain('sk-123');
  });

  it('a non-provider error is not swallowed', () => {
    expect(() => AiService.toAppError(new Error('bug'))).toThrow('bug');
  });

  it('the not-configured provider throws not_configured', async () => {
    await expect(new NotConfiguredAiProvider().generate()).rejects.toMatchObject({ kind: 'not_configured' });
  });
});

describe('configuration', () => {
  const base = { DATABASE_URL: 'postgres://u:p@localhost:5432/d', FIREBASE_PROJECT_ID: 'p' };

  it('boots without a key: model default gemini-2.5-flash, sane limits', () => {
    const env = loadEnv({ ...base });
    expect(env.GEMINI_API_KEY).toBeUndefined();
    expect(env.GEMINI_MODEL).toBe('gemini-2.5-flash');
    expect(env.AI_TIMEOUT_MS).toBe(25_000);
    expect(env.AI_MAX_OUTPUT_TOKENS).toBe(2048);
    expect(providerFromEnv(env).name).toBe('none');
  });

  it('with a key: a Gemini provider on the configured model; the key is not on the provider', () => {
    const env = loadEnv({ ...base, GEMINI_API_KEY: KEY, GEMINI_MODEL: 'gemini-2.5-flash', AI_TIMEOUT_MS: '10000' });
    const p = providerFromEnv(env);
    expect(p.name).toBe('gemini');
    expect(p.model).toBe('gemini-2.5-flash');
    expect(JSON.stringify({ name: p.name, model: p.model })).not.toContain(KEY);
  });

  it('an empty key (compose passthrough) is absent; an absurd timeout and a tiny token budget are rejected', () => {
    const env = loadEnv({ ...base, GEMINI_API_KEY: '' });
    expect(env.GEMINI_API_KEY).toBeUndefined();
    expect(providerFromEnv(env).name).toBe('none');
    expect(() => loadEnv({ ...base, AI_TIMEOUT_MS: '10' })).toThrow(/AI_TIMEOUT_MS/);
    expect(() => loadEnv({ ...base, AI_MAX_OUTPUT_TOKENS: '1' })).toThrow(/AI_MAX_OUTPUT_TOKENS/);
  });
});

describe('GET /v1/ai/status', () => {
  it('is default-deny', async () => {
    const { app } = await buildStubApp();
    const r = await app.inject({ method: 'GET', url: '/v1/ai/status', headers: { 'x-forwarded-for': '203.0.113.7' } });
    expect(r.statusCode).toBe(401);
    await app.close();
  });

  it('answers not configured without a key (the default test app), and configured with a fake', async () => {
    const { buildApp } = await import('../../app.js');
    const { FakeTokenVerifier } = await import('../../test/fake-token-verifier.js');
    const { stubDatabase } = await import('../../test/build-test-app.js');
    for (const [provider, expected] of [
      [undefined, { configured: false, provider: 'none', model: null }],
      [new FakeAiProvider(), { configured: true, provider: 'fake', model: 'fake-1' }],
    ] as const) {
      const verifier = new FakeTokenVerifier();
      verifier.accept('t', { uid: 'u1' });
      const app = await buildApp(testEnv(), {
        database: stubDatabase(),
        tokenVerifier: verifier,
        resolveUserId: async () => 'user-1',
        ...(provider !== undefined ? { aiProvider: provider } : {}),
      });
      const r = await app.inject({ method: 'GET', url: '/v1/ai/status', headers: { authorization: 'Bearer t', 'x-forwarded-for': '203.0.113.8' } });
      expect(r.statusCode).toBe(200);
      expect(r.json()).toMatchObject({ ...expected, excludes: ['health-connect', 'food-log'] });
      await app.close();
    }
  });
});
