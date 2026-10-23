'use client';

import {
  FEEDBACK_PRIORITIES,
  type AdminFeedbackCounts,
  type AdminFeedbackItem,
  type AdminFeedbackList,
  type FeedbackPriority,
  type FeedbackStatus,
} from '@fitos/contracts';
import { useEffect, useMemo, useState } from 'react';

import { Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/**
 * The owner's flow (after beta 3.2): a new message lands in New; a colour
 * (red solve first, yellow soon, green later) moves it to To do; Done moves
 * it to Done. Every move can be undone, and each change is audited.
 */
type Tab = 'new' | 'todo' | 'done';

const TABS: { tab: Tab; label: string; query: string }[] = [
  { tab: 'new', label: 'New', query: 'status=open&priority=none' },
  { tab: 'todo', label: 'To do', query: 'status=open' },
  { tab: 'done', label: 'Done', query: 'status=done' },
];
const MEANING: Record<FeedbackPriority, string> = { red: 'Red: solve first', yellow: 'Yellow: soon', green: 'Green: later' };
const RANK: Record<FeedbackPriority | 'none', number> = { red: 0, yellow: 1, green: 2, none: 3 };

type Change = { status?: FeedbackStatus; priority?: FeedbackPriority | null };

/** Which tab an item belongs in now. */
const tabOf = (x: AdminFeedbackItem): Tab => (x.status === 'done' ? 'done' : x.priority === null ? 'new' : 'todo');

export default function Feedback() {
  const [tab, setTab] = useState<Tab>('new');
  const [items, setItems] = useState<AdminFeedbackItem[]>([]);
  const [counts, setCounts] = useState<AdminFeedbackCounts | null>(null);
  const [next, setNext] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  /** The last move, so it can be undone. */
  const [undo, setUndo] = useState<{ item: AdminFeedbackItem; text: string } | null>(null);

  const loadCounts = async () => {
    try {
      setCounts(await api<AdminFeedbackCounts>('GET', '/admin/feedback/counts'));
    } catch (e) {
      setError(errorText(e));
    }
  };

  const load = async (before: string | null) => {
    setLoading(true);
    setError(null);
    try {
      const query = TABS.find((t) => t.tab === tab)!.query;
      const page = await api<AdminFeedbackList>('GET', `/admin/feedback?limit=100&${query}${before === null ? '' : `&before=${encodeURIComponent(before)}`}`);
      setItems((xs) => (before === null ? page.items : [...xs, ...page.items]));
      setNext(page.next);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    setUndo(null);
    void load(null);
    void loadCounts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  /** Applies a change; the row leaves this tab when it no longer belongs here. */
  const apply = async (before: AdminFeedbackItem, change: Change): Promise<AdminFeedbackItem | null> => {
    setError(null);
    try {
      const updated = await api<AdminFeedbackItem>('PATCH', `/admin/feedback/${before.id}`, change);
      setItems((xs) => (tabOf(updated) === tab ? xs.map((x) => (x.id === updated.id ? updated : x)) : xs.filter((x) => x.id !== updated.id)));
      void loadCounts();
      return updated;
    } catch (e) {
      setError(errorText(e));
      return null;
    }
  };

  const move = async (item: AdminFeedbackItem, change: Change, text: string) => {
    const updated = await apply(item, change);
    if (updated !== null && tabOf(updated) !== tab) setUndo({ item, text });
  };

  const undoLast = async () => {
    if (undo === null) return;
    const { item } = undo;
    setUndo(null);
    const restored = await apply(item, { status: item.status, priority: item.priority });
    if (restored !== null && tabOf(restored) === tab) {
      setItems((xs) => (xs.some((x) => x.id === restored.id) ? xs : [...xs, restored]));
    }
  };

  /** To do is a work queue: red, yellow, green, oldest first within each. New and Done: newest first. */
  const shown = useMemo(() => {
    if (tab !== 'todo') return [...items].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return [...items].sort((a, b) => RANK[a.priority ?? 'none'] - RANK[b.priority ?? 'none'] || a.createdAt.localeCompare(b.createdAt));
  }, [items, tab]);

  const count = (t: Tab): number | null =>
    counts === null ? null : t === 'new' ? counts.untagged : t === 'todo' ? counts.red + counts.yellow + counts.green + counts.untagged : counts.done;

  return (
    <>
      <Header eyebrow="Feedback" title="From the app">
        New messages land in <strong>New</strong>. Give each a colour (red: solve first, yellow: soon, green: later) and it moves to{' '}
        <strong>To do</strong>, red first. When it is in the app, press <strong>Done</strong>. Every move can be undone. The sender is an id: look
        them up under Support if you need to reply.
      </Header>
      <nav className="fb-tabs" aria-label="Feedback">
        {TABS.map(({ tab: t, label }) => (
          <button key={t} className={`fb-tab${tab === t ? ' active' : ''}`} aria-current={tab === t ? 'page' : undefined} onClick={() => setTab(t)}>
            {label}
            {count(t) !== null && <span className="fb-count">{count(t)}</span>}
          </button>
        ))}
      </nav>
      {tab === 'todo' && counts !== null && (
        <p className="fb-summary">
          {FEEDBACK_PRIORITIES.map((p) => (
            <span key={p}>
              <span className={`dot ${p}`} aria-hidden />
              {counts[p]} {p}
            </span>
          ))}
          {counts.untagged > 0 && (
            <span>
              <span className="dot none" aria-hidden />
              {counts.untagged} untagged
            </span>
          )}
        </p>
      )}
      {undo !== null && (
        <p className="fb-undo" role="status">
          {undo.text}
          <button className="button small" onClick={() => void undoLast()}>Undo</button>
        </p>
      )}
      {error !== null && <p className="error">{error}</p>}

      {shown.map((f) => (
        <article key={f.id} className={`fb-card${f.priority === null ? '' : ` p-${f.priority}`}`}>
          <div className="fb-meta">
            <span className="fb-category">{f.category}</span>
            <span>{when(f.createdAt)}</span>
            <span>app {f.appVersion}</span>
            <code title="Paste into Support to look the sender up">{f.userId.slice(0, 8)}</code>
          </div>
          <p className="fb-message">{f.message}</p>
          <div className="fb-actions">
            {tab !== 'done' && (
              <span className="fb-colours">
                {FEEDBACK_PRIORITIES.map((p) => (
                  <button
                    key={p}
                    type="button"
                    className={`prio ${p}${f.priority === p ? ' on' : ''}`}
                    title={MEANING[p]}
                    aria-label={MEANING[p]}
                    aria-pressed={f.priority === p}
                    onClick={() =>
                      void move(f, f.status === 'new' ? { priority: p, status: 'read' } : { priority: p }, `Tagged ${p}: moved to To do.`)
                    }
                  />
                ))}
              </span>
            )}
            {tab === 'done' ? (
              <button className="button small" onClick={() => void move(f, { status: 'read' }, 'Reopened: back in To do.')}>Reopen</button>
            ) : (
              <button className="button fb-done" onClick={() => void move(f, { status: 'done' }, 'Marked done.')}>✓ Done</button>
            )}
          </div>
        </article>
      ))}
      {shown.length === 0 && !loading && (
        <p className="muted">{tab === 'new' ? 'Nothing new. Everything is tagged.' : tab === 'todo' ? 'Nothing to do.' : 'Nothing done yet.'}</p>
      )}
      {next !== null && <button className="button" disabled={loading} onClick={() => void load(next)}>Older</button>}
    </>
  );
}
