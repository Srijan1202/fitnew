/**
 * Phase 15 — notifications (MASTER-SPEC §21, ADR-021). Gathers the user's
 * own facts, runs core's planner, keeps the ledger. Every rule (timing, cap,
 * back-off, words) is in core `notify/`; this file only reads and writes.
 */
import type { NotifyPlanRequest, NotifyPlanResponse, NotifySettings, NotifySettingsPatch, PlannedNotification } from '@fitos/contracts';
import { TEMPLATES, render } from '@fitos/core/notify/copy';
import { chooseVariant, planNotifications, type NotifyHistoryItem, type PlanFacts, type ReadinessBand } from '@fitos/core/notify/planner';
import { isoWeekday } from '@fitos/core/notify/time';
import { DEFAULT_NOTIFY_SETTINGS, HORIZON_DAYS, NOTIFY_KINDS, PROTEIN_GAP_SHARE, type NotifyKind } from '@fitos/core/notify/types';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';

import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { ReadinessAssembler } from '../recovery/readiness.js';
import type { PlanRepository } from '../running/plan-repository.js';
import type { TrainingRepository } from '../training/repository.js';
import type { NotificationRepository } from './repository.js';

const LOOKBACK_DAYS = 35;
const clock = /^([01]\d|2[0-3]):[0-5]\d$/;

/**
 * Stored settings as the planner reads them: the defaults, overlaid with
 * every stored field that is valid. `notification_settings` is also
 * writable through PATCH /user/preferences (a free-form record), so junk
 * there falls back to the default rather than breaking the plan.
 */
export function settingsFrom(stored: unknown): NotifySettings {
  const s = (stored !== null && typeof stored === 'object' ? stored : {}) as Record<string, unknown>;
  const kinds = (s['kinds'] !== null && typeof s['kinds'] === 'object' ? s['kinds'] : {}) as Record<string, unknown>;
  return {
    enabled: typeof s['enabled'] === 'boolean' ? s['enabled'] : DEFAULT_NOTIFY_SETTINGS.enabled,
    tone: s['tone'] === 'cheeky' || s['tone'] === 'gentle' ? s['tone'] : DEFAULT_NOTIFY_SETTINGS.tone,
    kinds: Object.fromEntries(
      NOTIFY_KINDS.map((k) => [k, typeof kinds[k] === 'boolean' ? (kinds[k] as boolean) : DEFAULT_NOTIFY_SETTINGS.kinds[k]]),
    ) as NotifySettings['kinds'],
    quietStart: typeof s['quietStart'] === 'string' && clock.test(s['quietStart']) ? s['quietStart'] : DEFAULT_NOTIFY_SETTINGS.quietStart,
    quietEnd: typeof s['quietEnd'] === 'string' && clock.test(s['quietEnd']) ? s['quietEnd'] : DEFAULT_NOTIFY_SETTINGS.quietEnd,
  };
}

/**
 * Beta 4.1 (ADR-039 C4/C5): the running plan in the reminders, with the
 * planner unchanged. A plan run's weekday is a training day named after the
 * run ("Easy 5 km in about an hour", "Easy 5 km didn't happen"), unless the
 * gym trains that weekday too: one reminder a day, and the gym session keeps
 * it (Today shows both). A skipped plan run is a skipped day; a day with any
 * run counts as trained. `planned` are the active plan's runs from yesterday
 * to the planner's horizon, earliest first.
 */
export function withRunning(
  gym: Readonly<Record<number, string>> | null,
  skippedDates: readonly string[],
  completedDates: readonly string[],
  planned: readonly { date: string; title: string; status: string }[],
  runDates: readonly string[],
): { programme: Record<number, string> | null; skippedDates: string[]; completedDates: string[] } {
  if (planned.length === 0) {
    return { programme: gym === null ? null : { ...gym }, skippedDates: [...skippedDates], completedDates: [...new Set([...completedDates, ...runDates])] };
  }
  const programme: Record<number, string> = { ...(gym ?? {}) };
  const skipped = [...skippedDates];
  for (const p of planned) {
    const weekday = isoWeekday(p.date);
    if (gym?.[weekday] !== undefined) continue;
    programme[weekday] ??= p.title;
    if (p.status === 'skipped') skipped.push(p.date);
  }
  return { programme, skippedDates: skipped, completedDates: [...new Set([...completedDates, ...runDates])] };
}

export class NotificationService {
  constructor(
    private readonly repo: NotificationRepository,
    private readonly training: TrainingRepository,
    private readonly logs: FoodLogRepository,
    private readonly readiness: ReadinessAssembler,
    private readonly plans: PlanRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async settings(userId: string): Promise<NotifySettings> {
    return settingsFrom(await this.repo.storedSettings(userId));
  }

  async updateSettings(userId: string, patch: NotifySettingsPatch): Promise<NotifySettings> {
    const current = await this.settings(userId);
    const next: NotifySettings = {
      enabled: patch.enabled ?? current.enabled,
      tone: patch.tone ?? current.tone,
      kinds: { ...current.kinds, ...Object.fromEntries(Object.entries(patch.kinds ?? {}).filter(([, v]) => v !== undefined)) },
      quietStart: patch.quietStart ?? current.quietStart,
      quietEnd: patch.quietEnd ?? current.quietEnd,
    };
    await this.repo.saveSettings(userId, next);
    return next;
  }

  /** The user's facts for the planner, at `now`. */
  async facts(userId: string, now: Date): Promise<PlanFacts> {
    const timeZone = await this.logs.timezoneOf(userId);
    const today = localDateOf(now, timeZone);
    const sinceDate = addDays(today, -LOOKBACK_DAYS);
    const since = new Date(now.getTime() - (LOOKBACK_DAYS + 1) * 86_400_000);

    const [settings, name, program, sessions, foodLogs, weighIns, checkIns, proteinDays, targets, history, assessment, planned, runs] = await Promise.all([
      this.settings(userId),
      this.repo.displayName(userId),
      this.training.activeProgram(userId),
      this.repo.sessionsSince(userId, since),
      this.repo.foodLogsSince(userId, since),
      this.repo.weighInsSince(userId, sinceDate),
      this.repo.checkInsSince(userId, sinceDate),
      this.repo.proteinDays(userId, sinceDate),
      this.logs.targetsOn(userId, today),
      this.repo.history(userId, sinceDate),
      this.readiness.assess(userId, today, timeZone),
      this.plans.between(userId, addDays(today, -1), addDays(today, HORIZON_DAYS)),
      this.plans.loads(userId, since),
    ]);

    const proteinTargetG = targets?.proteinG ?? null;
    const goal = proteinTargetG === null ? null : Math.ceil(proteinTargetG * PROTEIN_GAP_SHARE);
    const gym = program === null ? null : Object.fromEntries(program.days.filter((d) => !d.isRest).map((d) => [d.dayOfWeek, d.sessionName]));
    const { programme, skippedDates, completedDates } = withRunning(
      gym,
      program === null || program.program.skippedOn === null ? [] : [program.program.skippedOn],
      sessions.filter((s) => s.completedAt !== null).map((s) => localDateOf(s.completedAt!, timeZone)),
      planned,
      runs.map((r) => localDateOf(r.startedAt, timeZone)),
    );

    return {
      now,
      timeZone,
      seed: userId,
      name,
      settings,
      programme,
      skippedDates,
      sessionStarts: sessions.map((s) => s.startedAt),
      completedDates,
      foodLogs,
      weighIns,
      checkIns,
      proteinMetDates: goal === null ? [] : proteinDays.filter((d) => d.proteinHigh >= goal).map((d) => d.localDate),
      proteinTargetG,
      todayProteinHigh: proteinDays.find((d) => d.localDate === today)?.proteinHigh ?? 0,
      readinessBand: (assessment.readiness?.band ?? null) as ReadinessBand | null,
      history: history.map(
        (h): NotifyHistoryItem => ({ kind: h.kind as NotifyKind, localDate: h.localDate, variant: h.variant, at: h.sentAt ?? h.scheduledFor, status: h.status }),
      ),
    };
  }

  /** Apply the phone's reports, plan the next days, keep the ledger, return the plan. */
  async plan(userId: string, request: NotifyPlanRequest): Promise<NotifyPlanResponse> {
    const now = this.now();
    await this.repo.applyEvents(
      userId,
      request.events.map((e) => ({ id: e.id, event: e.event, at: new Date(e.at) })),
    );
    const facts = await this.facts(userId, now);
    const planned = planNotifications(facts);
    const rows = await this.repo.replacePlan(
      userId,
      now,
      planned.map((p) => ({ kind: p.kind, localDate: p.localDate, scheduledFor: p.at, variant: p.variant, title: p.title, body: p.body })),
    );
    const idOf = new Map(rows.map((r) => [`${r.kind}|${r.localDate}`, r.id]));
    const items: PlannedNotification[] = [];
    for (const p of planned) {
      const id = idOf.get(`${p.kind}|${p.localDate}`);
      if (id === undefined) continue; // already reported on; not re-sent
      items.push({
        id,
        kind: p.kind,
        localDate: p.localDate,
        at: p.at.toISOString(),
        title: p.title,
        body: p.body,
        variant: p.variant,
        tone: p.tone,
        screen: p.screen,
        slot: p.slot,
        actions: [...p.actions],
        cancelOn: p.cancelOn.map((c) => ({ ...c })),
        why: p.why,
      });
    }
    return { generatedAt: now.toISOString(), timeZone: facts.timeZone, settings: facts.settings, items };
  }

  /** The words a kind would use now, in the user's tone, with their data — nothing stored. */
  async preview(userId: string, kind: NotifyKind): Promise<{ title: string; body: string }> {
    const now = this.now();
    const facts = await this.facts(userId, now);
    const today = localDateOf(now, facts.timeZone);
    const session = Object.values(facts.programme ?? {})[0] ?? 'Push';
    const data = { name: facts.name, session, target: facts.proteinTargetG, streak: null, sessions: null, planned: null };
    const stage = kind === 'comeback' ? 2 : undefined;
    const template =
      chooseVariant(kind, facts.settings.tone, data, stage, facts.history.map((h) => ({ ...h })), today, `${userId}|preview|${now.getTime()}`) ??
      TEMPLATES.find((t) => t.kind === kind && t.tone === facts.settings.tone)!;
    return render(template, data);
  }

  async registerToken(userId: string, token: string): Promise<void> {
    await this.repo.saveToken(userId, token, 'android');
  }
}
