'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState, type FormEvent, type ReactNode } from 'react';

import { errorText } from '@/lib/api';
import { AuthProvider, useAuth } from '@/lib/auth';

/** Owner 2026-10-30: the pages in four short groups instead of one long list. */
const NAV: { group: string | null; items: { href: string; label: string }[] }[] = [
  { group: null, items: [{ href: '/', label: 'Overview' }] },
  {
    group: 'People',
    items: [
      { href: '/feedback', label: 'Feedback' },
      { href: '/users', label: 'Support' },
      { href: '/premium', label: 'Premium' },
    ],
  },
  {
    group: 'Food & training',
    items: [
      { href: '/mess', label: 'Mess corrections' },
      { href: '/mess-ratings', label: 'Mess ratings' },
      { href: '/foods', label: 'Foods' },
      { href: '/missing-foods', label: 'Missing foods' },
      { href: '/community-foods', label: 'Community foods' },
      { href: '/exercises', label: 'Exercises' },
    ],
  },
  {
    group: 'App',
    items: [
      { href: '/flags', label: 'App features' },
      { href: '/announce', label: 'Announce update' },
      { href: '/admins', label: 'Admins' },
      { href: '/audit', label: 'Audit log' },
    ],
  },
];

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
      <button
        className="button primary wide"
        onClick={() => signInGoogle().catch((err: unknown) => setError(errorText(err)))}
      >
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
      return <main className="narrow"><p className="muted">Loading…</p></main>;
    case 'not-configured':
      return (
        <main className="narrow">
          <h1>Not set up</h1>
          <p className="lede">Copy <code>apps/admin/.env.example</code> to <code>.env.local</code> and fill in the Firebase client config, then restart.</p>
        </main>
      );
    case 'signed-out':
      return <SignIn />;
    case 'error':
      return (
        <main className="narrow">
          <h1>Cannot reach the API</h1>
          <p className="lede">{state.message}</p>
          <p className="muted">Is the API running (the Docker container), and is <code>FITOS_API_URL</code> right?</p>
          <button className="button" onClick={() => void recheck()}>Try again</button>
        </main>
      );
    case 'not-admin':
      return (
        <main className="narrow">
          <h1>Not an administrator</h1>
          <p className="lede">{state.email ?? 'This account'} is signed in but has no admin role.</p>
          <p>Give it the role on the PC, then press <b>Check again</b>:</p>
          <pre>docker exec fitos-api node apps/api/dist/scripts/admin-grant.js {state.email ?? 'you@example.com'}</pre>
          <div className="row">
            <button className="button primary" onClick={() => void recheck()}>Check again</button>
            <button className="button" onClick={() => void signOutNow()}>Sign out</button>
          </div>
        </main>
      );
    case 'admin':
      return <Admin email={state.email} onSignOut={() => void signOutNow()}>{children}</Admin>;
  }
}

/** The signed-in panel: a sidebar on a PC; a top bar and a drawer on a phone. */
function Admin({ email, onSignOut, children }: { email: string | null; onSignOut: () => void; children: ReactNode }) {
  const path = usePathname();
  const [open, setOpen] = useState(false);
  useTableLabels(path);
  // A new page closes the drawer; so does Escape.
  useEffect(() => setOpen(false), [path]);
  useEffect(() => {
    if (!open) return;
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [open]);
  const current = NAV.flatMap((g) => g.items).find((n) => isActive(n.href, path))?.label ?? 'FITOS Admin';

  return (
    <div className="shell">
      <header className="topbar">
        <button className="icon-button" aria-label="Open the menu" aria-expanded={open} onClick={() => setOpen(true)}>☰</button>
        <span className="title">{current}</span>
        <Brand />
      </header>
      <div className={`scrim${open ? ' open' : ''}`} onClick={() => setOpen(false)} aria-hidden="true" />
      <nav className={`side${open ? ' open' : ''}`} aria-label="Pages">
        <Brand />
        {NAV.map((g) => (
          <div key={g.group ?? 'top'} className="nav-group">
            {g.group !== null && <p className="eyebrow">{g.group}</p>}
            {g.items.map((n) => (
              <Link key={n.href} href={n.href} className={isActive(n.href, path) ? 'active' : ''} aria-current={isActive(n.href, path) ? 'page' : undefined}>
                {n.label}
              </Link>
            ))}
          </div>
        ))}
        <div className="side-foot">
          <p className="muted small" title={email ?? undefined}>{email}</p>
          <button className="button small" onClick={onSignOut}>Sign out</button>
        </div>
      </nav>
      <main className="content">{children}</main>
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
