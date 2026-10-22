/**
 * Phase 16 — the admin panel's service (MASTER-SPEC §20, ADR-022). Reviews,
 * corrections and edits go through core's rules; every change is written
 * with its `audit_logs` row in one transaction. Support lookups are audited
 * too: who looked at whose account is itself worth a trail.
 */
import type {
  ExerciseInput,
  NotifySettings,
} from '@fitos/contracts';
import { applyCorrection, endpointHealth, notificationRates, recommendationRates, type MacroField, type MacroRanges } from '@fitos/core/admin/admin';
import { normaliseFoodText } from '@fitos/core/nutrition/food';
import type { z } from 'zod';
import type {
  adminExerciseSchema,
  adminFoodSchema,
  correctionGroupSchema,
  editFoodRequestSchema,
  endpointHealthSchema,
  reviewCorrectionRequestSchema,
  userSupportSchema,
} from '@fitos/contracts';

import { uniqueViolationOf } from '../../db/errors.js';
import { AppError } from '../../lib/errors.js';
import { settingsFrom } from '../notifications/service.js';
import type { TrainingRepository } from '../training/repository.js';
import type { AdminRepository } from './repository.js';

type Endpoint = z.infer<typeof endpointHealthSchema>;
type CorrectionGroup = z.infer<typeof correctionGroupSchema>;
type AdminFood = z.infer<typeof adminFoodSchema>;
type AdminExercise = z.infer<typeof adminExerciseSchema>;
type UserSupport = z.infer<typeof userSupportSchema>;
type Review = z.infer<typeof reviewCorrectionRequestSchema>;
type EditFood = z.infer<typeof editFoodRequestSchema>;

const n = (v: string | null): number | null => (v === null ? null : Number(v));
const iso = (d: Date | null | undefined): string | null => (d === null || d === undefined ? null : d.toISOString());

function rangesOf(r: { kcalLow: string; kcalHigh: string; proteinLow: string; proteinHigh: string; carbLow: string; carbHigh: string; fatLow: string; fatHigh: string }): MacroRanges {
  return {
    kcalLow: Number(r.kcalLow), kcalHigh: Number(r.kcalHigh), proteinLow: Number(r.proteinLow), proteinHigh: Number(r.proteinHigh),
    carbLow: Number(r.carbLow), carbHigh: Number(r.carbHigh), fatLow: Number(r.fatLow), fatHigh: Number(r.fatHigh),
  };
}

export class AdminService {
  constructor(
    private readonly repo: AdminRepository,
    private readonly training: TrainingRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /* ---------------------------------------------------------- overview -- */

  async endpoints(): Promise<Endpoint[]> {
    const now = this.now();
    return (await this.repo.endpoints()).map((m) => {
      const h = endpointHealth({ lastSuccessAt: m.lastSuccessAt, consecutiveFailures: m.consecutiveFailures }, now);
      return {
        code: m.code,
        label: `${m.hostelLabel} · ${m.messLabel}`,
        sourceUrl: m.sourceUrl,
        lastAttemptAt: iso(m.lastAttemptAt),
        lastSuccessAt: iso(m.lastSuccessAt),
        lastChangedAt: iso(m.lastChangedAt),
        lastError: m.lastError,
        consecutiveFailures: m.consecutiveFailures,
        state: h.state,
        hoursSinceSuccess: h.hoursSinceSuccess,
      };
    });
  }

  async overview(days: number) {
    const now = this.now();
    const since = new Date(now.getTime() - days * 86_400_000);
    const [endpoints, pending, users, recs, notes] = await Promise.all([
      this.endpoints(),
      this.repo.pendingCorrections(),
      this.repo.userCounts(new Date(now.getTime() - 7 * 86_400_000)),
      this.repo.recommendationFunnel(since),
      this.repo.notificationFunnel(since, now),
    ]);
    return {
      generatedAt: now.toISOString(),
      days,
      endpoints,
      pendingCorrections: pending,
      users: { total: users.total, active7d: users.active },
      recommendations: recommendationRates(recs),
      notifications: notificationRates(notes),
    };
  }

  /* -------------------------------------------------------- corrections -- */

  async queue(status: 'pending' | 'accepted' | 'rejected'): Promise<CorrectionGroup[]> {
    const rows = await this.repo.corrections(status);
    const slugs = [...new Set(rows.map((r) => r.dishSlug))];
    const [estimates, overrides] = await Promise.all([this.repo.dishEstimates(slugs), this.repo.overrides(slugs)]);
    return slugs.map((slug) => {
      const e = estimates.get(slug);
      return {
        dishSlug: slug,
        estimate:
          e === undefined
            ? null
            : { name: e.name, servingLabel: e.servingLabel, ...rangesOf(e), confidence: e.confidence },
        dietOverride: overrides.get(slug) ?? null,
        reports: rows
          .filter((r) => r.dishSlug === slug)
          .map((r) => ({
            id: r.id,
            field: r.field as CorrectionGroup['reports'][number]['field'],
            valueLow: n(r.valueLow),
            valueHigh: n(r.valueHigh),
            dietValue: (r.dietValue as 'veg' | 'egg' | 'nonveg' | null) ?? null,
            note: r.note,
            status: r.status as 'pending' | 'accepted' | 'rejected',
            createdAt: r.createdAt.toISOString(),
            reviewedAt: iso(r.reviewedAt),
          })),
      };
    });
  }

  /** Accept applies the correction to the dish by slug (every future menu); reject changes nothing. */
  async review(actor: string | null, id: string, body: Review): Promise<CorrectionGroup> {
    const c = await this.repo.correction(id);
    if (c === null) throw new AppError('NOT_FOUND', 'No such correction.');
    if (c.status !== 'pending') throw new AppError('CONFLICT', 'This correction has already been reviewed.', [{ path: 'status', issue: c.status }]);

    await this.repo.inTransaction(async (tx) => {
      if (body.decision === 'reject') {
        await tx.reviewCorrection(id, 'rejected', actor);
        await tx.audit({ actorUserId: actor, action: 'correction.reject', entity: 'mess_dish_correction', entityId: id, metadata: { dishSlug: c.dishSlug, note: body.note ?? null } });
        return;
      }
      const meta: Record<string, unknown> = { dishSlug: c.dishSlug, field: c.field, note: body.note ?? null };
      if (c.field === 'diet') {
        const diet = body.diet ?? (c.dietValue as 'veg' | 'egg' | 'nonveg' | null);
        if (diet === null) throw new AppError('VALIDATION_FAILED', 'Say which diet the dish is.', [{ path: 'diet', issue: 'missing' }]);
        await tx.setDiet(c.dishSlug, diet, `review of correction ${id}`, actor);
        meta['diet'] = diet;
      } else if (c.field !== 'other') {
        const estimate = (await tx.dishEstimates([c.dishSlug])).get(c.dishSlug);
        if (estimate === undefined) throw new AppError('VALIDATION_FAILED', 'This dish has no estimate to correct.', [{ path: 'dishSlug', issue: 'no estimate' }]);
        const low = body.valueLow ?? n(c.valueLow)!;
        const high = body.valueHigh ?? n(c.valueHigh)!;
        const r = applyCorrection(rangesOf(estimate), c.field as MacroField, low, high);
        if (!r.ok) throw new AppError('VALIDATION_FAILED', `That value cannot be used: ${r.problem}.`, [{ path: 'value', issue: r.problem }]);
        await tx.reviseEstimate(c.dishSlug, { [`${c.field}Low`]: low, [`${c.field}High`]: high }, `review of correction ${id}`);
        meta['low'] = low;
        meta['high'] = high;
      }
      await tx.reviewCorrection(id, 'accepted', actor);
      await tx.audit({ actorUserId: actor, action: 'correction.accept', entity: 'mess_dish_correction', entityId: id, metadata: meta });
    });
    const status = body.decision === 'accept' ? 'accepted' : 'rejected';
    return (await this.queue(status)).find((g) => g.dishSlug === c.dishSlug)!;
  }

  async editDish(actor: string | null, slug: string, field: MacroField, low: number, high: number, reason: string): Promise<void> {
    const estimate = (await this.repo.dishEstimates([slug])).get(slug);
    if (estimate === undefined) throw new AppError('NOT_FOUND', 'This dish has no estimate.');
    const r = applyCorrection(rangesOf(estimate), field, low, high);
    if (!r.ok) throw new AppError('VALIDATION_FAILED', `That value cannot be used: ${r.problem}.`, [{ path: 'value', issue: r.problem }]);
    await this.repo.inTransaction(async (tx) => {
      await tx.reviseEstimate(slug, { [`${field}Low`]: low, [`${field}High`]: high }, reason);
      await tx.audit({ actorUserId: actor, action: 'dish.estimate', entity: 'mess_dish', entityId: slug, metadata: { field, low, high, reason } });
    });
  }

  async dishDiet(actor: string | null, slug: string, diet: 'veg' | 'egg' | 'nonveg' | null, reason: string): Promise<void> {
    await this.repo.inTransaction(async (tx) => {
      await tx.setDiet(slug, diet, reason, actor);
      await tx.audit({ actorUserId: actor, action: 'dish.diet', entity: 'mess_dish', entityId: slug, metadata: { diet, reason } });
    });
  }

  /* -------------------------------------------------------------- foods -- */

  async foods(q: string) {
    return (await this.repo.foods(q)).map((f) => ({
      id: f.id, slug: f.slug, name: f.name, source: f.source, isVerified: f.isVerified, adminEditedAt: iso(f.adminEditedAt),
    }));
  }

  async food(id: string): Promise<AdminFood> {
    const r = await this.repo.food(id);
    if (r === null) throw new AppError('NOT_FOUND', 'No such FITOS food.');
    const f = r.food;
    return {
      id: f.id,
      slug: f.slug,
      name: f.name,
      source: f.source,
      sourceRef: f.sourceRef,
      isVerified: f.isVerified,
      adminEditedAt: iso(f.adminEditedAt),
      aliases: r.aliases,
      nutrition: r.rows.map((x) => ({
        basis: x.basis,
        servingLabel: x.servingLabel,
        servingGrams: n(x.servingGrams),
        kcalLow: Number(x.kcalLow), kcalHigh: Number(x.kcalHigh), proteinLow: Number(x.proteinLow), proteinHigh: Number(x.proteinHigh),
        carbLow: Number(x.carbLow), carbHigh: Number(x.carbHigh), fatLow: Number(x.fatLow), fatHigh: Number(x.fatHigh),
        fibreLow: n(x.fibreLow), fibreHigh: n(x.fibreHigh),
        confidence: x.confidence,
      })),
    };
  }

  /** A FITOS food corrected by hand. Logged meals keep the numbers they were logged with (snapshots). */
  async editFood(actor: string | null, id: string, body: EditFood): Promise<AdminFood> {
    const before = await this.food(id);
    if (before.source === 'estimated') {
      if (body.isVerified) throw new AppError('VALIDATION_FAILED', 'An estimate is never verified.', [{ path: 'isVerified', issue: 'estimate' }]);
      if (body.nutrition.some((r) => r.confidence === 'high')) {
        throw new AppError('VALIDATION_FAILED', 'An estimate never has high confidence.', [{ path: 'nutrition', issue: 'estimate' }]);
      }
    }
    await this.repo.inTransaction(async (tx) => {
      await tx.replaceFood(id, {
        name: body.name,
        isVerified: body.isVerified,
        aliases: body.aliases.map(normaliseFoodText).filter((a) => a !== ''),
        nutrition: body.nutrition as unknown as Record<string, unknown>[],
      });
      await tx.audit({
        actorUserId: actor,
        action: 'food.edit',
        entity: 'food',
        entityId: id,
        metadata: { slug: before.slug, reason: body.reason, before: { name: before.name, isVerified: before.isVerified, nutrition: before.nutrition }, after: { name: body.name, isVerified: body.isVerified, nutrition: body.nutrition } },
      });
    });
    return this.food(id);
  }

  /* ---------------------------------------------------------- exercises -- */

  async exercises(q: string, retired: boolean) {
    return (await this.repo.exercises(q, retired)).map((x) => ({
      id: x.id, slug: x.slug, name: x.name, movementPattern: x.movementPattern, equipment: x.equipment, retiredAt: iso(x.retiredAt), adminEditedAt: iso(x.adminEditedAt),
    }));
  }

  async exercise(id: string): Promise<AdminExercise> {
    const r = await this.repo.exercise(id);
    if (r === null) throw new AppError('NOT_FOUND', 'No such exercise.');
    const x = r.exercise;
    return {
      id: x.id,
      slug: x.slug,
      name: x.name,
      movementPattern: x.movementPattern,
      equipment: x.equipment,
      difficulty: x.difficulty,
      isUnilateral: x.isUnilateral,
      defaultIncrementKg: Number(x.defaultIncrementKg),
      instructions: x.instructions,
      videoUrl: x.videoUrl,
      primaryMuscles: r.muscles.filter((m) => m.role === 'primary').map((m) => m.muscleGroup),
      secondaryMuscles: r.muscles.filter((m) => m.role === 'secondary').map((m) => m.muscleGroup),
      contraindications: r.contraindications,
      retiredAt: iso(x.retiredAt),
      adminEditedAt: iso(x.adminEditedAt),
    };
  }

  async createExercise(actor: string | null, body: ExerciseInput): Promise<AdminExercise> {
    if ((await this.repo.exerciseIdBySlug(body.slug)) !== null) {
      throw new AppError('CONFLICT', 'An exercise with that slug exists.', [{ path: 'slug', issue: body.slug }]);
    }
    let id: string;
    try {
      id = await this.repo.inTransaction(async (tx) => {
        const created = await tx.writeExercise(null, body);
        await tx.audit({ actorUserId: actor, action: 'exercise.create', entity: 'exercise', entityId: created, metadata: { slug: body.slug, after: body } });
        return created;
      });
    } catch (e) {
      if (uniqueViolationOf(e) !== null) throw new AppError('CONFLICT', 'An exercise with that slug exists.', [{ path: 'slug', issue: body.slug }]);
      throw e;
    }
    return this.exercise(id);
  }

  async editExercise(actor: string | null, id: string, body: Omit<ExerciseInput, 'slug'>): Promise<AdminExercise> {
    const before = await this.exercise(id);
    await this.repo.inTransaction(async (tx) => {
      await tx.writeExercise(id, body);
      await tx.audit({ actorUserId: actor, action: 'exercise.edit', entity: 'exercise', entityId: id, metadata: { slug: before.slug, before, after: body } });
    });
    return this.exercise(id);
  }

  /** Retired: out of the browser and new programmes; sessions and programmes that have it keep it. */
  async retireExercise(actor: string | null, id: string, retired: boolean): Promise<AdminExercise> {
    const before = await this.exercise(id);
    await this.repo.inTransaction(async (tx) => {
      await tx.setRetired(id, retired);
      await tx.audit({ actorUserId: actor, action: retired ? 'exercise.retire' : 'exercise.restore', entity: 'exercise', entityId: id, metadata: { slug: before.slug } });
    });
    return this.exercise(id);
  }

  /* -------------------------------------------------------------- flags -- */

  async flags() {
    return (await this.repo.flags()).map((f) => ({ key: f.key, enabled: f.enabled, description: f.description, updatedAt: f.updatedAt.toISOString() }));
  }

  async putFlag(actor: string | null, key: string, enabled: boolean, description?: string) {
    const row = await this.repo.inTransaction(async (tx) => {
      const r = await tx.putFlag(key, enabled, description, actor);
      await tx.audit({ actorUserId: actor, action: 'flag.set', entity: 'feature_flag', entityId: key, metadata: { enabled, description: description ?? null } });
      return r;
    });
    return { key: row.key, enabled: row.enabled, description: row.description, updatedAt: row.updatedAt.toISOString() };
  }

  async metaConfig(minimumBuild: number): Promise<{ flags: Record<string, boolean>; minimumBuild: number }> {
    return { flags: Object.fromEntries((await this.repo.flags()).map((f) => [f.key, f.enabled])), minimumBuild };
  }

  /* ------------------------------------------------------------ support -- */

  async lookupUser(actor: string | null, q: { email?: string | undefined; id?: string | undefined }): Promise<UserSupport> {
    const u = q.email !== undefined ? await this.repo.userByEmail(q.email) : await this.repo.userById(q.id!);
    await this.repo.audit({
      actorUserId: actor,
      action: 'user.lookup',
      entity: 'user',
      entityId: u?.id ?? null,
      metadata: { by: q.email !== undefined ? 'email' : 'id', found: u !== null },
    });
    if (u === null) throw new AppError('NOT_FOUND', 'No such user.');
    const facts = await this.repo.supportFacts(u.id, new Date(this.now().getTime() - 7 * 86_400_000));
    const program = await this.training.activeProgram(u.id);
    const settings: NotifySettings = settingsFrom(facts.notificationSettings);
    return {
      userId: u.id,
      email: u.email,
      displayName: u.displayName,
      createdAt: u.createdAt.toISOString(),
      timezone: u.timezone,
      onboardingStage: facts.stage,
      goal: facts.goal,
      programme: program === null ? null : { name: program.program.name, splitType: program.program.splitType },
      counts: {
        sessions: facts.sessions.n,
        foodLogs: facts.foodLogs.n,
        weighIns: facts.weighIns.n,
        checkIns: facts.checkIns.n,
        aiCalls7d: facts.aiCalls7d,
      },
      lastActivity: {
        session: iso(facts.sessions.last),
        foodLog: iso(facts.foodLogs.last),
        weighIn: facts.weighIns.last,
        checkIn: facts.checkIns.last,
      },
      notifications: { enabled: settings.enabled, tone: settings.tone },
    };
  }

  /* -------------------------------------------------------------- audit -- */

  async auditPage(limit: number, before?: string) {
    const rows = await this.repo.auditPage(limit, before === undefined ? null : new Date(before));
    return {
      items: rows.map((r) => ({
        id: r.id,
        actorUserId: r.actorUserId,
        actorEmail: r.actorEmail ?? null,
        action: r.action,
        entity: r.entity,
        entityId: r.entityId,
        metadata: (r.metadata ?? {}) as Record<string, unknown>,
        occurredAt: r.occurredAt.toISOString(),
      })),
      next: rows.length === limit ? rows.at(-1)!.occurredAt.toISOString() : null,
    };
  }
}
