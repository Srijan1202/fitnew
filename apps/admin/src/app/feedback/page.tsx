'use client';

import {
  FEEDBACK_CATEGORIES,
  FEEDBACK_PRIORITIES,
  FEEDBACK_REPLY_MAX_LENGTH,
  type AdminFeedbackCounts,
  type AdminFeedbackItem,
  type AdminFeedbackList,
  type FeedbackCategory,
  type FeedbackPriority,
  type FeedbackReply,
  type FeedbackStatus,
} from '@fitos/contracts';
import { useEffect, useMemo, useState } from 'react';

import { Header, when } from '@/components/ui';
import { api, apiBlob, errorText } from '@/lib/api';

/** Beta 3.6: a picture sent with feedback, fetched with the admin's sign-in; click for full size. */
function Picture({ feedbackId, id }: { feedbackId: string; id: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let made: string | null = null;
    let live = true;
    apiBlob(`/admin/feedback/${feedbackId}/pictures/${id}`).then(
      (b) => {
        if (!live) return;
        made = URL.createObjectURL(b);
        setUrl(made);
      },
      () => live && setFailed(true),
    );
    return () => {
      live = false;
      if (made !== null) URL.revokeObjectURL(made);
    };
  }, [feedbackId, id]);
  if (failed) return <span className="fb-pic missing">Picture gone</span>;
  if (url === null) return <span className="fb-pic loading" aria-label="Loading picture" />;
  return (
    <a className="fb-pic" href={url} target="_blank" rel="noreferrer" title="Open full size">
      {/* eslint-disable-next-line @next/next/no-img-element -- a private blob, not a static asset */}
      <img src={url} alt="Sent with the feedback" />
    </a>
  );
}

/** Beta 3.6: the replies so far, and a box for a new one (the sender is told by a notification). */
function Replies({ item, onReplied }: { item: AdminFeedbackItem; onReplied: (r: FeedbackReply) => void }) {
  const [open, setOpen] = useState(false);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const send = async () => {
    setBusy(true);
    setError(null);
    try {
      const r = await api<FeedbackReply>('POST', `/admin/feedback/${item.id}/replies`, { message: text });
      onReplied(r);
      setText('');
      setOpen(false);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="fb-replies">
      {item.replies.map((r) => (
        <p key={r.id} className="fb-reply">
          <span className="fb-reply-meta">
            You replied {when(r.createdAt)} · {r.readAt === null ? 'not read yet' : `read ${when(r.readAt)}`}
          </span>
          {r.message}
        </p>
      ))}
      {open ? (
        <div className="fb-reply-box">
          <textarea
            value={text}
            maxLength={FEEDBACK_REPLY_MAX_LENGTH}
            rows={3}
            placeholder="They see this in FITOS and get a notification."
            onChange={(e) => setText(e.target.value)}
          />
          <div className="fb-reply-actions">
            <button className="button small" onClick={() => setOpen(false)} disabled={busy}>Cancel</button>
            <button className="button primary small" onClick={() => void send()} disabled={busy || text.trim() === ''}>Send reply</button>
          </div>
          {error !== null && <p className="error">{error}</p>}
        </div>
      ) : (
        <button className="button small" onClick={() => setOpen(true)}>Reply</button>
      )}
    </div>
  );
}

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
  /** Beta 3.6: one type of feedback, or all. */
  const [category, setCategory] = useState<FeedbackCategory | 'all'>('all');
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
      const query = TABS.find((t) => t.tab === tab)!.query + (category === 'all' ? '' : `&category=${category}`);
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
  }, [tab, category]);

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
        <strong>To do</strong>, red first. When it is in the app, press <strong>Done</strong>. Every move can be undone. <strong>Reply</strong> on a
        card: the sender reads it in FITOS and gets a notification. Pictures are kept for six months.
      </Header>
      <nav className="fb-tabs" aria-label="Feedback">
        {TABS.map(({ tab: t, label }) => (
          <button key={t} className={`fb-tab${tab === t ? ' active' : ''}`} aria-current={tab === t ? 'page' : undefined} onClick={() => setTab(t)}>
            {label}
            {count(t) !== null && <span className="fb-count">{count(t)}</span>}
          </button>
        ))}
        <select
          className="fb-type"
          aria-label="Type"
          value={category}
          onChange={(e) => setCategory(e.target.value as FeedbackCategory | 'all')}
        >
          <option value="all">All types</option>
          {FEEDBACK_CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
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
            {f.device !== null && (
              <span title="Sent with the message (the sender can leave it out)">
                {f.device.model} · {f.device.os}
                {f.device.screen !== null ? ` · ${f.device.screen}` : ''}
              </span>
            )}
            <code title="Paste into Support to look the sender up">{f.userId.slice(0, 8)}</code>
          </div>
          <p className="fb-message">{f.message}</p>
          {f.pictures.length > 0 && (
            <div className="fb-pics">
              {f.pictures.map((p) => (
                <Picture key={p.id} feedbackId={f.id} id={p.id} />
              ))}
            </div>
          )}
          <Replies
            item={f}
            onReplied={(r) => setItems((xs) => xs.map((x) => (x.id === f.id ? { ...x, replies: [...x.replies, r] } : x)))}
          />
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
