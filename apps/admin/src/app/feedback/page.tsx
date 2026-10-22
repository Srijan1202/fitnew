'use client';

import {
  FEEDBACK_PRIORITIES,
  FEEDBACK_STATUSES,
  type AdminFeedbackItem,
  type AdminFeedbackList,
  type FeedbackPriority,
  type FeedbackStatus,
} from '@fitos/contracts';
import { useEffect, useMemo, useState } from 'react';

import { Badge, Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

const TONE: Record<FeedbackStatus, 'warn' | 'muted' | 'ok'> = { new: 'warn', read: 'muted', done: 'ok' };
const MEANING: Record<FeedbackPriority, string> = { red: 'Red: solve first', yellow: 'Yellow: soon', green: 'Green: later' };
/** Red, yellow, green, then untagged; newest first within each. */
const RANK: Record<FeedbackPriority | 'none', number> = { red: 0, yellow: 1, green: 2, none: 3 };

type PriorityFilter = FeedbackPriority | 'none' | 'all';

/** Phase 19 (ADR-026): what beta testers sent from the app, tagged by what to solve first. */
export default function Feedback() {
  const [filter, setFilter] = useState<FeedbackStatus | 'all'>('new');
  const [priority, setPriority] = useState<PriorityFilter>('all');
  const [items, setItems] = useState<AdminFeedbackItem[]>([]);
  const [next, setNext] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async (before: string | null) => {
    setLoading(true);
    setError(null);
    try {
      const status = filter === 'all' ? '' : `&status=${filter}`;
      const tag = priority === 'all' ? '' : `&priority=${priority}`;
      const page = await api<AdminFeedbackList>('GET', `/admin/feedback?limit=50${status}${tag}${before === null ? '' : `&before=${encodeURIComponent(before)}`}`);
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
  }, [filter, priority]);

  /** Keeps a row only while it still matches both filters. */
  const fits = (x: AdminFeedbackItem): boolean =>
    (filter === 'all' || x.status === filter) && (priority === 'all' || (x.priority ?? 'none') === priority);

  const update = async (id: string, change: { status?: FeedbackStatus; priority?: FeedbackPriority | null }) => {
    setError(null);
    try {
      const updated = await api<AdminFeedbackItem>('PATCH', `/admin/feedback/${id}`, change);
      setItems((xs) => (fits(updated) ? xs.map((x) => (x.id === id ? updated : x)) : xs.filter((x) => x.id !== id)));
    } catch (e) {
      setError(errorText(e));
    }
  };

  const sorted = useMemo(
    () => items.map((x, i) => ({ x, i })).sort((a, b) => RANK[a.x.priority ?? 'none'] - RANK[b.x.priority ?? 'none'] || a.i - b.i).map((e) => e.x),
    [items],
  );

  return (
    <>
      <Header eyebrow="Feedback" title="From the app">
        What testers sent from Profile → Send feedback, red first, then yellow, then green, then untagged. Tap a colour to tag an item; tap it again to
        clear it. The sender is an id: look them up under Support if you need to reply. Tags and status changes are audited.
      </Header>
      <p>
        {(['new', 'read', 'done', 'all'] as const).map((f) => (
          <button key={f} className={`button${filter === f ? ' active' : ''}`} disabled={loading} onClick={() => setFilter(f)}>{f}</button>
        ))}
      </p>
      <p>
        {(['all', ...FEEDBACK_PRIORITIES, 'none'] as const).map((p) => (
          <button key={p} className={`button small${priority === p ? ' active' : ''}`} disabled={loading} onClick={() => setPriority(p)}>
            {p !== 'all' && <span className={`dot ${p}`} aria-hidden />}
            {p === 'all' ? 'every tag' : p === 'none' ? 'untagged' : p}
          </button>
        ))}
      </p>
      {error !== null && <p className="error">{error}</p>}
      <table>
        <thead><tr><th>Priority</th><th>When</th><th>Category</th><th>Message</th><th>App</th><th>Status</th><th /></tr></thead>
        <tbody>
          {sorted.map((f) => (
            <tr key={f.id} className={f.priority === null ? '' : `p-${f.priority}`}>
              <td style={{ whiteSpace: 'nowrap' }}>
                {FEEDBACK_PRIORITIES.map((p) => (
                  <button
                    key={p}
                    type="button"
                    className={`prio ${p}${f.priority === p ? ' on' : ''}`}
                    title={f.priority === p ? `${MEANING[p]} (tap to clear)` : MEANING[p]}
                    aria-label={f.priority === p ? `Clear the ${p} tag` : `Tag ${p}`}
                    aria-pressed={f.priority === p}
                    onClick={() => void update(f.id, { priority: f.priority === p ? null : p })}
                  />
                ))}
              </td>
              <td>{when(f.createdAt)}<div className="muted small"><code title="Paste into Support to look the sender up">{f.userId}</code></div></td>
              <td>{f.category}</td>
              <td style={{ whiteSpace: 'pre-wrap', maxWidth: '40rem' }}>{f.message}</td>
              <td className="small">{f.appVersion}</td>
              <td><Badge tone={TONE[f.status]}>{f.status}</Badge></td>
              <td>
                {FEEDBACK_STATUSES.filter((s) => s !== f.status).map((s) => (
                  <button key={s} className="button small" onClick={() => void update(f.id, { status: s })}>{s}</button>
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
