/**
 * Beta 6.1 (premium) — the AI programme builder (core `ai/programme`).
 *
 *   the library ──FITOS──▶ what this person can do: their equipment, no
 *       exercise their limitations rule out, nothing they asked to leave out
 *   ──model──▶ a week as short ids, sets, reps and RIR (JSON only)
 *   ──FITOS──▶ read and fitted (the minutes asked for, each muscle's MRV);
 *       every change said in a line
 *
 * Nothing is saved: the app uses a draft through the ordinary custom
 * programme route. Usage is recorded as the `programme` purpose.
 */
import type { AiProgrammeDraft, AiProgrammeRequest } from '@fitos/contracts';
import { fitProgramme, programmePrompt, readProgrammeAnswer, type ProgrammeCandidate, type ProgrammeDraft } from '@fitos/core/ai/programme';
import { isContraindicated, isPerformable, type BodyPart } from '@fitos/core/training/generator';

import { AppError } from '../../lib/errors.js';
import type { TrainingRepository } from '../training/repository.js';
import { toCatalogueExercise } from '../training/service.js';
import { AiProviderError, type AiProvider } from './provider.js';
import { AiService } from './service.js';
import type { AiBudget } from './usage.js';

/** The answer's room and wait (the server's defaults are for short answers: 2,048 tokens, 25 s). */
export const PROGRAMME_MAX_OUTPUT_TOKENS = 8192;
export const PROGRAMME_TIMEOUT_MS = 60_000;

export class ProgrammeBuilderService {
  constructor(
    private readonly provider: AiProvider,
    private readonly training: TrainingRepository,
    private readonly budget: AiBudget,
    private readonly log?: { warn: (obj: Record<string, unknown>, msg: string) => void },
  ) {}

  async draft(userId: string, body: AiProgrammeRequest, premium = false): Promise<AiProgrammeDraft> {
    await this.budget.check(userId, 'programme', premium);
    if (this.provider.name === 'none') throw AiService.toAppError(new AiProviderError('not_configured', 'no provider'));

    const { profile, goal, limitations } = await this.training.profileInputs(userId);
    if (goal === null || profile === null || profile.experienceLevel === null) {
      throw new AppError('CONFLICT', 'Finish onboarding before building a programme.', [{ path: 'goal', issue: 'required' }]);
    }
    const avoid = new Set(body.avoid);
    const library = (await this.training.catalogue())
      .map(toCatalogueExercise)
      .filter((x) => isPerformable(x, profile.equipment) && !isContraindicated(x, limitations as BodyPart[]) && !avoid.has(x.id));
    if (library.length < 6) {
      throw new AppError('CONFLICT', 'Too few exercises suit your equipment and what you left out to build a week.', [{ path: 'avoid', issue: 'too-few' }]);
    }
    const idOf = new Map<string, string>();
    const candidates: ProgrammeCandidate[] = library.map((x, i) => {
      const id = `E${i + 1}`;
      idOf.set(id, x.id);
      return { id, name: x.name, pattern: x.movementPattern, primary: x.primaryMuscles, secondary: x.secondaryMuscles };
    });
    const nameOf = new Map(library.map((x) => [x.id, x.name]));

    const note = body.note === undefined || body.note === null || body.note.trim() === '' ? null : body.note.trim();
    const prompt = programmePrompt(
      { goal: goal.goalType, experience: profile.experienceLevel, sessions: body.sessions, minutes: body.minutes, focus: body.focus, note },
      candidates,
    );
    let usage: { inputTokens: number; outputTokens: number } | undefined;
    let read: ProgrammeDraft;
    try {
      const response = await this.provider.generate({
        system: prompt.system,
        messages: [{ role: 'user', content: prompt.user }],
        jsonMode: true,
        temperature: 0.4,
        // A week is a long answer (up to 6 days × 8 exercises) after a long prompt (the library):
        // room to finish, and time to write it (audit 2026-11-10).
        maxOutputTokens: PROGRAMME_MAX_OUTPUT_TOKENS,
        timeoutMs: PROGRAMME_TIMEOUT_MS,
      });
      usage = response.usage;
      read = ProgrammeBuilderService.read(response.text, candidates, body.sessions);
    } catch (e) {
      if (e instanceof AiProviderError) {
        this.log?.warn({ kind: e.kind, upstreamStatus: e.status ?? null, model: this.provider.model }, 'ai programme: provider failure');
      }
      await this.budget.record(userId, 'programme', this.provider.model, usage, e instanceof AiProviderError && e.kind === 'malformed' ? 'discarded' : 'failed');
      throw AiService.toAppError(e);
    }
    const { draft, adjustments } = fitProgramme(read, candidates, body.minutes);
    await this.budget.record(userId, 'programme', this.provider.model, usage, 'ok');
    return {
      name: draft.name,
      why: draft.why,
      days: draft.days.map((d) => ({
        sessionName: d.name,
        exercises: d.exercises.map((x) => {
          const exerciseId = idOf.get(x.id)!;
          return { exerciseId, name: nameOf.get(exerciseId)!, setCount: x.sets, repMin: x.repMin, repMax: x.repMax, targetRir: x.rir };
        }),
      })),
      adjustments,
      model: this.provider.model,
    };
  }

  /** The model's JSON, read; a code fence around it is tolerated. */
  static read(raw: string, candidates: readonly ProgrammeCandidate[], sessions: number): ProgrammeDraft {
    const text = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    let json: unknown;
    try {
      json = JSON.parse(text);
    } catch {
      throw new AiProviderError('malformed', 'The model did not answer with JSON.');
    }
    const draft = readProgrammeAnswer(json, candidates, sessions);
    if (draft === null) throw new AiProviderError('malformed', 'The model answered in the wrong shape.');
    return draft;
  }
}
