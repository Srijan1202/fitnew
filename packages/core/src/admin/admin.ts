/**
 * Phase 16 — the deterministic rules behind the admin panel (MASTER-SPEC
 * §20, ADR-022): endpoint health and staleness, applying a reviewed dish
 * correction, diet overrides on a served menu, and the acceptance-rate
 * dashboards. The API only gathers rows and applies these.
 */
import type { DietClass, MessDay } from '../mess/types.js';

/* ------------------------------------------------------ provider health -- */

/** A menu endpoint publishes daily; a day and a bit without success is stale. */
export const STALE_AFTER_HOURS = 26;
/** This many failures in a row is failing, whatever the last success. */
export const FAILING_AFTER = 3;

export type EndpointState = 'ok' | 'stale' | 'failing' | 'never';

export interface EndpointFacts {
  readonly lastSuccessAt: Date | null;
  readonly consecutiveFailures: number;
}

export function endpointHealth(facts: EndpointFacts, now: Date): { state: EndpointState; hoursSinceSuccess: number | null } {
  const hours = facts.lastSuccessAt === null ? null : Math.max(0, (now.getTime() - facts.lastSuccessAt.getTime()) / 3_600_000);
  if (facts.consecutiveFailures >= FAILING_AFTER) return { state: 'failing', hoursSinceSuccess: hours === null ? null : Math.round(hours * 10) / 10 };
  if (hours === null) return { state: 'never', hoursSinceSuccess: null };
  return { state: hours > STALE_AFTER_HOURS ? 'stale' : 'ok', hoursSinceSuccess: Math.round(hours * 10) / 10 };
}

/* ------------------------------------------------------ dish corrections -- */

export type MacroField = 'kcal' | 'protein' | 'carb' | 'fat';

export interface MacroRanges {
  readonly kcalLow: number;
  readonly kcalHigh: number;
  readonly proteinLow: number;
  readonly proteinHigh: number;
  readonly carbLow: number;
  readonly carbHigh: number;
  readonly fatLow: number;
  readonly fatHigh: number;
}

/** Per-serving sanity: a reviewer's slip (an extra zero) is refused, not stored. */
export const DISH_BOUNDS: Readonly<Record<MacroField, number>> = { kcal: 3000, protein: 200, carb: 400, fat: 200 };

export type CorrectionResult = { readonly ok: true; readonly ranges: MacroRanges } | { readonly ok: false; readonly problem: string };

/**
 * One field of a dish estimate set to a reviewed range; every other field
 * kept. Ranges stay ordered and non-negative, within DISH_BOUNDS.
 */
export function applyCorrection(current: MacroRanges, field: MacroField, low: number, high: number): CorrectionResult {
  if (!Number.isFinite(low) || !Number.isFinite(high)) return { ok: false, problem: 'not a number' };
  if (low < 0) return { ok: false, problem: 'negative' };
  if (low > high) return { ok: false, problem: 'low above high' };
  if (high > DISH_BOUNDS[field]) return { ok: false, problem: `above ${DISH_BOUNDS[field]} per serving` };
  const round = (v: number): number => Math.round(v * 100) / 100;
  return { ok: true, ranges: { ...current, [`${field}Low`]: round(low), [`${field}High`]: round(high) } as MacroRanges };
}

/**
 * A served menu with reviewed diet corrections applied by dish slug — the
 * same slug on any day, any mess (§20: "corrections apply to future menus
 * by slug"). Nothing stored is changed; a dish without an override keeps
 * the parser's class.
 */
export function applyDietOverrides(day: MessDay, overrides: ReadonlyMap<string, DietClass>): MessDay {
  if (overrides.size === 0) return day;
  return {
    ...day,
    meals: day.meals.map((m) => ({
      ...m,
      dishes: m.dishes.map((d) => {
        const diet = overrides.get(d.id);
        return diet === undefined || diet === d.diet ? d : { ...d, diet };
      }),
    })),
  };
}

/* ----------------------------------------------------------- dashboards -- */

/** A share to one decimal place of a percent; null when nothing to divide by. */
export function rate(part: number, whole: number): number | null {
  return whole <= 0 ? null : Math.round((part / whole) * 1000) / 10;
}

export interface FunnelRow {
  readonly kind: string;
  readonly counts: Readonly<Record<string, number>>;
}

/**
 * TODAY actions (§16): per kind, how often what was shown was opened,
 * accepted, dismissed, completed — the recommendation acceptance rates §20
 * asks for. Counts are distinct actions reaching each event.
 */
export function recommendationRates(rows: readonly { kind: string; event: string; n: number }[]): {
  kind: string;
  shown: number;
  opened: number;
  accepted: number;
  dismissed: number;
  completed: number;
  acceptRate: number | null;
  dismissRate: number | null;
  completeRate: number | null;
}[] {
  const kinds = [...new Set(rows.map((r) => r.kind))].sort();
  const count = (kind: string, event: string): number => rows.filter((r) => r.kind === kind && r.event === event).reduce((s, r) => s + r.n, 0);
  return kinds.map((kind) => {
    const shown = count(kind, 'shown');
    const accepted = count(kind, 'accepted');
    const dismissed = count(kind, 'dismissed');
    const completed = count(kind, 'completed');
    return {
      kind,
      shown,
      opened: count(kind, 'opened'),
      accepted,
      dismissed,
      completed,
      acceptRate: rate(accepted, shown),
      dismissRate: rate(dismissed, shown),
      completeRate: rate(completed, shown),
    };
  });
}

/** Phase 15 reminders: per kind, sent (delivered or opened), opened, cancelled on the phone. */
export function notificationRates(rows: readonly { kind: string; status: string; n: number }[]): {
  kind: string;
  sent: number;
  opened: number;
  cancelled: number;
  openRate: number | null;
}[] {
  const kinds = [...new Set(rows.map((r) => r.kind))].sort();
  const count = (kind: string, status: string): number => rows.filter((r) => r.kind === kind && r.status === status).reduce((s, r) => s + r.n, 0);
  return kinds.map((kind) => {
    const opened = count(kind, 'opened');
    const sent = count(kind, 'delivered') + opened;
    return { kind, sent, opened, cancelled: count(kind, 'cancelled'), openRate: rate(opened, sent) };
  });
}
