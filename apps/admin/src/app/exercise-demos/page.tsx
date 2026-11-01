'use client';

import type { AdminDemoApproval } from '@fitos/contracts';
import { useEffect, useMemo, useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/** One demo as the app draws it (public/demos/manifest.json, from apps/mobile/tool/demo_frames). */
type DemoEntry = {
  slug: string;
  name: string;
  pattern: string;
  equipment: string[];
  cues: string[];
  seconds: number;
  /** Exercises that show this demo with a line saying what differs. */
  variants: { slug: string; name: string; note: string }[];
};

type State = 'waiting' | 'approved' | 'rejected';
type Filter = State | 'all';

/** The API's limit on a rejection note. */
const NOTE_MAX = 1000;

/**
 * Beta 5.2 (owner): an exercise demo shows in the app only once approved
 * here. Each animates as the app draws it; Approve shows it to everyone
 * (when they next open FITOS), Reject hides it with a note on what to fix.
 * A variant follows its demo. Each decision is audited.
 */
export default function ExerciseDemos() {
  const { data, error, loading, reload } = useGet<{ items: AdminDemoApproval[] }>('/admin/exercise-demos');
  const [demos, setDemos] = useState<DemoEntry[] | null>(null);
  const [demosError, setDemosError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>('waiting');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    fetch('/demos/manifest.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`manifest ${r.status}`))))
      .then((m: { demos: DemoEntry[] }) => setDemos(m.demos))
      .catch((e: unknown) => setDemosError(errorText(e)));
  }, []);

  const decided = useMemo(() => new Map((data?.items ?? []).map((d) => [d.slug, d])), [data]);
  const stateOf = (slug: string): State => {
    const d = decided.get(slug);
    return d === undefined ? 'waiting' : d.approved ? 'approved' : 'rejected';
  };

  const all = demos ?? [];
  const counts: Record<Filter, number> = {
    waiting: all.filter((d) => stateOf(d.slug) === 'waiting').length,
    approved: all.filter((d) => stateOf(d.slug) === 'approved').length,
    rejected: all.filter((d) => stateOf(d.slug) === 'rejected').length,
    all: all.length,
  };
  const shown = all.filter((d) => filter === 'all' || stateOf(d.slug) === filter);
  const rejected = all.filter((d) => stateOf(d.slug) === 'rejected');

  // Every rejection's note as plain lines, to hand over for the redraw.
  const copyNotes = async () => {
    const lines = rejected.map((d) => `${d.name} (${d.slug}): ${decided.get(d.slug)?.note ?? 'no note'}`);
    await navigator.clipboard.writeText(lines.join('\n'));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <>
      <Header eyebrow="Content" title="Exercise demos">
        A demo shows in the app only after you approve it here. Watch it play and read its steps, then Approve it, or Reject it with a note on what looks
        wrong. Phones pick up the change the next time FITOS opens or comes back. A variant (listed under its demo) follows the demo. Each decision is
        audited.
      </Header>
      <Status error={error ?? demosError} loading={(loading && data === null) || demos === null} />

      <div className="fb-tabs">
        {(['waiting', 'approved', 'rejected', 'all'] as const).map((f) => (
          <button key={f} className={`fb-tab${filter === f ? ' active' : ''}`} onClick={() => setFilter(f)}>
            {f === 'waiting' ? 'Waiting' : f === 'approved' ? 'Approved' : f === 'rejected' ? 'Rejected' : 'All'}{' '}
            <span className="fb-count">{counts[f]}</span>
          </button>
        ))}
      </div>

      {filter === 'rejected' && rejected.length > 0 && (
        <div className="row">
          <button className="button small" onClick={() => void copyNotes()}>
            {copied ? 'Copied' : 'Copy all notes'}
          </button>
          <span className="muted small">Every rejected demo with its note, one per line.</span>
        </div>
      )}

      {demos !== null && shown.length === 0 && (
        <p className="muted">
          {filter === 'waiting' ? 'Nothing waiting: every demo has been decided.' : filter === 'rejected' ? 'Nothing rejected.' : 'None yet.'}
        </p>
      )}

      <div className="demo-grid">
        {shown.map((d) => (
          <DemoCard key={d.slug} demo={d} state={stateOf(d.slug)} row={decided.get(d.slug)} onChanged={reload} />
        ))}
      </div>
    </>
  );
}

function DemoCard({ demo: d, state, row, onChanged }: { demo: DemoEntry; state: State; row: AdminDemoApproval | undefined; onChanged: () => void }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState(false);
  const [note, setNote] = useState('');

  const put = async (body: { approved: boolean; note?: string }) => {
    setError(null);
    setBusy(true);
    try {
      await api('PUT', `/admin/exercise-demos/${encodeURIComponent(d.slug)}`, body);
      setRejecting(false);
      onChanged();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  };

  const openReject = () => {
    setNote(row?.note ?? '');
    setRejecting(true);
  };

  return (
    <article className="card demo-card">
      <div className="demo-stage">
        {/* eslint-disable-next-line @next/next/no-img-element -- an animated WebP; next/image would serve its first frame */}
        <img src={`/demos/${d.slug}.webp`} alt={`Demo of ${d.name}`} loading="lazy" width={288} height={320} />
      </div>
      <div className="stack">
        <div className="row">
          <strong className="grow">{d.name}</strong>
          {state === 'approved' ? <Badge tone="ok">approved</Badge> : state === 'rejected' ? <Badge tone="bad">rejected</Badge> : <Badge tone="warn">waiting</Badge>}
        </div>
        <div className="muted small">
          {d.pattern.replace('-', ' ')} · {d.equipment.join(' + ').replace(/-/g, ' ')} · {d.seconds} s a rep
          {row !== undefined && <> · changed {when(row.updatedAt)}</>}
        </div>
        <ol className="small demo-cues">
          {d.cues.map((c) => (
            <li key={c}>{c}</li>
          ))}
        </ol>
        {d.variants.length > 0 && (
          <div className="small muted">
            Also shown for: {d.variants.map((v) => `${v.name} ("${v.note}")`).join('; ')}
          </div>
        )}
        {state === 'rejected' && !rejecting && <p className="demo-note small">{row?.note ?? 'Rejected without a note.'}</p>}

        {rejecting ? (
          <div className="demo-reject">
            <textarea
              value={note}
              maxLength={NOTE_MAX}
              rows={3}
              autoFocus
              placeholder="What looks wrong? For example: the arms bend at the elbow; they should stay long."
              onChange={(e) => setNote(e.target.value)}
            />
            <div className="row">
              <button className="button small" onClick={() => setRejecting(false)} disabled={busy}>
                Cancel
              </button>
              <button className="button primary small" onClick={() => void put({ approved: false, note: note.trim() })} disabled={busy || note.trim() === ''}>
                {state === 'rejected' ? 'Save note' : 'Reject'}
              </button>
            </div>
          </div>
        ) : (
          <div className="row">
            {state !== 'approved' && (
              <button className="button primary small" disabled={busy} onClick={() => void put({ approved: true })}>
                Approve
              </button>
            )}
            <button className="button small" disabled={busy} onClick={openReject}>
              {state === 'rejected' ? 'Edit note' : 'Reject'}
            </button>
          </div>
        )}
        {error !== null && <p className="error small">{error}</p>}
      </div>
    </article>
  );
}
