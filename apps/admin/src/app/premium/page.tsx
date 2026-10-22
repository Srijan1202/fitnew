'use client';

import type { AdminPremiumMember, AdminPremiumRequest } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Badge, Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

type Filter = 'pending' | 'approved' | 'denied' | 'all';

/** Phase 19 (ADR-027): who asked for premium, the decision, and who has it. */
export default function Premium() {
  const [filter, setFilter] = useState<Filter>('pending');
  const [requests, setRequests] = useState<AdminPremiumRequest[]>([]);
  const [members, setMembers] = useState<AdminPremiumMember[]>([]);
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = async () => {
    setError(null);
    try {
      const status = filter === 'all' ? '' : `?status=${filter}`;
      const [r, m] = await Promise.all([
        api<{ items: AdminPremiumRequest[] }>('GET', `/admin/premium/requests${status}`),
        api<{ items: AdminPremiumMember[] }>('GET', '/admin/premium/members'),
      ]);
      setRequests(r.items);
      setMembers(m.items);
    } catch (e) {
      setError(errorText(e));
    }
  };

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  const decide = async (id: string, decision: 'approve' | 'deny') => {
    setBusy(true);
    setError(null);
    try {
      const note = notes[id]?.trim();
      await api('POST', `/admin/premium/requests/${id}/decision`, { decision, ...(note ? { note } : {}) });
      await load();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  };

  const revoke = async (m: AdminPremiumMember) => {
    if (!window.confirm(`Take premium away from ${m.email ?? m.userId}? A premium profile picture goes back to none.`)) return;
    setBusy(true);
    setError(null);
    try {
      await api('POST', `/admin/premium/members/${m.userId}/revoke`);
      await load();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <Header eyebrow="Premium" title="Requests and members">
        Approving gives FITOS AI (with higher limits), the weekly report, the colour themes and the three premium pictures, until you revoke it.
        Admins are premium by role. Every decision is audited.
      </Header>
      {error !== null && <p className="error">{error}</p>}

      <h2>Requests</h2>
      <p>
        {(['pending', 'approved', 'denied', 'all'] as const).map((f) => (
          <button key={f} className={`button${filter === f ? ' active' : ''}`} disabled={busy} onClick={() => setFilter(f)}>{f}</button>
        ))}
      </p>
      <table>
        <thead><tr><th>When</th><th>Who</th><th>Their message</th><th>Status</th><th>Note to them</th><th /></tr></thead>
        <tbody>
          {requests.map((r) => (
            <tr key={r.id}>
              <td>{when(r.createdAt)}</td>
              <td>{r.displayName ?? '—'}<div className="muted small">{r.email ?? r.userId}</div></td>
              <td style={{ whiteSpace: 'pre-wrap', maxWidth: '28rem' }}>{r.message ?? <span className="muted">—</span>}</td>
              <td>
                <Badge tone={r.status === 'pending' ? 'warn' : r.status === 'approved' ? 'ok' : 'muted'}>{r.status}</Badge>
                {r.decidedAt !== null && <div className="muted small">{when(r.decidedAt)}</div>}
              </td>
              <td>
                {r.status === 'pending' ? (
                  <input
                    maxLength={300}
                    placeholder="Optional"
                    value={notes[r.id] ?? ''}
                    onChange={(e) => setNotes((n) => ({ ...n, [r.id]: e.target.value }))}
                  />
                ) : (
                  <span className="small">{r.note ?? '—'}</span>
                )}
              </td>
              <td>
                {r.status === 'pending' && (
                  <>
                    <button className="button" disabled={busy} onClick={() => void decide(r.id, 'approve')}>Approve</button>
                    <button className="button" disabled={busy} onClick={() => void decide(r.id, 'deny')}>Deny</button>
                  </>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {requests.length === 0 && <p className="muted">Nothing here.</p>}

      <h2>Members</h2>
      <table>
        <thead><tr><th>Who</th><th>Since</th><th>Approved by</th><th /></tr></thead>
        <tbody>
          {members.map((m) => (
            <tr key={m.userId}>
              <td>{m.displayName ?? '—'}<div className="muted small">{m.email ?? m.userId}</div></td>
              <td>{when(m.since)}</td>
              <td className="small">{m.grantedBy ?? '—'}</td>
              <td><button className="button" disabled={busy} onClick={() => void revoke(m)}>Revoke</button></td>
            </tr>
          ))}
        </tbody>
      </table>
      {members.length === 0 && <p className="muted">No one yet (admins are premium by role and are not listed).</p>}
    </>
  );
}
