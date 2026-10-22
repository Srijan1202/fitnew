'use client';

import { FEEDBACK_STATUSES, type AdminFeedbackItem, type AdminFeedbackList, type FeedbackStatus } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Badge, Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

const TONE: Record<FeedbackStatus, 'warn' | 'muted' | 'ok'> = { new: 'warn', read: 'muted', done: 'ok' };

/** Phase 19 (ADR-026): what beta testers sent from the app, newest first. */
export default function Feedback() {
  const [filter, setFilter] = useState<FeedbackStatus | 'all'>('new');
  const [items, setItems] = useState<AdminFeedbackItem[]>([]);
  const [next, setNext] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async (before: string | null) => {
    setLoading(true);
    setError(null);
    try {
      const status = filter === 'all' ? '' : `&status=${filter}`;
      const page = await api<AdminFeedbackList>('GET', `/admin/feedback?limit=50${status}${before === null ? '' : `&before=${encodeURIComponent(before)}`}`);
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  const mark = async (id: string, status: FeedbackStatus) => {
    setError(null);
    try {
      const updated = await api<AdminFeedbackItem>('PATCH', `/admin/feedback/${id}`, { status });
      setItems((xs) => (filter === 'all' || filter === status ? xs.map((x) => (x.id === id ? updated : x)) : xs.filter((x) => x.id !== id)));
    } catch (e) {
      setError(errorText(e));
    }
  };

  return (
    <>
      <Header eyebrow="Feedback" title="From the app">
        What testers sent from Profile → Send feedback. The sender is an id: look them up under Support if you need to reply. Marking is audited.
      </Header>
      <p>
        {(['new', 'read', 'done', 'all'] as const).map((f) => (
          <button key={f} className={`button${filter === f ? ' active' : ''}`} disabled={loading} onClick={() => setFilter(f)}>{f}</button>
        ))}
      </p>
      {error !== null && <p className="error">{error}</p>}
      <table>
        <thead><tr><th>When</th><th>Category</th><th>Message</th><th>App</th><th>Status</th><th /></tr></thead>
        <tbody>
          {items.map((f) => (
            <tr key={f.id}>
              <td>{when(f.createdAt)}<div className="muted small"><code title="Paste into Support to look the sender up">{f.userId}</code></div></td>
              <td>{f.category}</td>
              <td style={{ whiteSpace: 'pre-wrap', maxWidth: '40rem' }}>{f.message}</td>
              <td className="small">{f.appVersion}</td>
              <td><Badge tone={TONE[f.status]}>{f.status}</Badge></td>
              <td>
                {FEEDBACK_STATUSES.filter((s) => s !== f.status).map((s) => (
                  <button key={s} className="button small" onClick={() => void mark(f.id, s)}>{s}</button>
                ))}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {items.length === 0 && !loading && <p className="muted">Nothing here.</p>}
      {next !== null && <button className="button" disabled={loading} onClick={() => void load(next)}>Older</button>}
    </>
  );
}
