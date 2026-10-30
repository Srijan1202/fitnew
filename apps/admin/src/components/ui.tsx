'use client';

import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, errorText } from '@/lib/api';

/** GET once (and on demand): data, error, loading, reload. */
export function useGet<T>(path: string | null): { data: T | null; error: string | null; loading: boolean; reload: () => void } {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [tick, setTick] = useState(0);
  useEffect(() => {
    if (path === null) return;
    let live = true;
    setLoading(true);
    setError(null);
    api<T>('GET', path)
      .then((d) => live && setData(d))
      .catch((e: unknown) => live && setError(errorText(e)))
      .finally(() => live && setLoading(false));
    return () => {
      live = false;
    };
  }, [path, tick]);
  const reload = useCallback(() => setTick((t) => t + 1), []);
  return { data, error, loading, reload };
}

/**
 * A page's title. Its longer explanation folds into "About this page"
 * (owner 2026-10-30: the panel read as cluttered with every page opening
 * on a paragraph).
 */
export function Header({ eyebrow, title, children }: { eyebrow: string; title: string; children?: ReactNode }) {
  return (
    <header className="page-head">
      <p className="eyebrow">{eyebrow}</p>
      <h1>{title}</h1>
      {children !== undefined && (
        <details className="about">
          <summary>About this page</summary>
          <div>{children}</div>
        </details>
      )}
    </header>
  );
}

export function Status({ error, loading }: { error: string | null; loading: boolean }) {
  if (error !== null) return <p className="error">{error}</p>;
  if (loading) return <p className="muted">Loading…</p>;
  return null;
}

export const when = (iso: string | null): string =>
  iso === null ? '—' : new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

export const pct = (v: number | null): string => (v === null ? '—' : `${v}%`);

export function Badge({ tone, children }: { tone: 'ok' | 'warn' | 'bad' | 'muted'; children: ReactNode }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}
