/**
 * Beta 3.3 (ADR-033): the app features the admin panel switches on and off.
 * The list is `APP_FEATURES` in contracts; a feature is on unless its
 * `feature_flags` row says otherwise, so a new switch needs no migration.
 * Read through a short cache (every request would otherwise hit the table);
 * the admin route clears it when a switch changes, and other instances catch
 * up within the cache's lifetime.
 */
import { APP_FEATURES, type AppFeature } from '@fitos/contracts';
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

export class FeatureSwitches {
  private cached: { at: number; rows: Map<string, boolean> } | null = null;

  constructor(
    private readonly db: () => Db,
    private readonly now: () => number = Date.now,
  ) {}

  /** Every stored flag (switches and any other flag the admin added). */
  async stored(): Promise<Map<string, boolean>> {
    if (this.cached !== null && this.now() - this.cached.at < TTL_MS) return this.cached.rows;
    const rows = await this.db().select({ key: featureFlags.key, enabled: featureFlags.enabled }).from(featureFlags);
    const map = new Map(rows.map((r) => [r.key, r.enabled]));
    this.cached = { at: this.now(), rows: map };
    return map;
  }

  async isOn(feature: AppFeature): Promise<boolean> {
    return (await this.stored()).get(feature) ?? true;
  }

  /** Throws 403 `feature-off` when the feature is switched off. */
  async require(feature: AppFeature): Promise<void> {
    if (!(await this.isOn(feature))) throw featureOff(feature);
  }

  /** Every flag the app may read: each switch (on unless stored off), then the other stored flags. */
  async config(): Promise<Record<string, boolean>> {
    const stored = await this.stored();
    const out: Record<string, boolean> = {};
    for (const key of Object.keys(APP_FEATURES)) out[key] = stored.get(key) ?? true;
    for (const [key, enabled] of stored) if (!(key in out)) out[key] = enabled;
    return out;
  }

  invalidate(): void {
    this.cached = null;
  }
}
