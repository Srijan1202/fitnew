/**
 * Administrators managed in the panel (ADR-022 D2 amendment): one
 * administrator makes another account an administrator, or takes it away.
 *
 * - The account must already exist in Firebase (it signed in to FITOS once).
 * - A grant takes effect when that account's token refreshes (sign out and
 *   in, or within the hour). A removal takes effect at once: its sessions
 *   are revoked, and the API checks revocation on every token.
 * - Nobody removes themselves, so there is always at least one administrator.
 * - Each change writes its audit row in a transaction that commits only
 *   after Firebase accepted the change.
 */
import type { AdminAccount } from '@fitos/contracts';

import type { AdminDirectory, DirectoryAccount } from '../../lib/admin-directory.js';
import { AppError } from '../../lib/errors.js';
import type { AdminRepository } from './repository.js';

export class AdministratorsService {
  constructor(
    private readonly repo: AdminRepository,
    private readonly directory: AdminDirectory,
  ) {}

  private async out(accounts: readonly DirectoryAccount[], meUid: string): Promise<AdminAccount[]> {
    const ids = await this.repo.userIdsByFirebaseUid(accounts.map((a) => a.uid));
    return accounts.map((a) => ({
      firebaseUid: a.uid,
      email: a.email,
      userId: ids.get(a.uid) ?? null,
      lastSignInAt: a.lastSignInAt?.toISOString() ?? null,
      isYou: a.uid === meUid,
    }));
  }

  async list(meUid: string): Promise<AdminAccount[]> {
    const admins = await this.directory.listAdmins();
    admins.sort((a, b) => (a.email ?? a.uid).localeCompare(b.email ?? b.uid));
    return this.out(admins, meUid);
  }

  async grant(actorUserId: string | null, meUid: string, email: string): Promise<AdminAccount> {
    const account = await this.directory.findByEmail(email);
    if (account === null) {
      throw new AppError('NOT_FOUND', 'No FITOS account uses this email. They need to sign in to FITOS once first.', [{ path: 'email', issue: 'no account' }]);
    }
    if (account.admin) throw new AppError('CONFLICT', 'This account is already an administrator.', [{ path: 'email', issue: 'already admin' }]);
    await this.repo.inTransaction(async (repo) => {
      await repo.audit({ actorUserId, action: 'admin.grant', entity: 'account', entityId: account.uid, metadata: { email: account.email } });
      await this.directory.setAdmin(account.uid, true);
    });
    const [granted] = await this.out([{ ...account, admin: true }], meUid);
    return granted!;
  }

  async revoke(actorUserId: string | null, meUid: string, uid: string): Promise<void> {
    if (uid === meUid) throw new AppError('CONFLICT', 'You cannot remove yourself. Ask another administrator.', [{ path: 'uid', issue: 'self' }]);
    const account = await this.directory.findByUid(uid);
    if (account === null || !account.admin) throw new AppError('NOT_FOUND', 'This account is not an administrator.');
    await this.repo.inTransaction(async (repo) => {
      await repo.audit({ actorUserId, action: 'admin.revoke', entity: 'account', entityId: uid, metadata: { email: account.email } });
      await this.directory.setAdmin(uid, false);
    });
    // After the claim is gone: the next token it gets carries no admin role.
    await this.directory.revokeSessions(uid);
  }
}
