/**
 * A scripted AiProvider for deterministic tests and for the server when
 * no key is configured. Answers in order from `script`; records every
 * request so a test can assert what reached "the model" — and, above all,
 * what did not (no Health Connect data, owner B4).
 */
import { AiProviderError, type AiProvider, type AiRequest, type AiResponse, type AiTextSink } from './provider.js';

export class FakeAiProvider implements AiProvider {
  readonly name = 'fake';
  readonly model = 'fake-1';
  readonly requests: AiRequest[] = [];
  /** Each entry answers one call; a function may throw to script a failure. */
  script: (AiResponse | ((request: AiRequest) => AiResponse))[] = [];

  async generate(request: AiRequest): Promise<AiResponse> {
    this.requests.push(request);
    const next = this.script.shift();
    if (next === undefined) {
      return { text: 'OK', toolCalls: [], finishReason: 'stop' };
    }
    return typeof next === 'function' ? next(request) : next;
  }

  /** Beta 3.8: the scripted answer, its text reported in 10-character steps. */
  async generateStream(request: AiRequest, onText: AiTextSink): Promise<AiResponse> {
    const response = await this.generate(request);
    for (let i = 10; i < response.text.length + 10; i += 10) onText(response.text.slice(0, i));
    return response;
  }
}

/** The provider the server uses when GEMINI_API_KEY is absent: honest. */
export class NotConfiguredAiProvider implements AiProvider {
  readonly name = 'none';
  readonly model = '';

  async generate(): Promise<AiResponse> {
    throw new AiProviderError('not_configured', 'AI is not set up on this server.');
  }
}
