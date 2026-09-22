/**
 * Phase 6.6 — the language-model seam (ADR-010). The rest of the AI module
 * talks to this interface only; Gemini is one implementation behind it and
 * can be replaced without touching the context assembler, the tool
 * registry or the routes.
 *
 * A provider is a text-in / text-or-tool-calls-out function with a hard
 * timeout. It knows nothing about FITOS: no database, no user, no tools of
 * its own — the caller passes tool *declarations* and executes any call the
 * model asks for (Gate 4). Health Connect data never reaches a provider
 * (owner B4).
 */

export type AiRole = 'user' | 'assistant';

export interface AiMessage {
  readonly role: AiRole;
  readonly content: string;
}

/** A tool the model may ask to call. Arguments are a JSON-schema object. */
export interface AiToolDeclaration {
  readonly name: string;
  readonly description: string;
  readonly parameters: Record<string, unknown>;
}

/** The result of a tool the caller executed, fed back to the model. */
export interface AiToolResult {
  readonly name: string;
  readonly result: Record<string, unknown>;
}

export interface AiRequest {
  /** The system instruction; the persona and the rules. */
  readonly system: string;
  /** The conversation so far, oldest first. */
  readonly messages: readonly AiMessage[];
  readonly tools?: readonly AiToolDeclaration[];
  /** Results for the tool calls the previous answer asked for. */
  readonly toolResults?: readonly AiToolResult[];
  readonly maxOutputTokens?: number;
  readonly temperature?: number;
  /** Ask for a JSON object as the answer (structured extraction). */
  readonly jsonMode?: boolean;
}

export interface AiToolCall {
  readonly name: string;
  readonly args: Record<string, unknown>;
}

export interface AiResponse {
  /** The model's text, '' when it answered only with tool calls. */
  readonly text: string;
  readonly toolCalls: readonly AiToolCall[];
  readonly finishReason: 'stop' | 'length' | 'tool' | 'safety' | 'other';
  readonly usage?: { readonly inputTokens: number; readonly outputTokens: number };
}

export interface AiProvider {
  /** For status and logs — never a credential. */
  readonly name: string;
  readonly model: string;
  generate(request: AiRequest): Promise<AiResponse>;
}

/**
 * Why a provider call failed, mapped to the §10 envelope by the service:
 * `unavailable` → UPSTREAM_UNAVAILABLE, `rate_limited` → RATE_LIMITED,
 * `malformed`/`empty` → UPSTREAM_UNAVAILABLE with a distinct message,
 * `not_configured` → UPSTREAM_UNAVAILABLE ("AI is not set up on this
 * server"). The message never carries a credential or the raw upstream body.
 */
export type AiFailureKind = 'not_configured' | 'timeout' | 'unavailable' | 'rate_limited' | 'malformed' | 'empty' | 'blocked';

export class AiProviderError extends Error {
  constructor(
    readonly kind: AiFailureKind,
    message: string,
    /** Upstream HTTP status, when there was one. */
    readonly status?: number,
  ) {
    super(message);
    this.name = 'AiProviderError';
  }
}
