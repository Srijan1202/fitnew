'use client';

import type { AdminAccount } from '@fitos/contracts';
import { useState, type FormEvent } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/** ADR-022 D2 amendment: who is an administrator; make another account one, or take it away. */
export default function Admins() {
  const { data, error, loading, reload } = useGet<{ items: AdminAccount[] }>('/admin/admins');
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const grant = async (e: FormEvent) => {
    e.preventDefault();
    const address = email.trim();
    if (address === '') return;
    if (!window.confirm(`Make ${address} an administrator? They can change foods, exercises, mess data, flags and Premium, and make other administrators.`)) return;
    setBusy(true);
    setActionError(null);
    setDone(null);
    try {
      const a = await api<AdminAccount>('POST', '/admin/admins', { email: address });
      setDone(`${a.email ?? address} is now an administrator. They sign out and in again (or wait up to an hour) to see it.`);
      setEmail('');
      reload();
    } catch (err) {
      setActionError(errorText(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async (a: AdminAccount) => {
    if (!window.confirm(`Take the admin role away from ${a.email ?? a.firebaseUid}? They are signed out everywhere at once and sign in again as a normal user.`)) return;
    setBusy(true);
    setActionError(null);
    setDone(null);
    try {
      await api('DELETE', `/admin/admins/${encodeURIComponent(a.firebaseUid)}`);
      setDone(`${a.email ?? a.firebaseUid} is no longer an administrator.`);
      reload();
    } catch (err) {
      setActionError(errorText(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <Header eyebrow="Admins" title="Administrators">
        Administrators use this panel and have Premium by role. The account must have signed in to FITOS once. Every change is in the audit log. You
        cannot remove yourself, so there is always at least one administrator.
      </Header>

      <form className="row" onSubmit={(e) => void grant(e)}>
        <input type="email" required maxLength={254} placeholder="their@email.com" value={email} onChange={(e) => setEmail(e.target.value)} disabled={busy} />
        <button className="button primary" type="submit" disabled={busy || email.trim() === ''}>Make administrator</button>
      </form>
      {done !== null && <p className="ok">{done}</p>}
      {actionError !== null && <p className="error">{actionError}</p>}

      <Status error={error} loading={loading && data === null} />
      {data !== null && (
        <table>
          <thead><tr><th>Account</th><th>Last sign-in</th><th /></tr></thead>
          <tbody>
            {data.items.map((a) => (
              <tr key={a.firebaseUid}>
                <td>
                  {a.email ?? <span className="muted">no email</span>} {a.isYou && <Badge tone="ok">you</Badge>}
                  {a.userId === null && <div className="muted small">has not used FITOS yet</div>}
                </td>
                <td>{a.lastSignInAt === null ? '—' : when(a.lastSignInAt)}</td>
                <td>{!a.isYou && <button className="button" disabled={busy} onClick={() => void remove(a)}>Remove</button>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}
