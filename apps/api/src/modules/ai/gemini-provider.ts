/**
 * Gemini behind the AiProvider seam, through the REST API with Node's
 * fetch — no SDK, so the surface is exactly what we use. The key travels
 * in the `x-goog-api-key` header (never the URL, so it cannot land in a
 * proxy log), is read once from the environment and is never echoed in an
 * error, a log line or a response. Every call has a hard timeout.
 *
 * Owner B2: GEMINI_API_KEY lives in apps/api/.env only.
 */
import {
  AiProviderError,
  type AiProvider,
  type AiRequest,
  type AiResponse,
  type AiTextSink,
  type AiToolCall,
} from './provider.js';

export interface GeminiProviderOptions {
  readonly apiKey: string;
  readonly model: string;
  readonly timeoutMs: number;
  readonly maxOutputTokens: number;
  /** Overridable for tests; defaults to the public endpoint. */
  readonly baseUrl?: string;
  readonly fetchImpl?: typeof fetch;
  /** The pause before the one retry on a 5xx (tests pass 0). */
  readonly retryDelayMs?: number;
}

/* --------------------------------------------------------- wire shapes -- */

interface GeminiPart {
  readonly text?: string;
  readonly functionCall?: { readonly name: string; readonly args?: Record<string, unknown>; readonly id?: string };
  readonly functionResponse?: { readonly name: string; readonly response: Record<string, unknown>; readonly id?: string };
  /** Gemini 3: must be echoed back with the function call on the next turn. */
  readonly thoughtSignature?: string;
}

interface GeminiContent {
  readonly role: 'user' | 'model';
  readonly parts: readonly GeminiPart[];
}

interface GeminiCandidate {
  readonly content?: { readonly parts?: readonly GeminiPart[] };
  readonly finishReason?: string;
}

interface GeminiResponseBody {
  readonly candidates?: readonly GeminiCandidate[];
  readonly promptFeedback?: { readonly blockReason?: string };
  readonly usageMetadata?: { readonly promptTokenCount?: number; readonly candidatesTokenCount?: number };
}

export class GeminiProvider implements AiProvider {
  readonly name = 'gemini';
  readonly model: string;
  private readonly apiKey: string;
  private readonly timeoutMs: number;
  private readonly maxOutputTokens: number;
  private readonly baseUrl: string;
  private readonly fetchImpl: typeof fetch;
  private readonly retryDelayMs: number;

  constructor(opts: GeminiProviderOptions) {
    if (opts.apiKey.trim().length === 0) throw new Error('GeminiProvider needs an API key');
    if (opts.model.trim().length === 0) throw new Error('GeminiProvider needs a model');
    this.apiKey = opts.apiKey;
    this.model = opts.model;
    this.timeoutMs = opts.timeoutMs;
    this.maxOutputTokens = opts.maxOutputTokens;
    this.baseUrl = opts.baseUrl ?? 'https://generativelanguage.googleapis.com/v1beta';
    this.fetchImpl = opts.fetchImpl ?? fetch;
    this.retryDelayMs = opts.retryDelayMs ?? 1000;
  }

  /**
   * Phase 14: one retry, after a short pause, when the model host answers
   * 5xx ("overloaded" — common on the free tier, seen in the live smoke).
   * Never for 429 (the quota), a bad key, a timeout or a malformed answer.
   */
  async generate(request: AiRequest): Promise<AiResponse> {
    return this.withRetry(() => this.once(request));
  }

  /**
   * Beta 3.8: `streamGenerateContent` as server-sent events. The timeout is
   * per chunk (the model may write for longer than one answer took whole),
   * and the one 5xx retry happens before any text, as a 5xx is a status.
   */
  async generateStream(request: AiRequest, onText: AiTextSink): Promise<AiResponse> {
    return this.withRetry(() => this.streamOnce(request, onText));
  }

  private async withRetry(call: () => Promise<AiResponse>): Promise<AiResponse> {
    try {
      return await call();
    } catch (e) {
      if (!(e instanceof AiProviderError) || e.kind !== 'unavailable' || e.status === undefined || e.status < 500) throw e;
      await new Promise((r) => setTimeout(r, this.retryDelayMs));
      return call();
    }
  }

  private async post(request: AiRequest, method: string, signal: AbortSignal): Promise<Response> {
    let res: Response;
    try {
      const model = request.model ?? this.model;
      res = await this.fetchImpl(`${this.baseUrl}/models/${encodeURIComponent(model)}:${method}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': this.apiKey },
        body: JSON.stringify(GeminiProvider.toBody(request, this.maxOutputTokens)),
        signal,
      });
    } catch (e) {
      throw this.transportError(e, 'Could not reach the model.');
    }
    if (res.status === 429) throw new AiProviderError('rate_limited', 'The model is rate limited right now.', 429);
    if (res.status === 401 || res.status === 403) {
      // A bad key is an operator problem, never the user's; say so without the key.
      throw new AiProviderError('not_configured', 'The model rejected this server\'s credentials.', res.status);
    }
    if (!res.ok) throw new AiProviderError('unavailable', `The model answered ${res.status}.`, res.status);
    return res;
  }

  private transportError(e: unknown, message: string): AiProviderError {
    if (e instanceof AiProviderError) return e;
    if ((e as { name?: string }).name === 'AbortError') {
      return new AiProviderError('timeout', `The model did not answer within ${this.timeoutMs} ms.`);
    }
    return new AiProviderError('unavailable', message);
  }

  private async streamOnce(request: AiRequest, onText: AiTextSink): Promise<AiResponse> {
    const controller = new AbortController();
    let timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const res = await this.post(request, 'streamGenerateContent?alt=sse', controller.signal);
      if (res.body === null) throw new AiProviderError('malformed', 'The model answered with no body.');
      const chunks: GeminiResponseBody[] = [];
      let text = '';
      const line = (raw: string): void => {
        const l = raw.replace(/\r$/, '');
        if (!l.startsWith('data:')) return;
        let chunk: GeminiResponseBody;
        try {
          chunk = JSON.parse(l.slice(5)) as GeminiResponseBody;
        } catch {
          throw new AiProviderError('malformed', 'The model answered with something that is not JSON.');
        }
        chunks.push(chunk);
        const delta = (chunk.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? '').join('');
        if (delta.length > 0) {
          text += delta;
          onText(text);
        }
      };
      let pending = '';
      const decoder = new TextDecoder();
      try {
        for await (const bytes of res.body as unknown as AsyncIterable<Uint8Array>) {
          clearTimeout(timer);
          timer = setTimeout(() => controller.abort(), this.timeoutMs);
          pending += decoder.decode(bytes, { stream: true });
          for (let nl = pending.indexOf('\n'); nl >= 0; nl = pending.indexOf('\n')) {
            line(pending.slice(0, nl));
            pending = pending.slice(nl + 1);
          }
        }
      } catch (e) {
        throw this.transportError(e, 'The model stopped answering.');
      }
      line(pending + decoder.decode());
      return GeminiProvider.fromChunks(chunks);
    } finally {
      clearTimeout(timer);
    }
  }

  private async once(request: AiRequest): Promise<AiResponse> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    let res: Response;
    try {
      res = await this.post(request, 'generateContent', controller.signal);
    } finally {
      clearTimeout(timer);
    }

    let json: GeminiResponseBody;
    try {
      json = (await res.json()) as GeminiResponseBody;
    } catch {
      throw new AiProviderError('malformed', 'The model answered with something that is not JSON.');
    }
    return GeminiProvider.fromBody(json);
  }

  /* ------------------------------------------------------------ mapping -- */

  static toBody(request: AiRequest, maxOutputTokens: number): Record<string, unknown> {
    const contents: GeminiContent[] = request.messages.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [
        ...(m.content.length > 0 ? [{ text: m.content }] : []),
        ...(m.toolCalls ?? []).map((c) => ({
          functionCall: { name: c.name, args: c.args, ...(c.id !== undefined ? { id: c.id } : {}) },
          ...(c.signature !== undefined ? { thoughtSignature: c.signature } : {}),
        })),
      ],
    }));
    if (request.toolResults !== undefined && request.toolResults.length > 0) {
      contents.push({
        role: 'user',
        parts: request.toolResults.map((r) => ({ functionResponse: { name: r.name, response: r.result, ...(r.id !== undefined ? { id: r.id } : {}) } })),
      });
    }
    const generationConfig: Record<string, unknown> = {
      maxOutputTokens: request.maxOutputTokens ?? maxOutputTokens,
      temperature: request.temperature ?? 0.3,
    };
    if (request.jsonMode === true) generationConfig['responseMimeType'] = 'application/json';
    const body: Record<string, unknown> = {
      systemInstruction: { parts: [{ text: request.system }] },
      contents,
      generationConfig,
    };
    if (request.tools !== undefined && request.tools.length > 0) {
      body['tools'] = [
        {
          functionDeclarations: request.tools.map((t) => ({
            name: t.name,
            description: t.description,
            parameters: t.parameters,
          })),
        },
      ];
    }
    return body;
  }

  /**
   * Beta 3.8: a streamed answer as one body: every part in order, the last
   * finish reason and token count, and a block if any chunk carried one.
   */
  static fromChunks(chunks: readonly GeminiResponseBody[]): AiResponse {
    if (chunks.length === 0) throw new AiProviderError('empty', 'The model returned no answer.');
    const blocked = chunks.find((c) => c.promptFeedback?.blockReason !== undefined);
    const finishReason = [...chunks].reverse().find((c) => c.candidates?.[0]?.finishReason !== undefined)?.candidates?.[0]?.finishReason;
    const usage = [...chunks].reverse().find((c) => c.usageMetadata !== undefined)?.usageMetadata;
    const parts = chunks.flatMap((c) => c.candidates?.[0]?.content?.parts ?? []);
    return GeminiProvider.fromBody({
      ...(blocked !== undefined ? { promptFeedback: blocked.promptFeedback } : {}),
      candidates: [{ content: { parts }, ...(finishReason !== undefined ? { finishReason } : {}) }],
      ...(usage !== undefined ? { usageMetadata: usage } : {}),
    });
  }

  static fromBody(json: GeminiResponseBody): AiResponse {
    if (json.promptFeedback?.blockReason !== undefined) {
      throw new AiProviderError('blocked', 'The model declined that request.');
    }
    const candidate = json.candidates?.[0];
    if (candidate === undefined) throw new AiProviderError('empty', 'The model returned no answer.');
    const parts = candidate.content?.parts ?? [];
    const text = parts
      .map((p) => p.text)
      .filter((t): t is string => typeof t === 'string')
      .join('');
    const toolCalls: AiToolCall[] = parts
      .filter((p) => p.functionCall !== undefined)
      .map((p) => ({
        name: p.functionCall!.name,
        args: p.functionCall!.args ?? {},
        ...(p.functionCall!.id !== undefined ? { id: p.functionCall!.id } : {}),
        ...(p.thoughtSignature !== undefined ? { signature: p.thoughtSignature } : {}),
      }));
    if (text.length === 0 && toolCalls.length === 0) {
      if (candidate.finishReason === 'SAFETY') throw new AiProviderError('blocked', 'The model declined that request.');
      throw new AiProviderError('empty', 'The model returned an empty answer.');
    }
    const finishReason: AiResponse['finishReason'] =
      toolCalls.length > 0
        ? 'tool'
        : candidate.finishReason === 'MAX_TOKENS'
          ? 'length'
          : candidate.finishReason === 'SAFETY'
            ? 'safety'
            : candidate.finishReason === 'STOP' || candidate.finishReason === undefined
              ? 'stop'
              : 'other';
    const usage =
      json.usageMetadata !== undefined
        ? { inputTokens: json.usageMetadata.promptTokenCount ?? 0, outputTokens: json.usageMetadata.candidatesTokenCount ?? 0 }
        : undefined;
    return { text, toolCalls, finishReason, ...(usage !== undefined ? { usage } : {}) };
  }
}
