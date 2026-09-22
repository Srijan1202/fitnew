/**
 * Profile / goal / diet / preferences orchestration. Reads the bundle, maps
 * rows to contracts, and asks TargetsService to recompute when something that
 * feeds the formula changes. No formula lives here (§8.3).
 */
import type {
  DietPreferences,
  Goal,
  GoalResponse,
  PatchPreferencesRequest,
  PatchProfileRequest,
  PutDietPreferencesRequest,
  PutGoalRequest,
  UserPreferences,
  UserProfileDetail,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { stripUndefined } from '../../lib/objects.js';
import type { ProfileBundle, UserRepository } from './repository.js';
import { TargetsService, targetInputFrom, toContract } from './targets.service.js';

export function profileDetailFrom(bundle: ProfileBundle): UserProfileDetail {
  const p = bundle.profile;
  return {
    displayName: bundle.user.displayName,
    sex: p?.sex ?? null,
    birthDate: p?.birthDate ?? null,
    heightCm: p?.heightCm !== null && p?.heightCm !== undefined ? Number(p.heightCm) : null,
    experienceLevel: p?.experienceLevel ?? null,
    trainingDaysPerWeek: p?.trainingDaysPerWeek ?? null,
    activityLevel: p?.activityLevel ?? null,
    preferredSessionMinutes: p?.preferredSessionMinutes ?? null,
    trainingLocation: p?.trainingLocation ?? null,
    equipment: p?.equipment ?? [],
    latestWeightKg: bundle.latestWeight !== null ? Number(bundle.latestWeight.weightKg) : null,
    timezone: bundle.user.timezone,
    locale: bundle.user.locale,
    onboardingStage: p?.onboardingStage ?? 'goal',
    mess:
      p?.messProviderId && p.messHostelId && p.messMessId
        ? { providerId: p.messProviderId, hostelId: p.messHostelId, messId: p.messMessId }
        : null,
  };
}

export function goalFrom(bundle: ProfileBundle): Goal | null {
  const g = bundle.goal;
  if (g === null) return null;
  return {
    id: g.id,
    goalType: g.goalType,
    targetWeightKg: g.targetWeightKg !== null ? Number(g.targetWeightKg) : null,
    startedAt: g.startedAt.toISOString(),
  };
}

export function dietFrom(bundle: ProfileBundle): DietPreferences | null {
  const d = bundle.diet;
  if (d === null) return null;
  return {
    dietType: d.dietType,
    allergies: bundle.allergies.map((a) => ({ allergen: a.allergen, severity: a.severity })),
    excludedDishIds: Array.isArray(d.excludedDishIds) ? (d.excludedDishIds as string[]) : [],
    budgetTier: d.budgetTier,
  };
}

export function preferencesFrom(bundle: ProfileBundle): UserPreferences {
  const p = bundle.preferences;
  return {
    units: p?.units ?? 'metric',
    notificationSettings: (p?.notificationSettings as Record<string, unknown>) ?? {},
    featureFlags: (p?.featureFlags as Record<string, unknown>) ?? {},
  };
}

/** Fields whose change must produce a new targets row. */
const TARGET_INPUTS: ReadonlySet<keyof PatchProfileRequest> = new Set([
  'heightCm',
  'trainingDaysPerWeek',
  'activityLevel',
]);

export class UserService {
  private readonly targets: TargetsService;

  constructor(private readonly repo: UserRepository) {
    this.targets = new TargetsService(repo);
  }

  private async bundleOrThrow(userId: string): Promise<ProfileBundle> {
    const bundle = await this.repo.loadBundle(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'User not found.');
    return bundle;
  }

  async getProfile(userId: string): Promise<UserProfileDetail> {
    return profileDetailFrom(await this.bundleOrThrow(userId));
  }

  async patchProfile(userId: string, patch: PatchProfileRequest): Promise<UserProfileDetail> {
    await this.bundleOrThrow(userId);
    const { timezone, locale, heightCm, displayName, ...rest } = patch;
    if (displayName !== undefined) await this.repo.updateDisplayName(userId, displayName);
    await this.repo.updateUserLocale(userId, { ...(timezone !== undefined ? { timezone } : {}), ...(locale !== undefined ? { locale } : {}) });
    const profilePatch = stripUndefined({
      ...rest,
      heightCm: heightCm !== undefined ? String(heightCm) : undefined,
    });
    if (Object.keys(profilePatch).length > 0) await this.repo.upsertProfile(userId, profilePatch);

    const after = await this.bundleOrThrow(userId);
    // Recompute only when a formula input changed AND targets already exist:
    // before onboarding completes there is nothing to keep current.
    const touchesTargets = Object.keys(patch).some((k) => TARGET_INPUTS.has(k as keyof PatchProfileRequest));
    if (touchesTargets && after.targets !== null && !('missing' in targetInputFrom(after))) {
      await this.targets.recompute(userId, after, 'profile-change');
    }
    return profileDetailFrom(after);
  }

  async getGoal(userId: string): Promise<GoalResponse> {
    const bundle = await this.bundleOrThrow(userId);
    const goal = goalFrom(bundle);
    if (goal === null) throw new AppError('NOT_FOUND', 'No goal set yet. Complete onboarding first.');
    return { goal, targets: bundle.targets !== null ? toContract(bundle.targets) : null };
  }

  /** PUT closes the old goal, opens the new one, recomputes targets (§10.1). */
  async putGoal(userId: string, request: PutGoalRequest): Promise<GoalResponse> {
    await this.bundleOrThrow(userId);
    await this.repo.replaceGoal(userId, {
      goalType: request.goalType,
      targetWeightKg: request.targetWeightKg !== undefined && request.targetWeightKg !== null ? String(request.targetWeightKg) : null,
    });
    const after = await this.bundleOrThrow(userId);
    const goal = goalFrom(after);
    if (goal === null) throw new Error('goal vanished after replace');
    // A goal change always recomputes when the profile can support it.
    const targets =
      'missing' in targetInputFrom(after) ? null : await this.targets.recompute(userId, after, 'goal-change');
    return { goal, targets };
  }

  async getDiet(userId: string): Promise<DietPreferences> {
    const diet = dietFrom(await this.bundleOrThrow(userId));
    if (diet === null) throw new AppError('NOT_FOUND', 'No diet preferences yet. Complete onboarding first.');
    return diet;
  }

  async putDiet(userId: string, request: PutDietPreferencesRequest): Promise<DietPreferences> {
    await this.bundleOrThrow(userId);
    await this.repo.replaceDiet(
      userId,
      {
        dietType: request.dietType,
        ...(request.excludedDishIds !== undefined ? { excludedDishIds: request.excludedDishIds } : {}),
        ...(request.budgetTier !== undefined ? { budgetTier: request.budgetTier } : {}),
      },
      request.allergies,
    );
    const diet = dietFrom(await this.bundleOrThrow(userId));
    if (diet === null) throw new Error('diet vanished after replace');
    return diet;
  }

  async getPreferences(userId: string): Promise<UserPreferences> {
    return preferencesFrom(await this.bundleOrThrow(userId));
  }

  async patchPreferences(userId: string, patch: PatchPreferencesRequest): Promise<UserPreferences> {
    await this.bundleOrThrow(userId);
    await this.repo.upsertPreferences(userId, stripUndefined(patch));
    return preferencesFrom(await this.bundleOrThrow(userId));
  }
}
