'use client';

import type { AuditEntry, AuditList } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/** §20: every admin action, newest first. */
export default function Audit() {
  const [items, setItems] = useState<AuditEntry[]>([]);
  const [next, setNext] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async (before: string | null) => {
    setLoading(true);
    setError(null);
    try {
      const page = await api<AuditList>('GET', `/admin/audit?limit=50${before === null ? '' : `&before=${encodeURIComponent(before)}`}`);
      setItems((xs) => (before === null ? page.items : [...xs, ...page.items]));
      setNext(page.next);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load(null);
  }, []);

  return (
    <>
      <Header eyebrow="Audit" title="Audit log">Every change made here, and every account lookup, with who did it.</Header>
      {error !== null && <p className="error">{error}</p>}
      <table>
        <thead><tr><th>When</th><th>Who</th><th>Action</th><th>On</th><th>Details</th></tr></thead>
        <tbody>
          {items.map((a) => (
            <tr key={a.id}>
              <td>{when(a.occurredAt)}</td>
              <td>{a.actorEmail ?? a.actorUserId ?? '—'}</td>
              <td><code>{a.action}</code></td>
              <td>{a.entity}{a.entityId !== null && <div className="muted small">{a.entityId}</div>}</td>
              <td><details><summary className="small">view</summary><pre className="small">{JSON.stringify(a.metadata, null, 2)}</pre></details></td>
            </tr>
          ))}
        </tbody>
      </table>
      {items.length === 0 && !loading && <p className="muted">Nothing yet.</p>}
      {next !== null && <button className="button" disabled={loading} onClick={() => void load(next)}>Older</button>}
    </>
  );
}
