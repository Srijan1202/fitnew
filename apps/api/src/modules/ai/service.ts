/**
 * Phase 6.6 — the AI service. Gate 3: status and the one place provider
 * failures become §10 envelopes. The context assembler, tool registry
 * and chat orchestration arrive in Gates 4–5 on top of this.
 */
import type { AiStatusResponse } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { AiProviderError, type AiProvider } from './provider.js';

/** What the assistant never sees (owner B4; Phase 8 not built). */
export const AI_EXCLUDES: AiStatusResponse['excludes'] = ['health-connect', 'food-log'];

export class AiService {
  constructor(private readonly provider: AiProvider) {}

  status(): AiStatusResponse {
    const configured = this.provider.name !== 'none';
    return {
      configured,
      provider: this.provider.name,
      model: configured ? this.provider.model : null,
      excludes: AI_EXCLUDES,
    };
  }

  /**
   * Provider failures → the envelope. The message is safe for the user;
   * the upstream detail stays server-side. Anything that is not an
   * AiProviderError is re-thrown for the generic handler (500, logged).
   */
  static toAppError(e: unknown): AppError {
    if (e instanceof AppError) return e;
    if (e instanceof AiProviderError) {
      switch (e.kind) {
        case 'not_configured':
          return new AppError('UPSTREAM_UNAVAILABLE', 'AI is not set up on this server.');
        case 'rate_limited':
          return new AppError('RATE_LIMITED', 'FITOS AI is busy right now. Try again in a minute.');
        case 'timeout':
          return new AppError('UPSTREAM_UNAVAILABLE', 'FITOS AI took too long to answer. Try again.');
        case 'blocked':
          return new AppError('VALIDATION_FAILED', 'FITOS AI cannot answer that request.', [
            { path: 'message', issue: 'declined by the model' },
          ]);
        case 'malformed':
        case 'empty':
        case 'unavailable':
          return new AppError('UPSTREAM_UNAVAILABLE', 'FITOS AI is unavailable right now. Try again shortly.');
      }
    }
    throw e;
  }
}
