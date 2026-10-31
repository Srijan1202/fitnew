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

type Filter = 'waiting' | 'approved' | 'all';

/**
 * Beta 5.2 (owner): an exercise demo shows in the app only once approved
 * here. Each animates as the app draws it; Approve shows it to everyone
 * (within a few minutes, or when they next open FITOS), Withdraw hides it
 * again. A variant follows its demo. Each decision is audited.
 */
export default function ExerciseDemos() {
  const { data, error, loading, reload } = useGet<{ items: AdminDemoApproval[] }>('/admin/exercise-demos');
  const [demos, setDemos] = useState<DemoEntry[] | null>(null);
  const [demosError, setDemosError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>('waiting');
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/demos/manifest.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`manifest ${r.status}`))))
      .then((m: { demos: DemoEntry[] }) => setDemos(m.demos))
      .catch((e: unknown) => setDemosError(errorText(e)));
  }, []);

  const decided = useMemo(() => new Map((data?.items ?? []).map((d) => [d.slug, d])), [data]);
  const stateOf = (slug: string): 'approved' | 'withdrawn' | 'waiting' => {
    const d = decided.get(slug);
    return d === undefined ? 'waiting' : d.approved ? 'approved' : 'withdrawn';
  };

  const put = async (slug: string, approved: boolean) => {
    setActionError(null);
    setBusy(slug);
    try {
      await api('PUT', `/admin/exercise-demos/${encodeURIComponent(slug)}`, { approved });
      reload();
    } catch (e) {
      setActionError(errorText(e));
    } finally {
      setBusy(null);
    }
  };

  const all = demos ?? [];
  const counts = {
    waiting: all.filter((d) => stateOf(d.slug) !== 'approved').length,
    approved: all.filter((d) => stateOf(d.slug) === 'approved').length,
    all: all.length,
  };
  const shown = all.filter((d) => (filter === 'all' ? true : filter === 'approved' ? stateOf(d.slug) === 'approved' : stateOf(d.slug) !== 'approved'));

  return (
    <>
      <Header eyebrow="Content" title="Exercise demos">
        A demo shows in the app only after you approve it here. Watch it play, read its steps, then Approve. Withdraw hides it again. Phones pick up the change
        the next time FITOS opens or comes back. A variant (listed under its demo) follows the demo. Each decision is audited.
      </Header>
      <Status error={error ?? demosError} loading={(loading && data === null) || demos === null} />
      {actionError !== null && <p className="error">{actionError}</p>}

      <div className="fb-tabs">
        {(['waiting', 'approved', 'all'] as const).map((f) => (
          <button key={f} className={`fb-tab${filter === f ? ' active' : ''}`} onClick={() => setFilter(f)}>
            {f === 'waiting' ? 'Waiting' : f === 'approved' ? 'Approved' : 'All'} <span className="fb-count">{counts[f]}</span>
          </button>
        ))}
      </div>

      {demos !== null && shown.length === 0 && (
        <p className="muted">{filter === 'waiting' ? 'Nothing waiting: every demo is approved.' : 'None yet.'}</p>
      )}

      <div className="demo-grid">
        {shown.map((d) => {
          const state = stateOf(d.slug);
          const row = decided.get(d.slug);
          return (
            <article key={d.slug} className="card demo-card">
              <div className="demo-stage">
                {/* eslint-disable-next-line @next/next/no-img-element -- an animated WebP; next/image would serve its first frame */}
                <img src={`/demos/${d.slug}.webp`} alt={`Demo of ${d.name}`} loading="lazy" width={288} height={320} />
              </div>
              <div className="stack">
                <div className="row">
                  <strong className="grow">{d.name}</strong>
                  {state === 'approved' ? <Badge tone="ok">approved</Badge> : state === 'withdrawn' ? <Badge tone="bad">withdrawn</Badge> : <Badge tone="warn">waiting</Badge>}
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
                <div className="row">
                  {state === 'approved' ? (
                    <button className="button" disabled={busy === d.slug} onClick={() => void put(d.slug, false)}>
                      Withdraw
                    </button>
                  ) : (
                    <button className="button primary" disabled={busy === d.slug} onClick={() => void put(d.slug, true)}>
                      Approve
                    </button>
                  )}
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </>
  );
}
