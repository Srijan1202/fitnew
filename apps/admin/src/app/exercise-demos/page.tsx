'use client';

import type { AdminDemoApproval } from '@fitos/contracts';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { Icon } from '@/components/icons';
import { toast } from '@/components/Shell';
import { Badge, Empty, Header, SearchBox, Status, useGet, when } from '@/components/ui';
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
 * A variant follows its demo. Each decision is audited. Beta 5.3: a large
 * view on click, the arrow keys to move through them, a search.
 */
export default function ExerciseDemos() {
  const { data, error, loading, reload } = useGet<{ items: AdminDemoApproval[] }>('/admin/exercise-demos');
  const [demos, setDemos] = useState<DemoEntry[] | null>(null);
  const [demosError, setDemosError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>('waiting');
  const [q, setQ] = useState('');
  const [view, setView] = useState<string | null>(null);

  useEffect(() => {
    fetch('/demos/manifest.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`manifest ${r.status}`))))
      .then((m: { demos: DemoEntry[] }) => setDemos(m.demos))
      .catch((e: unknown) => setDemosError(errorText(e)));
  }, []);

  const decided = useMemo(() => new Map((data?.items ?? []).map((d) => [d.slug, d])), [data]);
  const stateOf = useCallback(
    (slug: string): State => {
      const d = decided.get(slug);
      return d === undefined ? 'waiting' : d.approved ? 'approved' : 'rejected';
    },
    [decided],
  );

  const all = demos ?? [];
  const counts: Record<Filter, number> = {
    waiting: all.filter((d) => stateOf(d.slug) === 'waiting').length,
    approved: all.filter((d) => stateOf(d.slug) === 'approved').length,
    rejected: all.filter((d) => stateOf(d.slug) === 'rejected').length,
    all: all.length,
  };
  const term = q.trim().toLowerCase();
  const shown = all.filter(
    (d) => (filter === 'all' || stateOf(d.slug) === filter) && (term === '' || `${d.name} ${d.pattern} ${d.equipment.join(' ')}`.toLowerCase().includes(term)),
  );
  const rejected = all.filter((d) => stateOf(d.slug) === 'rejected');

  // Every rejection's note as plain lines, to hand over for the redraw.
  const copyNotes = async () => {
    const lines = rejected.map((d) => `${d.name} (${d.slug}): ${decided.get(d.slug)?.note ?? 'no note'}`);
    await navigator.clipboard.writeText(lines.join('\n'));
    toast(`Copied ${lines.length} note${lines.length === 1 ? '' : 's'}`);
  };

  const viewIndex = view === null ? -1 : shown.findIndex((d) => d.slug === view);
  const viewing = viewIndex < 0 ? null : shown[viewIndex]!;

  return (
    <>
      <Header
        eyebrow="Content"
        title="Exercise demos"
        actions={
          rejected.length > 0 ? (
            <button className="button" onClick={() => void copyNotes()}>
              <Icon name="copy" size={16} /> Copy all notes
            </button>
          ) : undefined
        }
      >
        A demo shows in the app only after you approve it here. Click one to watch it large and read its steps, then Approve it, or Reject it with a
        note on what looks wrong. Phones pick up the change the next time FITOS opens or comes back. A variant (listed under its demo) follows the
        demo. Each decision is audited. Copy all notes gives every rejected demo with its note, one per line.
      </Header>
      <Status error={error ?? demosError} loading={(loading && data === null) || demos === null} />

      <div className="toolbar">
        <div className="segmented" role="group" aria-label="Which demos" style={{ margin: 0 }}>
          {(['waiting', 'approved', 'rejected', 'all'] as const).map((f) => (
            <button key={f} className={filter === f ? 'active' : ''} onClick={() => setFilter(f)}>
              {f === 'waiting' ? 'Waiting' : f === 'approved' ? 'Approved' : f === 'rejected' ? 'Rejected' : 'All'}
              <span className="fb-count">{counts[f]}</span>
            </button>
          ))}
        </div>
        <SearchBox value={q} onChange={setQ} placeholder="Find a demo (name, movement, equipment)" />
      </div>

      {demos !== null && shown.length === 0 && (
        <Empty icon={filter === 'waiting' && term === '' ? 'check' : 'search'} title={filter === 'waiting' && term === '' ? 'Nothing waiting' : 'No demo here'}>
          {filter === 'waiting' && term === '' ? 'Every demo has been decided.' : 'Try another tab or search.'}
        </Empty>
      )}

      <div className="demo-grid">
        {shown.map((d) => (
          <article key={d.slug} className="card demo-card">
            <button className="demo-stage" onClick={() => setView(d.slug)} aria-label={`Watch ${d.name} large`}>
              {/* eslint-disable-next-line @next/next/no-img-element -- an animated WebP; next/image would serve its first frame */}
              <img src={`/demos/${d.slug}.webp`} alt={`Demo of ${d.name}`} loading="lazy" width={288} height={320} />
            </button>
            <div className="stack">
              <DemoDetails demo={d} state={stateOf(d.slug)} row={decided.get(d.slug)} />
              <Decision demo={d} state={stateOf(d.slug)} row={decided.get(d.slug)} onChanged={reload} />
            </div>
          </article>
        ))}
      </div>

      {viewing !== null && (
        <Lightbox
          demo={viewing}
          index={viewIndex}
          total={shown.length}
          state={stateOf(viewing.slug)}
          row={decided.get(viewing.slug)}
          onChanged={reload}
          onMove={(by) => {
            const next = shown[viewIndex + by];
            if (next !== undefined) setView(next.slug);
          }}
          onClose={() => setView(null)}
        />
      )}
    </>
  );
}

function DemoDetails({ demo: d, state, row }: { demo: DemoEntry; state: State; row: AdminDemoApproval | undefined }) {
  return (
    <>
      <div className="row" style={{ margin: 0 }}>
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
      {d.variants.length > 0 && <div className="small muted">Also shown for: {d.variants.map((v) => `${v.name} ("${v.note}")`).join('; ')}</div>}
    </>
  );
}

/** Approve, or Reject with a note (or edit the note of a rejected one). */
function Decision({ demo: d, state, row, onChanged }: { demo: DemoEntry; state: State; row: AdminDemoApproval | undefined; onChanged: () => void }) {
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

  return (
    <>
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
            onKeyDown={(e) => e.stopPropagation()}
          />
          <div className="row" style={{ margin: 0 }}>
            <button className="button small" onClick={() => setRejecting(false)} disabled={busy}>
              Cancel
            </button>
            <button className="button primary small" onClick={() => void put({ approved: false, note: note.trim() })} disabled={busy || note.trim() === ''}>
              {state === 'rejected' ? 'Save note' : 'Reject'}
            </button>
          </div>
        </div>
      ) : (
        <div className="row" style={{ margin: 0 }}>
          {state !== 'approved' && (
            <button className="button primary small" disabled={busy} onClick={() => void put({ approved: true })}>
              <Icon name="check" size={15} /> Approve
            </button>
          )}
          <button
            className="button small danger"
            disabled={busy}
            onClick={() => {
              setNote(row?.note ?? '');
              setRejecting(true);
            }}
          >
            {state === 'rejected' ? 'Edit note' : 'Reject'}
          </button>
        </div>
      )}
      {error !== null && <p className="error small">{error}</p>}
    </>
  );
}

/** The demo large, its steps and decision beside it; ← and → move, Esc closes. */
function Lightbox(props: {
  demo: DemoEntry;
  index: number;
  total: number;
  state: State;
  row: AdminDemoApproval | undefined;
  onChanged: () => void;
  onMove: (by: number) => void;
  onClose: () => void;
}) {
  const { demo: d, index, total, onMove, onClose } = props;
  useEffect(() => {
    const keys = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      else if (e.key === 'ArrowRight') onMove(1);
      else if (e.key === 'ArrowLeft') onMove(-1);
    };
    window.addEventListener('keydown', keys);
    return () => window.removeEventListener('keydown', keys);
  }, [onMove, onClose]);
  return (
    <>
      <div className="overlay" onClick={onClose} aria-hidden="true" />
      <div className="lightbox" role="dialog" aria-label={d.name}>
        <div className="demo-stage">
          {/* eslint-disable-next-line @next/next/no-img-element -- an animated WebP */}
          <img key={d.slug} src={`/demos/${d.slug}.webp`} alt={`Demo of ${d.name}`} />
        </div>
        <div className="lightbox-side">
          <div className="lightbox-nav">
            <button className="icon-button" aria-label="Previous demo" disabled={index === 0} onClick={() => onMove(-1)}>
              <Icon name="chevronLeft" />
            </button>
            <span className="muted small grow">
              {index + 1} of {total} · <kbd>←</kbd> <kbd>→</kbd>
            </span>
            <button className="icon-button" aria-label="Next demo" disabled={index === total - 1} onClick={() => onMove(1)}>
              <Icon name="chevronRight" />
            </button>
            <button className="icon-button" aria-label="Close" onClick={onClose}>
              <Icon name="close" />
            </button>
          </div>
          <DemoDetails demo={d} state={props.state} row={props.row} />
          <Decision key={d.slug} demo={d} state={props.state} row={props.row} onChanged={props.onChanged} />
        </div>
      </div>
    </>
  );
}
