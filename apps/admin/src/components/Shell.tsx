'use client';

import type { AdminDemoApproval, AdminFeedbackCounts } from '@fitos/contracts';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from 'react';

import { Icon, type IconName } from '@/components/icons';
import { SAVED_EVENT, api, errorText } from '@/lib/api';
import { AuthProvider, useAuth } from '@/lib/auth';
import { type Mode, applyMode, saveMode, savedMode } from '@/lib/mode';

type CountKey = 'feedback' | 'premium' | 'mess' | 'missing' | 'demos';
type NavItem = { href: string; label: string; icon: IconName; count?: CountKey; keywords?: string };

/** Owner 2026-10-30: the pages in four short groups; beta 5.3: icons and what waits. */
const NAV: { group: string | null; items: NavItem[] }[] = [
  { group: null, items: [{ href: '/', label: 'Overview', icon: 'overview', keywords: 'dashboard home health' }] },
  {
    group: 'People',
    items: [
      { href: '/feedback', label: 'Feedback', icon: 'feedback', count: 'feedback', keywords: 'bugs reports replies' },
      { href: '/users', label: 'Support', icon: 'support', keywords: 'user lookup email person rewards' },
      { href: '/premium', label: 'Premium', icon: 'premium', count: 'premium', keywords: 'requests members' },
      // Beta 5.8 (ADR-057).
      { href: '/social', label: 'Community', icon: 'world', keywords: 'friends clubs world board leaderboard reports handles' },
    ],
  },
  {
    group: 'Food & training',
    items: [
      { href: '/mess', label: 'Mess corrections', icon: 'mess', count: 'mess', keywords: 'dish menu' },
      { href: '/mess-ratings', label: 'Mess ratings', icon: 'ratings' },
      { href: '/foods', label: 'Foods', icon: 'foods', keywords: 'nutrition library' },
      { href: '/missing-foods', label: 'Missing foods', icon: 'missing', count: 'missing', keywords: 'requests' },
      { href: '/community-foods', label: 'Community foods', icon: 'community' },
      { href: '/exercises', label: 'Exercises', icon: 'exercises', keywords: 'library' },
      { href: '/exercise-demos', label: 'Exercise demos', icon: 'demos', count: 'demos', keywords: 'animations approve reject' },
    ],
  },
  {
    group: 'App',
    items: [
      { href: '/flags', label: 'App features', icon: 'flags', keywords: 'flags switches' },
      { href: '/announce', label: 'Announce update', icon: 'announce', keywords: 'push notification release' },
      { href: '/admins', label: 'Admins', icon: 'admins', keywords: 'roles' },
      { href: '/audit', label: 'Audit log', icon: 'audit', keywords: 'history' },
    ],
  },
];
const PAGES = NAV.flatMap((g) => g.items);

const isActive = (href: string, path: string) => (href === '/' ? path === '/' : path.startsWith(href));

function Brand() {
  return (
    <Link href="/" className="brand">
      {/* eslint-disable-next-line @next/next/no-img-element -- a static export: no image optimiser */}
      <img src="/icon.png" alt="" />
      <b>FITOS <span>Admin</span></b>
    </Link>
  );
}

/**
 * Phones: each table row is shown as a card, so every cell names its column
 * (the `data-label` the CSS prints) from the table's header — set here once
 * for every page instead of in each table.
 */
function useTableLabels(path: string) {
  useEffect(() => {
    const label = () => {
      for (const table of document.querySelectorAll('main table')) {
        const heads = [...table.querySelectorAll('thead th')].map((th) => th.textContent?.trim() ?? '');
        for (const row of table.querySelectorAll('tbody tr')) {
          [...row.children].forEach((cell, i) => {
            const name = heads[i];
            if (name !== undefined && name !== '' && cell.getAttribute('data-label') !== name) cell.setAttribute('data-label', name);
          });
        }
      }
    };
    label();
    const seen = new MutationObserver(label);
    const main = document.querySelector('main');
    if (main !== null) seen.observe(main, { childList: true, subtree: true });
    return () => seen.disconnect();
  }, [path]);
}

/** Beta 5.3: what waits on each page, read again after every change. */
function useCounts(path: string): Partial<Record<CountKey, number>> {
  const [counts, setCounts] = useState<Partial<Record<CountKey, number>>>({});
  const load = useCallback(async () => {
    const take = async <T,>(p: Promise<T>): Promise<T | null> => p.catch(() => null);
    const [feedback, premium, mess, missing, decided, manifest] = await Promise.all([
      take(api<AdminFeedbackCounts>('GET', '/admin/feedback/counts')),
      take(api<{ items: unknown[] }>('GET', '/admin/premium/requests?status=pending')),
      take(api<{ items: unknown[] }>('GET', '/admin/mess/corrections?status=pending')),
      take(api<{ items: unknown[] }>('GET', '/admin/foods/requests?status=open')),
      take(api<{ items: AdminDemoApproval[] }>('GET', '/admin/exercise-demos')),
      take(fetch('/demos/manifest.json').then((r) => r.json() as Promise<{ demos: { slug: string }[] }>)),
    ]);
    const seen = new Set((decided?.items ?? []).map((d) => d.slug));
    setCounts({
      ...(feedback !== null && { feedback: feedback.untagged }),
      ...(premium !== null && { premium: premium.items.length }),
      ...(mess !== null && { mess: mess.items.length }),
      ...(missing !== null && { missing: missing.items.length }),
      ...(decided !== null && manifest !== null && { demos: manifest.demos.filter((d) => !seen.has(d.slug)).length }),
    });
  }, []);
  useEffect(() => {
    void load();
  }, [load, path]);
  useEffect(() => {
    const again = () => void load();
    window.addEventListener(SAVED_EVENT, again);
    return () => window.removeEventListener(SAVED_EVENT, again);
  }, [load]);
  return counts;
}

/* ------------------------------------------------------------- toasts -- */

type Toast = { id: number; text: string; bad?: boolean };
let toastId = 0;
const TOAST_EVENT = 'fitos:toast';

/** A short message at the bottom right ("Saved" after every change). */
export function toast(text: string, bad = false): void {
  window.dispatchEvent(new CustomEvent<Toast>(TOAST_EVENT, { detail: { id: ++toastId, text, bad } }));
}

function Toasts() {
  const [items, setItems] = useState<Toast[]>([]);
  useEffect(() => {
    const add = (t: Toast) => {
      setItems((xs) => [...xs.slice(-2), t]);
      setTimeout(() => setItems((xs) => xs.filter((x) => x.id !== t.id)), 2600);
    };
    const onToast = (e: Event) => add((e as CustomEvent<Toast>).detail);
    const onSaved = () => add({ id: ++toastId, text: 'Saved' });
    window.addEventListener(TOAST_EVENT, onToast);
    window.addEventListener(SAVED_EVENT, onSaved);
    return () => {
      window.removeEventListener(TOAST_EVENT, onToast);
      window.removeEventListener(SAVED_EVENT, onSaved);
    };
  }, []);
  return (
    <div className="toasts" role="status" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={`toast${t.bad ? ' bad' : ''}`}>
          <Icon name={t.bad ? 'alert' : 'check'} />
          {t.text}
        </div>
      ))}
    </div>
  );
}

/* ------------------------------------------------- command palette -- */

type Command = { id: string; group: string; label: string; icon: IconName; hint?: string; go: () => void };

/** Ctrl+K (or /): jump to a page, or search people, foods and exercises. */
function Palette({ onClose }: { onClose: () => void }) {
  const router = useRouter();
  const [q, setQ] = useState('');
  const [sel, setSel] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => input.current?.focus(), []);

  const go = useCallback(
    (href: string) => {
      onClose();
      router.push(href);
    },
    [onClose, router],
  );

  const commands = useMemo<Command[]>(() => {
    const term = q.trim().toLowerCase();
    const pages = PAGES.filter((p) => term === '' || `${p.label} ${p.keywords ?? ''}`.toLowerCase().includes(term)).map((p) => ({
      id: p.href,
      group: 'Pages',
      label: p.label,
      icon: p.icon,
      go: () => go(p.href),
    }));
    if (term === '') return pages;
    const enc = encodeURIComponent(q.trim());
    const searches: Command[] = [
      { id: 's-user', group: 'Search', label: `Find the person “${q.trim()}”`, icon: 'support', hint: 'email or id', go: () => go(`/users?q=${enc}`) },
      { id: 's-food', group: 'Search', label: `Foods matching “${q.trim()}”`, icon: 'foods', go: () => go(`/foods?q=${enc}`) },
      { id: 's-ex', group: 'Search', label: `Exercises matching “${q.trim()}”`, icon: 'exercises', go: () => go(`/exercises?q=${enc}`) },
    ];
    return [...pages, ...searches];
  }, [q, go]);

  useEffect(() => setSel(0), [q]);

  const key = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSel((s) => Math.min(s + 1, commands.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSel((s) => Math.max(s - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      commands[sel]?.go();
    } else if (e.key === 'Escape') {
      onClose();
    }
  };

  return (
    <>
      <div className="overlay" onClick={onClose} aria-hidden="true" />
      <div className="palette" role="dialog" aria-label="Search" onKeyDown={key}>
        <div className="palette-input">
          <Icon name="search" />
          <input ref={input} value={q} onChange={(e) => setQ(e.target.value)} placeholder="Go to a page, or find a person, food or exercise" aria-label="Search" />
          <kbd>Esc</kbd>
        </div>
        <div className="palette-list" role="listbox">
          {commands.length === 0 && <p className="muted small" style={{ padding: '10px 12px' }}>Nothing matches.</p>}
          {commands.map((c, i) => {
            const head = c.group !== commands[i - 1]?.group ? <div className="palette-group">{c.group}</div> : null;
            return (
              <div key={c.id}>
                {head}
                <button className={`palette-item${i === sel ? ' selected' : ''}`} role="option" aria-selected={i === sel} onMouseEnter={() => setSel(i)} onClick={c.go}>
                  <Icon name={c.icon} />
                  {c.label}
                  {c.hint !== undefined && <span className="hint">{c.hint}</span>}
                </button>
              </div>
            );
          })}
        </div>
        <div className="palette-foot">
          <span><kbd>↑</kbd> <kbd>↓</kbd> move</span>
          <span><kbd>Enter</kbd> open</span>
        </div>
      </div>
    </>
  );
}

/* --------------------------------------------------------- top menus -- */

function ModeMenu() {
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState<Mode>('system');
  useEffect(() => {
    setMode(savedMode());
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const follow = () => savedMode() === 'system' && applyMode('system');
    media.addEventListener('change', follow);
    return () => media.removeEventListener('change', follow);
  }, []);
  useClickAway(open, () => setOpen(false));
  const choose = (m: Mode) => {
    saveMode(m);
    setMode(m);
    setOpen(false);
  };
  const icon: IconName = mode === 'light' ? 'sun' : mode === 'dark' ? 'moon' : 'monitor';
  return (
    <div className="menu" data-menu>
      <button className="icon-button" aria-label="Light or dark" aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <Icon name={icon} />
      </button>
      {open && (
        <div className="menu-pop">
          <div className="menu-label">Appearance</div>
          {(
            [
              ['system', 'Like this computer', 'monitor'],
              ['light', 'Cobalt Light', 'sun'],
              ['dark', 'Cobalt', 'moon'],
            ] as const
          ).map(([m, label, i]) => (
            <button key={m} className={mode === m ? 'on' : ''} onClick={() => choose(m)}>
              <Icon name={i} size={16} />
              {label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** Closes a popup on a click outside any `[data-menu]`. */
function useClickAway(active: boolean, close: () => void) {
  useEffect(() => {
    if (!active) return;
    const away = (e: MouseEvent) => {
      if (!(e.target instanceof Element) || e.target.closest('[data-menu]') === null) close();
    };
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && close();
    window.addEventListener('mousedown', away);
    window.addEventListener('keydown', esc);
    return () => {
      window.removeEventListener('mousedown', away);
      window.removeEventListener('keydown', esc);
    };
  }, [active, close]);
}

/** Who is signed in, and Sign out. */
function Account({ email, onSignOut }: { email: string | null; onSignOut: () => void }) {
  return (
    <div className="side-foot">
      <span className="avatar">{(email ?? '?').slice(0, 1)}</span>
      <span className="who" title={email ?? undefined}>{email}</span>
      <button className="icon-button" aria-label="Sign out" title="Sign out" onClick={onSignOut}>
        <Icon name="logout" size={16} />
      </button>
    </div>
  );
}

/* ------------------------------------------------------------ sign-in -- */

function SignIn() {
  const { signInGoogle, signInEmail } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      await signInEmail(email, password);
    } catch (err) {
      setError(errorText(err));
    }
  };
  return (
    <main className="narrow">
      <div className="card">
        <Brand />
        <h1 style={{ marginTop: 24 }}>Sign in</h1>
        <p className="lede">With the account you use in the app. Only administrators get in.</p>
        <button className="button primary wide" onClick={() => signInGoogle().catch((err: unknown) => setError(errorText(err)))}>
          Sign in with Google
        </button>
        <hr />
        <form onSubmit={submit} className="stack">
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="username" />
          </label>
          <label>
            Password
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" />
          </label>
          <button className="button wide" type="submit">
            Sign in
          </button>
        </form>
        {error !== null && <p className="error">{error}</p>}
      </div>
    </main>
  );
}

function Gate({ children }: { children: ReactNode }) {
  const { state, signOutNow, recheck } = useAuth();
  switch (state.kind) {
    case 'loading':
      return (
        <main className="narrow">
          <p className="muted">Loading…</p>
        </main>
      );
    case 'not-configured':
      return (
        <main className="narrow">
          <h1>Not set up</h1>
          <p className="lede">
            Copy <code>apps/admin/.env.example</code> to <code>.env.local</code> and fill in the Firebase client config, then restart.
          </p>
        </main>
      );
    case 'signed-out':
      return <SignIn />;
    case 'error':
      return (
        <main className="narrow">
          <h1>Cannot reach the API</h1>
          <p className="lede">{state.message}</p>
          <p className="muted">
            Is the API running (the Docker container), and is <code>FITOS_API_URL</code> right?
          </p>
          <button className="button" onClick={() => void recheck()}>
            Try again
          </button>
        </main>
      );
    case 'not-admin':
      return (
        <main className="narrow">
          <h1>Not an administrator</h1>
          <p className="lede">{state.email ?? 'This account'} is signed in but has no admin role.</p>
          <p>
            Give it the role on the PC, then press <b>Check again</b>:
          </p>
          <pre>docker exec fitos-api node apps/api/dist/scripts/admin-grant.js {state.email ?? 'you@example.com'}</pre>
          <div className="row">
            <button className="button primary" onClick={() => void recheck()}>
              Check again
            </button>
            <button className="button" onClick={() => void signOutNow()}>
              Sign out
            </button>
          </div>
        </main>
      );
    case 'admin':
      return (
        <Admin email={state.email} onSignOut={() => void signOutNow()}>
          {children}
        </Admin>
      );
  }
}

/** The signed-in panel: a sidebar and a top bar; on a phone the sidebar is a drawer. */
function Admin({ email, onSignOut, children }: { email: string | null; onSignOut: () => void; children: ReactNode }) {
  const path = usePathname();
  const [open, setOpen] = useState(false);
  const [palette, setPalette] = useState(false);
  const counts = useCounts(path);
  useTableLabels(path);
  // A new page closes the drawer and the search; so does Escape.
  useEffect(() => {
    setOpen(false);
    setPalette(false);
  }, [path]);
  useEffect(() => {
    const keys = (e: KeyboardEvent) => {
      const typing = e.target instanceof HTMLElement && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName);
      if ((e.key === 'k' && (e.ctrlKey || e.metaKey)) || (e.key === '/' && !typing)) {
        e.preventDefault();
        setPalette(true);
      } else if (e.key === 'Escape') {
        setOpen(false);
      }
    };
    window.addEventListener('keydown', keys);
    return () => window.removeEventListener('keydown', keys);
  }, []);
  const current = PAGES.find((n) => isActive(n.href, path));
  const group = NAV.find((g) => g.items.includes(current as NavItem))?.group;

  return (
    <div className="shell">
      <div className={`scrim${open ? ' open' : ''}`} onClick={() => setOpen(false)} aria-hidden="true" />
      <nav className={`side${open ? ' open' : ''}`} aria-label="Pages">
        <Brand />
        {NAV.map((g) => (
          <div key={g.group ?? 'top'} className="nav-group">
            {g.group !== null && <p className="eyebrow">{g.group}</p>}
            {g.items.map((n) => {
              const count = n.count === undefined ? undefined : counts[n.count];
              return (
                <Link
                  key={n.href}
                  href={n.href}
                  className={isActive(n.href, path) ? 'active' : ''}
                  aria-current={isActive(n.href, path) ? 'page' : undefined}
                >
                  <Icon name={n.icon} />
                  <span className="nav-label">{n.label}</span>
                  {count !== undefined && count > 0 && (
                    <span className="nav-count" aria-label={`${count} waiting`}>
                      {count > 99 ? '99+' : count}
                    </span>
                  )}
                </Link>
              );
            })}
          </div>
        ))}
        <Account email={email} onSignOut={onSignOut} />
      </nav>
      <div className="main-col">
        <header className="topbar">
          <button className="icon-button menu-button" aria-label="Open the menu" aria-expanded={open} onClick={() => setOpen(true)}>
            <Icon name="menu" />
          </button>
          <span className="crumb">
            {group !== undefined && group !== null && <>{group} / </>}
            <b>{current?.label ?? 'FITOS Admin'}</b>
          </span>
          <button className="search-button" onClick={() => setPalette(true)} aria-label="Search">
            <Icon name="search" size={16} />
            <span className="search-text">Search</span>
            <kbd>Ctrl K</kbd>
          </button>
          <ModeMenu />
        </header>
        <main className="content">{children}</main>
      </div>
      {palette && <Palette onClose={() => setPalette(false)} />}
      <Toasts />
    </div>
  );
}

export function Shell({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <Gate>{children}</Gate>
    </AuthProvider>
  );
}
