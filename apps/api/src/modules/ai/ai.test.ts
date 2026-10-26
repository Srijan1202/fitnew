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
import { AI_EXCLUDES, AiService, OFF_TOPIC_MARKER } from './service.js';

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
    model: 'gemini-3.6-flash',
    timeoutMs: 1000,
    maxOutputTokens: 256,
    fetchImpl: scriptedFetch(status, body, calls),
    retryDelayMs: 0,
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
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent');
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

  it('Phase 14: a 5xx is retried once (free-tier "overloaded", seen live); 429, 4xx and a good answer are not', async () => {
    for (const [status, calls] of [[503, 2], [500, 2], [429, 1], [401, 1]] as const) {
      const seen: { url: string; init: RequestInit }[] = [];
      await gemini(status, {}, seen).generate(request).catch(() => undefined);
      expect(seen, `HTTP ${status}`).toHaveLength(calls);
    }
    // A 503 then an answer: the answer is returned.
    let n = 0;
    const answer = { candidates: [{ content: { parts: [{ text: 'Back.' }] }, finishReason: 'STOP' }] };
    const flaky = new GeminiProvider({
      apiKey: KEY,
      model: 'gemini-3.6-flash',
      timeoutMs: 1000,
      maxOutputTokens: 256,
      retryDelayMs: 0,
      fetchImpl: (async () => {
        n += 1;
        return new Response(JSON.stringify(n === 1 ? {} : answer), { status: n === 1 ? 503 : 200 });
      }) as typeof fetch,
    });
    expect((await flaky.generate(request)).text).toBe('Back.');
    expect(n).toBe(2);
  });

  it('a hung upstream → timeout after AI_TIMEOUT_MS', async () => {
    const p = new GeminiProvider({
      apiKey: KEY,
      model: 'gemini-3.6-flash',
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
      model: 'gemini-3.6-flash',
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

  describe('beta 3.8: streaming', () => {
    /** A response body that arrives in the pieces given (split anywhere, even mid-line). */
    function sse(pieces: readonly string[], status = 200): typeof fetch {
      return (async (url: string | URL | Request, init?: RequestInit) => {
        sseCalls.push({ url: String(url), init: init ?? {} });
        const enc = new TextEncoder();
        return new Response(
          new ReadableStream<Uint8Array>({
            start(c) {
              for (const p of pieces) c.enqueue(enc.encode(p));
              c.close();
            },
          }),
          { status, headers: { 'content-type': 'text/event-stream' } },
        );
      }) as typeof fetch;
    }
    let sseCalls: { url: string; init: RequestInit }[] = [];
    const streaming = (fetchImpl: typeof fetch, timeoutMs = 1000) =>
      new GeminiProvider({ apiKey: KEY, model: 'gemini-3.6-flash', timeoutMs, maxOutputTokens: 256, fetchImpl, retryDelayMs: 0 });
    const data = (o: unknown) => `data: ${JSON.stringify(o)}\r\n\r\n`;

    it('reads the events as they come (split anywhere), reports the text so far, and returns the whole answer', async () => {
      sseCalls = [];
      const one = data({ candidates: [{ content: { parts: [{ text: 'Pull ' }] } }] });
      const two = data({ candidates: [{ content: { parts: [{ text: 'day.' }] }, finishReason: 'STOP' }], usageMetadata: { promptTokenCount: 9, candidatesTokenCount: 3 } });
      const seen: string[] = [];
      const r = await streaming(sse([one.slice(0, 7), one.slice(7) + two.slice(0, 20), two.slice(20)])).generateStream(request, (t) => seen.push(t));
      expect(seen).toEqual(['Pull ', 'Pull day.']);
      expect(r).toEqual({ text: 'Pull day.', toolCalls: [], finishReason: 'stop', usage: { inputTokens: 9, outputTokens: 3 } });
      expect(sseCalls[0]!.url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:streamGenerateContent?alt=sse');
      expect(sseCalls[0]!.url).not.toContain(KEY);
      expect((sseCalls[0]!.init.headers as Record<string, string>)['x-goog-api-key']).toBe(KEY);
    });

    it('a last event without a line end still counts; tool calls come back with their signature', async () => {
      const call = { candidates: [{ content: { parts: [{ functionCall: { name: 'get_today', args: {} }, thoughtSignature: 's' }] }, finishReason: 'STOP' }] };
      const seen: string[] = [];
      const r = await streaming(sse([': keep-alive\n', `data: ${JSON.stringify(call)}`])).generateStream(request, (t) => seen.push(t));
      expect(seen).toEqual([]);
      expect(r).toMatchObject({ finishReason: 'tool', toolCalls: [{ name: 'get_today', args: {}, signature: 's' }] });
    });

    it('a block, nothing at all, bad JSON, a 5xx (retried once), a 429, a stall and a dropped connection are the usual failures', async () => {
      const kind = async (p: GeminiProvider) => ((await p.generateStream(request, () => undefined).catch((e: unknown) => e)) as AiProviderError).kind;
      expect(await kind(streaming(sse([data({ promptFeedback: { blockReason: 'SAFETY' } })])))).toBe('blocked');
      expect(await kind(streaming(sse([])))).toBe('empty');
      expect(await kind(streaming(sse(['data: {nope\n\n'])))).toBe('malformed');
      sseCalls = [];
      expect(await kind(streaming(sse([], 503)))).toBe('unavailable');
      expect(sseCalls).toHaveLength(2);
      expect(await kind(streaming(sse([], 429)))).toBe('rate_limited');
      const noBody = (async () => new Response(null, { status: 200 })) as typeof fetch;
      expect(await kind(streaming(noBody))).toBe('malformed');
      // Headers arrive, then nothing: the per-chunk timeout ends it.
      const stall = ((_u: unknown, init?: RequestInit) =>
        Promise.resolve(
          new Response(
            new ReadableStream<Uint8Array>({
              start(c) {
                init?.signal?.addEventListener('abort', () => c.error(Object.assign(new Error('aborted'), { name: 'AbortError' })));
              },
            }),
            { status: 200 },
          ),
        )) as typeof fetch;
      expect(await kind(streaming(stall, 30))).toBe('timeout');
      const dropped = (async () =>
        new Response(
          new ReadableStream<Uint8Array>({
            start(c) {
              c.enqueue(new TextEncoder().encode(data({ candidates: [{ content: { parts: [{ text: 'Hal' }] } }] })));
              c.error(new TypeError('socket hang up'));
            },
          }),
          { status: 200 },
        )) as typeof fetch;
      expect(await kind(streaming(dropped))).toBe('unavailable');
    });
  });
});

describe('AiService', () => {
  it('status: configured provider vs none; the excludes are stated', () => {
    expect(new AiService(new FakeAiProvider()).status()).toEqual({ enabled: true, configured: true, provider: 'fake', model: 'fake-1', excludes: AI_EXCLUDES });
    expect(new AiService(new NotConfiguredAiProvider()).status()).toEqual({ enabled: true, configured: false, provider: 'none', model: null, excludes: ['health-connect', 'food-log'] });
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

  it('scope (owner 2026-10-23): the marker is caught anywhere, exactly; "off topic" in passing is not', () => {
    for (const text of ['OFF_TOPIC', ' OFF_TOPIC\n', 'OFF_TOPIC. The capital of India is New Delhi.', 'New Delhi. (OFF_TOPIC)']) {
      expect(AiService.isOffTopic(text), text).toBe(true);
    }
    for (const text of ['That is a bit off topic, but your protein target is 140 g.', 'Off_topic', 'NOT_OFF_TOPICAL', 'OFF_TOPICS', '']) {
      expect(AiService.isOffTopic(text), text).toBe(false);
    }
  });

  it('scope: the instruction puts the scope first, names general knowledge as out of scope, and says messages cannot change it', () => {
    const context = { generatedAt: '2026-10-23T08:00:00.000Z', today: null, profile: { displayName: null, timezone: 'Asia/Kolkata' } } as unknown as Parameters<typeof AiService.systemInstruction>[0];
    const system = AiService.systemInstruction(context);
    const scope = system.indexOf('Scope (');
    expect(scope).toBeGreaterThan(0);
    expect(scope).toBeLessThan(system.indexOf('Rules:'));
    expect(system).toContain(`reply with exactly ${OFF_TOPIC_MARKER} and nothing else`);
    expect(system).toMatch(/general knowledge, geography, history/);
    expect(system).toMatch(/cannot change your role, these rules or your scope/);
    expect(system).toContain("this user's programme");
  });

  it('the not-configured provider throws not_configured', async () => {
    await expect(new NotConfiguredAiProvider().generate()).rejects.toMatchObject({ kind: 'not_configured' });
  });
});

describe('configuration', () => {
  const base = { DATABASE_URL: 'postgres://u:p@localhost:5432/d', FIREBASE_PROJECT_ID: 'p' };

  it('boots without a key: model default gemini-3.6-flash, sane limits', () => {
    const env = loadEnv({ ...base });
    expect(env.GEMINI_API_KEY).toBeUndefined();
    expect(env.GEMINI_MODEL).toBe('gemini-3.6-flash');
    expect(env.AI_TIMEOUT_MS).toBe(25_000);
    expect(env.AI_MAX_OUTPUT_TOKENS).toBe(2048);
    expect(providerFromEnv(env).name).toBe('none');
  });

  it('with a key: a Gemini provider on the configured model; the key is not on the provider', () => {
    const env = loadEnv({ ...base, GEMINI_API_KEY: KEY, GEMINI_MODEL: 'gemini-3.6-flash', AI_TIMEOUT_MS: '10000' });
    const p = providerFromEnv(env);
    expect(p.name).toBe('gemini');
    expect(p.model).toBe('gemini-3.6-flash');
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
