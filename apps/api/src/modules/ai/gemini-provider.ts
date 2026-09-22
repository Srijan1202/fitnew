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

  constructor(opts: GeminiProviderOptions) {
    if (opts.apiKey.trim().length === 0) throw new Error('GeminiProvider needs an API key');
    if (opts.model.trim().length === 0) throw new Error('GeminiProvider needs a model');
    this.apiKey = opts.apiKey;
    this.model = opts.model;
    this.timeoutMs = opts.timeoutMs;
    this.maxOutputTokens = opts.maxOutputTokens;
    this.baseUrl = opts.baseUrl ?? 'https://generativelanguage.googleapis.com/v1beta';
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  async generate(request: AiRequest): Promise<AiResponse> {
    const body = GeminiProvider.toBody(request, this.maxOutputTokens);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    let res: Response;
    try {
      res = await this.fetchImpl(`${this.baseUrl}/models/${encodeURIComponent(this.model)}:generateContent`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': this.apiKey },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (e) {
      if ((e as { name?: string }).name === 'AbortError') {
        throw new AiProviderError('timeout', `The model did not answer within ${this.timeoutMs} ms.`);
      }
      throw new AiProviderError('unavailable', 'Could not reach the model.');
    } finally {
      clearTimeout(timer);
    }

    if (res.status === 429) throw new AiProviderError('rate_limited', 'The model is rate limited right now.', 429);
    if (res.status === 401 || res.status === 403) {
      // A bad key is an operator problem, never the user's; say so without the key.
      throw new AiProviderError('not_configured', 'The model rejected this server\'s credentials.', res.status);
    }
    if (!res.ok) throw new AiProviderError('unavailable', `The model answered ${res.status}.`, res.status);

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
