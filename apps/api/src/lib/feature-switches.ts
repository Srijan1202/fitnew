/**
 * Beta 3.3 (ADR-033): the app features the admin panel switches on and off.
 * The list is `APP_FEATURES` in contracts; a feature is on unless its
 * `feature_flags` row says otherwise, so a new switch needs no migration.
 * Read through a short cache (every request would otherwise hit the table);
 * the admin route clears it when a switch changes, and other instances catch
 * up within the cache's lifetime.
 *
 * Beta 6.1 (early access): an on switch is on for `everyone` or for
 * `premium` accounts only (admins are premium by role). The server decides
 * per request; the public config reads an early-access switch as off.
 */
import { APP_FEATURES, type AppFeature, type FlagAudience } from '@fitos/contracts';
import { featureFlags } from '../db/schema.js';
import type { DatabaseHandle } from '../db/client.js';
import { AppError } from './errors.js';

declare module 'fastify' {
  interface FastifyInstance {
    features: FeatureSwitches;
  }
}

type Db = DatabaseHandle['db'];

const TTL_MS = 10_000;

export const isAppFeature = (key: string): key is AppFeature => Object.hasOwn(APP_FEATURES, key);

/** 403 `feature-off`: the admin switched this feature off. */
export const featureOff = (feature: AppFeature): AppError =>
  new AppError('FORBIDDEN', `${APP_FEATURES[feature].name} is switched off for now.`, [{ path: 'feature', issue: 'feature-off' }]);

/** 403 `early-access`: on, but only for premium accounts for now. */
export const earlyAccessOnly = (feature: AppFeature): AppError =>
  new AppError('FORBIDDEN', `${APP_FEATURES[feature].name} is in early access for FITOS Premium. Ask for Premium in Profile → Premium.`, [
    { path: 'feature', issue: 'early-access' },
  ]);

export type SwitchState = 'off' | FlagAudience;

/** Who is asking: a request's user and its token's claims. */
export interface Asker {
  readonly userId: string | null;
  readonly identity?: { readonly claims?: Readonly<Record<string, unknown>> } | null;
}

/** Premium, as PremiumService decides it (granted, or an admin by role). */
export type PremiumCheck = (userId: string, claims: Readonly<Record<string, unknown>> | undefined) => Promise<boolean>;

export class FeatureSwitches {
  private cached: { at: number; rows: Map<string, SwitchState> } | null = null;

  constructor(
    private readonly db: () => Db,
    private readonly premium: PremiumCheck = async () => false,
    private readonly now: () => number = Date.now,
  ) {}

  /** Every stored flag (switches and any other flag the admin added). */
  async stored(): Promise<Map<string, SwitchState>> {
    if (this.cached !== null && this.now() - this.cached.at < TTL_MS) return this.cached.rows;
    const rows = await this.db().select({ key: featureFlags.key, enabled: featureFlags.enabled, audience: featureFlags.audience }).from(featureFlags);
    const map = new Map(rows.map((r): [string, SwitchState] => [r.key, r.enabled ? r.audience : 'off']));
    this.cached = { at: this.now(), rows: map };
    return map;
  }

  async state(feature: AppFeature): Promise<SwitchState> {
    return (await this.stored()).get(feature) ?? 'everyone';
  }

  private async premiumAsker(who: Asker | undefined): Promise<boolean> {
    if (who === undefined || who.userId === null) return false;
    return this.premium(who.userId, who.identity?.claims);
  }

  /** On for this user: on for everyone, or early access and [userId] is premium (a read that only shows or hides something). */
  async isOn(feature: AppFeature, userId?: string | null): Promise<boolean> {
    const state = await this.state(feature);
    if (state === 'everyone') return true;
    return state === 'premium' && (await this.premiumAsker({ userId: userId ?? null }));
  }

  /** Throws 403 `feature-off` when off, and 403 `early-access` when on for premium only and [who] is not. */
  async require(feature: AppFeature, who?: Asker): Promise<void> {
    const state = await this.state(feature);
    if (state === 'off') throw featureOff(feature);
    if (state === 'premium' && !(await this.premiumAsker(who))) throw earlyAccessOnly(feature);
  }

  /** Every flag the app may read before sign-in: each switch (on unless stored off; early access reads off), then the other stored flags. */
  async config(): Promise<Record<string, boolean>> {
    const stored = await this.stored();
    const out: Record<string, boolean> = {};
    for (const key of Object.keys(APP_FEATURES)) out[key] = (stored.get(key) ?? 'everyone') === 'everyone';
    for (const [key, state] of stored) if (!(key in out)) out[key] = state === 'everyone';
    return out;
  }

  /** The flags as they are for [who]; `earlyAccess` names those on only because [who] is premium. */
  async configFor(who: Asker): Promise<{ flags: Record<string, boolean>; earlyAccess: string[] }> {
    const stored = await this.stored();
    const flags = await this.config();
    const early = [...stored].filter(([, state]) => state === 'premium').map(([key]) => key);
    if (early.length === 0 || !(await this.premiumAsker(who))) return { flags, earlyAccess: [] };
    for (const key of early) flags[key] = true;
    return { flags, earlyAccess: early.sort() };
  }

  invalidate(): void {
    this.cached = null;
  }
}
