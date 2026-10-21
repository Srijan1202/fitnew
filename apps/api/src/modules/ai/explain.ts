/**
 * Phase 14 — explanation rephrasing with numeric validation (MASTER-SPEC
 * §19.1 "rephrasing engine-produced reasons", §19.2; ADR-020 D5).
 *
 * The input is a TODAY action the user owns: its deterministic headline,
 * detail and structured reason, loaded on the server (the phone sends only
 * the id, so nothing else can be smuggled in). The model may only reword it.
 * Any number in its answer that is not in that input — digits or words —
 * and the answer is discarded: the engine's own words are returned instead.
 * Nothing is stored except the usage row.
 */
import type { ExplainResponse } from '@fitos/contracts';
import { checkExplanation } from '@fitos/core/ai/guard';

import { AppError } from '../../lib/errors.js';
import type { AiConfig } from '../../plugins/ai.js';
import type { TodayRepository } from '../today/repository.js';
import { AiProviderError, type AiProvider } from './provider.js';
import { AiService } from './service.js';
import type { AiBudget } from './usage.js';

export const EXPLAIN_SYSTEM = [
  'You rephrase one recommendation from a fitness app so a student can understand it at a glance.',
  'Rules:',
  '- Use only the facts in the input. Say the same thing in plain, friendly words: at most 3 short sentences.',
  '- Do not add any number that is not already in the input: no new amounts, durations, percentages or counts, not even written as words.',
  '- Do not give medical advice or diagnose anything. Do not promise results.',
  '- Plain text only: no lists, no markdown, no emoji.',
].join('\n');

export class ExplainService {
  constructor(
    private readonly provider: AiProvider,
    private readonly today: TodayRepository,
    private readonly budget: AiBudget,
    private readonly config: AiConfig,
    /** Operator diagnostics: the failure kind and upstream status, never the text. */
    private readonly log?: { warn: (obj: Record<string, unknown>, msg: string) => void },
  ) {}

  private get model(): string {
    return this.config.models.explain ?? this.provider.model;
  }

  async explain(userId: string, actionId: string): Promise<ExplainResponse> {
    this.budget.assertEnabled();
    const row = await this.today.recommendation(userId, actionId);
    if (row === null) throw new AppError('NOT_FOUND', 'No such action.');
    await this.budget.check(userId, 'explain');
    if (this.provider.name === 'none') throw AiService.toAppError(new AiProviderError('not_configured', 'no provider'));

    const reason = (row.payload as { reason?: { code?: string; values?: Record<string, unknown> } }).reason ?? {};
    const input = { headline: row.headline, detail: row.detail, facts: reason.values ?? {} };
    let text: string;
    let usage: { inputTokens: number; outputTokens: number } | undefined;
    try {
      const response = await this.provider.generate({
        system: EXPLAIN_SYSTEM,
        messages: [{ role: 'user', content: JSON.stringify(input) }],
        temperature: 0.2,
        ...(this.config.models.explain !== null ? { model: this.config.models.explain } : {}),
      });
      usage = response.usage;
      text = AiService.plainText(response.text);
    } catch (e) {
      if (e instanceof AiProviderError) {
        this.log?.warn({ kind: e.kind, upstreamStatus: e.status ?? null, model: this.model }, 'ai explain: provider failure');
      }
      await this.budget.record(userId, 'explain', this.model, usage, 'failed');
      throw AiService.toAppError(e);
    }

    const check = checkExplanation(text, input);
    if (!check.ok) {
      await this.budget.record(userId, 'explain', this.model, usage, 'discarded');
      return { text: row.detail, source: 'engine', discarded: check.reason };
    }
    await this.budget.record(userId, 'explain', this.model, usage, 'ok');
    return { text, source: 'ai', discarded: null };
  }
}
