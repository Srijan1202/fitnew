/**
 * Onboarding (§32): progressive profiling, at most seven screens, state held
 * server-side so it survives a killed app.
 *
 * Model: each answer is a discriminated union on `step`. Any step may be
 * answered or re-answered at any time — that is what makes "back always
 * works" trivial — and the server derives the next step from what is stored.
 * `complete` is refused until every required step has an answer.
 */
import { z } from 'zod';

import {
  activityLevelSchema,
  allergySchema,
  dietTypeSchema,
  equipmentSchema,
  experienceLevelSchema,
  goalResponseSchema,
  goalTypeSchema,
  heightCmSchema,
  isoDateSchema,
  nutritionTargetsSchema,
  displayNameSchema,
  sexSchema,
  trainingDaysSchema,
  trainingLocationSchema,
  userProfileDetailSchema,
  weightKgSchema,
} from './profile.js';

/** Screens 1–6 of §32, plus the terminal state. */
export const ONBOARDING_STEPS = ['goal', 'about', 'experience', 'training', 'food', 'vit'] as const;
export const onboardingStepSchema = z.enum(ONBOARDING_STEPS);
export type OnboardingStep = z.infer<typeof onboardingStepSchema>;

export const ONBOARDING_COMPLETE = 'complete' as const;
export const onboardingStageSchema = z.enum([...ONBOARDING_STEPS, ONBOARDING_COMPLETE]);
export type OnboardingStage = z.infer<typeof onboardingStageSchema>;

/** Screen 6 is the only optional one: non-VIT users skip it. */
export const REQUIRED_STEPS: readonly OnboardingStep[] = ['goal', 'about', 'experience', 'training', 'food'];

/* ------------------------------------------------------------- consent -- */

export const CONSENT_TYPES = ['privacy-policy', 'health-data-processing'] as const;
export const consentTypeSchema = z.enum(CONSENT_TYPES);
export type ConsentType = z.infer<typeof consentTypeSchema>;

/**
 * Bump this whenever the privacy policy text changes. Every consent row
 * records which version was agreed to (§23), so a policy change can be
 * re-consented rather than assumed.
 */
export const CURRENT_POLICY_VERSION = '2026-09-21';

export const consentGrantSchema = z
  .object({
    policyVersion: z.string().min(1),
    /** Must include every type in CONSENT_TYPES; partial consent is refused. */
    types: z.array(consentTypeSchema).min(1),
  })
  .strict();

/* ------------------------------------------------------------- answers -- */

const goalAnswer = z.object({
  step: z.literal('goal'),
  goalType: goalTypeSchema,
});

/**
 * Screen 2 is where health-adjacent data first arrives, so consent is taken
 * here and is required (§23). Weight goes to body_metrics, not the profile:
 * it is a reading, and the trend engine (Phase 12) reads the series.
 */
const aboutAnswer = z.object({
  step: z.literal('about'),
  /** Phase 6.6: "What should we call you?" — the first field of the step. */
  displayName: displayNameSchema,
  sex: sexSchema,
  birthDate: isoDateSchema,
  heightCm: heightCmSchema,
  weightKg: weightKgSchema,
  consent: consentGrantSchema,
});

/**
 * Activity level is asked here rather than deferred to Phase 13: the TDEE
 * formula (§13.1) needs it on screen 7, and it is one tap with a sensible
 * default. Recorded as a Phase 2 deviation from §32's deferral list.
 */
const experienceAnswer = z.object({
  step: z.literal('experience'),
  experienceLevel: experienceLevelSchema,
  trainingDaysPerWeek: trainingDaysSchema,
  activityLevel: activityLevelSchema,
});

const trainingAnswer = z.object({
  step: z.literal('training'),
  trainingLocation: trainingLocationSchema,
  equipment: z.array(equipmentSchema).min(1),
});

const foodAnswer = z.object({
  step: z.literal('food'),
  dietType: dietTypeSchema,
  allergies: z.array(allergySchema),
});

/** Either "not a VIT student", or a mess reference. */
const vitAnswer = z.object({
  step: z.literal('vit'),
  isVitStudent: z.boolean(),
  mess: z
    .object({
      providerId: z.string().min(1),
      hostelId: z.string().min(1),
      messId: z.string().min(1),
    })
    .nullable(),
});

export const onboardingAnswerSchema = z
  .discriminatedUnion('step', [
    goalAnswer,
    aboutAnswer,
    experienceAnswer,
    trainingAnswer,
    foodAnswer,
    vitAnswer,
  ])
  .superRefine((answer, ctx) => {
    if (answer.step === 'vit' && answer.isVitStudent && answer.mess === null) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['mess'],
        message: 'a VIT student must pick a mess',
      });
    }
  });
export type OnboardingAnswer = z.infer<typeof onboardingAnswerSchema>;

/* --------------------------------------------------------------- state -- */

/**
 * GET /onboarding/state and the response to every answer.
 *
 * `answered` lets the client restore every screen's previous values on
 * resume, and lets "back" show what was chosen rather than a blank form.
 */
export const onboardingStateSchema = z.object({
  /** Next unanswered step, or 'complete' when every step is answered (= ready for screen 7). */
  stage: onboardingStageSchema,
  /** True only once POST /onboarding/complete has computed targets. */
  completed: z.boolean(),
  /** Steps with a stored answer, in §32 order. */
  answered: z.array(onboardingStepSchema),
  /** Required steps still missing; empty means `complete` may be called. */
  missing: z.array(onboardingStepSchema),
  /** Current profile snapshot, for pre-filling screens. */
  profile: userProfileDetailSchema,
  goalType: goalTypeSchema.nullable(),
  dietType: dietTypeSchema.nullable(),
  allergies: z.array(allergySchema),
  policyVersion: z.string(),
});
export type OnboardingState = z.infer<typeof onboardingStateSchema>;

/**
 * POST /onboarding/complete — screen 7.
 *
 * Targets are real engine output (§32: "a real generated plan, not a
 * placeholder"). The training week is Phase 4's generator and is absent here
 * rather than faked; it joins this response when it exists.
 */
export const onboardingCompleteResponseSchema = z.object({
  profile: userProfileDetailSchema,
  goal: goalResponseSchema.shape.goal,
  targets: nutritionTargetsSchema,
});
export type OnboardingCompleteResponse = z.infer<typeof onboardingCompleteResponseSchema>;
