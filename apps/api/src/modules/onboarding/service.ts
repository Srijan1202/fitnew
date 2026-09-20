/**
 * Onboarding state machine (§32).
 *
 * Stateless in the interesting sense: the "state" is whatever has been
 * stored, and the next step is DERIVED from it on every read. That is what
 * makes both spec rules trivially true —
 *   "state persists server-side and resumes after a kill": every answer is a
 *   write, and GET /onboarding/state recomputes from the rows;
 *   "back always works": any step may be re-answered at any time.
 *
 * `complete` is the only gate: it refuses until every required step has an
 * answer, then computes real targets (§32 rule: never a placeholder).
 */
import { createHash } from 'node:crypto';

import {
  CONSENT_TYPES,
  CURRENT_POLICY_VERSION,
  MIN_AGE_YEARS,
  ONBOARDING_COMPLETE,
  ONBOARDING_STEPS,
  REQUIRED_STEPS,
  type OnboardingAnswer,
  type OnboardingCompleteResponse,
  type OnboardingStage,
  type OnboardingState,
  type OnboardingStep,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { ProfileBundle, UserRepository } from '../user/repository.js';
import { goalFrom, profileDetailFrom } from '../user/service.js';
import { TargetsService, ageYears, todayIn } from '../user/targets.service.js';

/** Which steps have a stored answer. Pure; unit-tested without a database. */
export function answeredSteps(bundle: ProfileBundle): OnboardingStep[] {
  const p = bundle.profile;
  const out: OnboardingStep[] = [];
  if (bundle.goal !== null) out.push('goal');
  if (p?.sex && p.birthDate && p.heightCm && bundle.latestWeight !== null) out.push('about');
  if (p?.experienceLevel && p.trainingDaysPerWeek !== null && p.activityLevel) out.push('experience');
  if (p?.trainingLocation && p.equipment.length > 0) out.push('training');
  if (bundle.diet !== null) out.push('food');
  if (p?.isVitStudent !== null && p?.isVitStudent !== undefined) out.push('vit');
  return out;
}

/** The next unanswered step in §32 order, or `complete`. */
export function nextStage(answered: readonly OnboardingStep[], completed: boolean): OnboardingStage {
  if (completed) return ONBOARDING_COMPLETE;
  const done = new Set(answered);
  for (const step of ONBOARDING_STEPS) {
    if (!done.has(step)) return step;
  }
  return ONBOARDING_COMPLETE;
}

export function missingRequired(answered: readonly OnboardingStep[]): OnboardingStep[] {
  const done = new Set(answered);
  return REQUIRED_STEPS.filter((s) => !done.has(s));
}

/** Salted, so the hash shows a request came from somewhere without storing where. */
export function hashIp(ip: string, salt: string): string {
  return createHash('sha256').update(`${salt}:${ip}`).digest('hex');
}

export interface AnswerContext {
  /** From the verified request, for the consent record. */
  readonly ip: string;
  readonly ipSalt: string;
}

export class OnboardingService {
  private readonly targets: TargetsService;

  constructor(private readonly repo: UserRepository) {
    this.targets = new TargetsService(repo);
  }

  private async bundleOrThrow(userId: string): Promise<ProfileBundle> {
    const bundle = await this.repo.loadBundle(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'User not found.');
    return bundle;
  }

  private stateFrom(bundle: ProfileBundle): OnboardingState {
    const answered = answeredSteps(bundle);
    const completed = bundle.profile?.onboardingStage === ONBOARDING_COMPLETE;
    return {
      stage: nextStage(answered, completed),
      completed,
      answered,
      missing: missingRequired(answered),
      profile: profileDetailFrom(bundle),
      goalType: bundle.goal?.goalType ?? null,
      dietType: bundle.diet?.dietType ?? null,
      allergies: bundle.allergies.map((a) => ({ allergen: a.allergen, severity: a.severity })),
      policyVersion: CURRENT_POLICY_VERSION,
    };
  }

  async getState(userId: string): Promise<OnboardingState> {
    return this.stateFrom(await this.bundleOrThrow(userId));
  }

  async answer(userId: string, answer: OnboardingAnswer, ctx: AnswerContext): Promise<OnboardingState> {
    const before = await this.bundleOrThrow(userId);

    switch (answer.step) {
      case 'goal':
        // Re-answering the goal during onboarding replaces it rather than
        // stacking history: the user is still deciding.
        await this.repo.replaceGoal(userId, { goalType: answer.goalType, targetWeightKg: null });
        break;

      case 'about': {
        const today = todayIn(before.user.timezone);
        if (ageYears(answer.birthDate, today) < MIN_AGE_YEARS) {
          // 18+ only (§23, ADR): the row is not written.
          throw new AppError('VALIDATION_FAILED', 'FitOS is for adults only.', [
            { path: 'birthDate', issue: `must be at least ${MIN_AGE_YEARS} years ago` },
          ]);
        }
        if (answer.birthDate > today) {
          throw new AppError('VALIDATION_FAILED', 'Birth date cannot be in the future.', [
            { path: 'birthDate', issue: 'is in the future' },
          ]);
        }
        const granted = new Set(answer.consent.types);
        const notGranted = CONSENT_TYPES.filter((t) => !granted.has(t));
        if (notGranted.length > 0) {
          throw new AppError('VALIDATION_FAILED', 'Consent is required to continue.', [
            { path: 'consent.types', issue: `missing: ${notGranted.join(', ')}` },
          ]);
        }
        if (answer.consent.policyVersion !== CURRENT_POLICY_VERSION) {
          throw new AppError('VALIDATION_FAILED', 'The privacy policy has changed; please review it again.', [
            { path: 'consent.policyVersion', issue: `current version is ${CURRENT_POLICY_VERSION}` },
          ]);
        }
        // Consent first, then the data it covers.
        await this.repo.recordConsent(
          CONSENT_TYPES.map((consentType) => ({
            userId,
            consentType,
            granted: true,
            policyVersion: answer.consent.policyVersion,
            ipHash: hashIp(ctx.ip, ctx.ipSalt),
          })),
        );
        await this.repo.upsertProfile(userId, {
          sex: answer.sex,
          birthDate: answer.birthDate,
          heightCm: String(answer.heightCm),
        });
        await this.repo.upsertWeight(userId, {
          measuredOn: today,
          weightKg: String(answer.weightKg),
          source: 'onboarding',
        });
        break;
      }

      case 'experience':
        await this.repo.upsertProfile(userId, {
          experienceLevel: answer.experienceLevel,
          trainingDaysPerWeek: answer.trainingDaysPerWeek,
          activityLevel: answer.activityLevel,
        });
        break;

      case 'training':
        await this.repo.upsertProfile(userId, {
          trainingLocation: answer.trainingLocation,
          equipment: answer.equipment,
        });
        break;

      case 'food':
        await this.repo.replaceDiet(userId, { dietType: answer.dietType }, answer.allergies);
        break;

      case 'vit':
        await this.repo.upsertProfile(userId, {
          isVitStudent: answer.isVitStudent,
          messProviderId: answer.mess?.providerId ?? null,
          messHostelId: answer.mess?.hostelId ?? null,
          messMessId: answer.mess?.messId ?? null,
        });
        break;
    }

    // Keep the stored stage current so the session response routes right at
    // cold start; never regress a completed profile back to in-progress. The
    // stored value is capped at the last step: only /complete may write
    // 'complete', because that is the call that computes targets. Without the
    // cap a user who answered all six screens but never saw screen 7 would be
    // routed to TODAY with no targets — found while writing the client flow.
    const after = await this.bundleOrThrow(userId);
    if (after.profile?.onboardingStage !== ONBOARDING_COMPLETE) {
      const next = nextStage(answeredSteps(after), false);
      await this.repo.upsertProfile(userId, {
        onboardingStage: next === ONBOARDING_COMPLETE ? 'vit' : next,
      });
    }
    return this.stateFrom(await this.bundleOrThrow(userId));
  }

  /** Screen 7: real targets from the engine, or 409 naming what is missing. */
  async complete(userId: string): Promise<OnboardingCompleteResponse> {
    const bundle = await this.bundleOrThrow(userId);
    const missing = missingRequired(answeredSteps(bundle));
    if (missing.length > 0) {
      throw new AppError('CONFLICT', 'Onboarding is not finished.', missing.map((s) => ({ path: s, issue: 'unanswered' })));
    }
    // Ensure a preferences row exists with defaults, so later PATCHes are updates.
    await this.repo.upsertPreferences(userId, {});
    const targets = await this.targets.recompute(userId, bundle, 'onboarding');
    await this.repo.upsertProfile(userId, { onboardingStage: ONBOARDING_COMPLETE });

    const after = await this.bundleOrThrow(userId);
    const goal = goalFrom(after);
    if (goal === null) throw new Error('goal missing after complete');
    return { profile: profileDetailFrom(after), goal, targets };
  }
}
