/**
 * Phase 17 — privacy (MASTER-SPEC §23, ADR-023): consent per purpose, the
 * export (portability) and deletion (erasure, immediate — owner D2).
 */
import {
  CONSENT_TYPES,
  CURRENT_POLICY_VERSION,
  REQUIRED_CONSENT_TYPES,
  type ConsentsResponse,
  type ConsentType,
  type DataExport,
} from '@fitos/contracts';

import type { AccountDeleter } from '../../lib/account-deleter.js';
import { AppError } from '../../lib/errors.js';
import { hashIp } from '../onboarding/service.js';
import type { PrivacyRepository } from './repository.js';

const REQUIRED: ReadonlySet<string> = new Set(REQUIRED_CONSENT_TYPES);

export const EXPORT_NOTES = [
  'FITOS data export (MASTER-SPEC §23.4). Every table that holds rows you own, by table name; each row as stored.',
  'Times are UTC (ISO 8601). Local dates (local_date, logged_on, measured_on) are in your stored time zone.',
  'Nutrition values are ranges (low/high) because FITOS estimates; a logged item keeps the numbers it was logged with.',
  'Runs: track_points is the GPS route in FITOS track encoding v1 (polyline-style: lat/lon ×1e6, elevation ×10, seconds ×10); the app exports any run as GPX.',
  'Not included: the shared FITOS food and exercise libraries and mess menus (not yours), and records about other people.',
];

export class PrivacyService {
  constructor(
    private readonly repo: PrivacyRepository,
    private readonly deleter: AccountDeleter,
    private readonly log: { info: (o: Record<string, unknown>, m: string) => void; warn: (o: Record<string, unknown>, m: string) => void },
    private readonly now: () => Date = () => new Date(),
  ) {}

  async consents(userId: string): Promise<ConsentsResponse> {
    const latest = await this.repo.latestConsents(userId);
    const items = CONSENT_TYPES.map((type) => {
      const r = latest.get(type);
      return { type, granted: r?.granted ?? false, policyVersion: r?.policyVersion ?? null, at: r?.at.toISOString() ?? null, required: REQUIRED.has(type) };
    });
    const needsReconsent = items.some((i) => i.required && (!i.granted || i.policyVersion !== CURRENT_POLICY_VERSION));
    return { currentPolicyVersion: CURRENT_POLICY_VERSION, needsReconsent, items };
  }

  /**
   * §23.1: specific, revocable consent per purpose, each change a new record
   * with the policy version. A required purpose can be re-granted (a policy
   * update) but not withdrawn here — FITOS cannot run without it; deleting
   * the account is the way out.
   */
  async setConsent(userId: string, type: ConsentType, granted: boolean, ctx: { ip: string; ipSalt: string }): Promise<ConsentsResponse> {
    if (REQUIRED.has(type) && !granted) {
      throw new AppError('VALIDATION_FAILED', 'FITOS needs this to work. To stop it, delete your account.', [{ path: 'type', issue: 'required' }]);
    }
    await this.repo.recordConsent(userId, type, granted, CURRENT_POLICY_VERSION, hashIp(ctx.ip, ctx.ipSalt));
    return this.consents(userId);
  }

  async export(userId: string): Promise<DataExport> {
    const tables = await this.repo.ownedRows(userId);
    this.log.info({ tables: Object.keys(tables).length }, 'privacy: export');
    return { format: 'fitos-export', version: 1, exportedAt: this.now().toISOString(), userId, notes: EXPORT_NOTES, tables };
  }

  /** §23.3: every row now; then the Firebase sign-in. Nothing to undo. */
  async deleteAccount(userId: string): Promise<{ deleted: true; signInRemoved: boolean }> {
    const firebaseUid = await this.repo.firebaseUid(userId);
    if (firebaseUid === null) throw new AppError('NOT_FOUND', 'No such account.');
    await this.repo.deleteUser(userId);
    let signInRemoved = true;
    try {
      await this.deleter.deleteAccount(firebaseUid);
    } catch (e) {
      // FITOS holds nothing of the user now; the sign-in can be removed by support.
      signInRemoved = false;
      this.log.warn({ code: (e as { code?: string }).code ?? null }, 'privacy: Firebase account not removed');
    }
    this.log.info({ signInRemoved }, 'privacy: account deleted');
    return { deleted: true, signInRemoved };
  }
}
