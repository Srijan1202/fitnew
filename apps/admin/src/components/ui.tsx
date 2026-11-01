'use client';

import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';

import { Icon, type IconName } from '@/components/icons';
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
 * A page's title, with its main actions beside it. Its longer explanation
 * folds into "About this page" (owner 2026-10-30: every page opening on a
 * paragraph read as cluttered).
 */
export function Header({ eyebrow, title, actions, children }: { eyebrow: string; title: string; actions?: ReactNode; children?: ReactNode }) {
  return (
    <header className="page-head">
      <div className="titles">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        {children !== undefined && (
          <details className="about">
            <summary>About this page</summary>
            <div>{children}</div>
          </details>
        )}
      </div>
      {actions !== undefined && <div className="actions">{actions}</div>}
    </header>
  );
}

/** An error, or a shimmer while the first answer loads. */
export function Status({ error, loading }: { error: string | null; loading: boolean }) {
  if (error !== null) return <p className="error">{error}</p>;
  if (loading)
    return (
      <div aria-label="Loading" role="status">
        <div className="skeleton" style={{ width: '60%' }} />
        <div className="skeleton" style={{ width: '85%' }} />
        <div className="skeleton" style={{ width: '40%' }} />
      </div>
    );
  return null;
}

/** Nothing to show, said plainly, with what to do about it. */
export function Empty({ icon = 'inbox', title, children }: { icon?: IconName; title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <Icon name={icon} size={28} />
      <b>{title}</b>
      {children !== undefined && <span className="small">{children}</span>}
    </div>
  );
}

/** A search box with its icon; Enter submits when [onSubmit] is given. */
export function SearchBox({
  value,
  onChange,
  onSubmit,
  placeholder,
  autoFocus,
}: {
  value: string;
  onChange: (v: string) => void;
  onSubmit?: () => void;
  placeholder: string;
  autoFocus?: boolean;
}) {
  return (
    <form
      className="search"
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit?.();
      }}
    >
      <Icon name="search" size={16} />
      <input type="search" value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} aria-label={placeholder} autoFocus={autoFocus} />
    </form>
  );
}

/** A panel that slides in from the right over the page; Escape or the scrim closes it. */
export function Drawer({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', esc);
    const body = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', esc);
      document.body.style.overflow = body;
    };
  }, [onClose]);
  return (
    <>
      <div className="overlay" onClick={onClose} aria-hidden="true" />
      <aside className="drawer" role="dialog" aria-label={title}>
        <div className="drawer-head">
          <b>{title}</b>
          <button className="icon-button" aria-label="Close" onClick={onClose}>
            <Icon name="close" />
          </button>
        </div>
        <div className="drawer-body">{children}</div>
      </aside>
    </>
  );
}

/** Horizontal bars, each against the largest (or [max]). */
export function Bars({ rows, max, format = (v) => String(v) }: { rows: { label: string; value: number | null }[]; max?: number; format?: (v: number) => string }) {
  const top = max ?? Math.max(1, ...rows.map((r) => r.value ?? 0));
  return (
    <div className="bars">
      {rows.map((r) => (
        <div key={r.label} className="bar-row">
          <span className="bar-label" title={r.label}>
            {r.label}
          </span>
          <span className="bar-track">
            <span className="bar-fill" style={{ display: 'block', width: `${Math.min(100, ((r.value ?? 0) / top) * 100)}%` }} />
          </span>
          <span className="bar-value">{r.value === null ? '—' : format(r.value)}</span>
        </div>
      ))}
    </div>
  );
}

type SortDir = 'asc' | 'desc';

/** Rows sorted by a column the user clicks; click again to reverse. */
export function useSort<T>(rows: T[], keys: Record<string, (row: T) => string | number | null>, initial?: { key: string; dir?: SortDir }) {
  const [sort, setSort] = useState<{ key: string; dir: SortDir } | null>(initial === undefined ? null : { key: initial.key, dir: initial.dir ?? 'asc' });
  const sorted = useMemo(() => {
    if (sort === null) return rows;
    const get = keys[sort.key];
    if (get === undefined) return rows;
    const out = [...rows].sort((a, b) => {
      const x = get(a);
      const y = get(b);
      if (x === y) return 0;
      if (x === null) return 1;
      if (y === null) return -1;
      return typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y), 'en', { numeric: true });
    });
    return sort.dir === 'asc' ? out : out.reverse();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- the getters are defined inline per render
  }, [rows, sort]);
  const th = (key: string, label: ReactNode) => {
    const on = sort?.key === key;
    return (
      <th
        className="sortable"
        aria-sort={on ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}
        onClick={() => setSort((s) => (s?.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: 'asc' }))}
      >
        {label}
        {on && <span className="sort-mark">{sort.dir === 'asc' ? '↑' : '↓'}</span>}
      </th>
    );
  };
  return { rows: sorted, th };
}

/** A query parameter of the page's address, read once on the client (a static export). */
export function useQueryParam(name: string): string {
  const [v, setV] = useState('');
  useEffect(() => setV(new URLSearchParams(window.location.search).get(name) ?? ''), [name]);
  return v;
}

export const when = (iso: string | null): string =>
  iso === null ? '—' : new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

export const pct = (v: number | null): string => (v === null ? '—' : `${v}%`);

export function Badge({ tone, children }: { tone: 'ok' | 'warn' | 'bad' | 'muted'; children: ReactNode }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}
