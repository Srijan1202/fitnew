'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, type FormEvent, type ReactNode } from 'react';

import { errorText } from '@/lib/api';
import { AuthProvider, useAuth } from '@/lib/auth';

const NAV = [
  { href: '/', label: 'Overview' },
  { href: '/mess', label: 'Mess corrections' },
  { href: '/foods', label: 'Foods' },
  { href: '/missing-foods', label: 'Missing foods' },
  { href: '/community-foods', label: 'Community foods' },
  { href: '/exercises', label: 'Exercises' },
  { href: '/premium', label: 'Premium' },
  { href: '/feedback', label: 'Feedback' },
  { href: '/flags', label: 'App features' },
  { href: '/users', label: 'Support' },
  { href: '/admins', label: 'Admins' },
  { href: '/audit', label: 'Audit log' },
];

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
      <p className="eyebrow">FITOS</p>
      <h1>Admin</h1>
      <p className="lede">Sign in with the account you use in the app. Only administrators get in; the server checks on every request.</p>
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
    </main>
  );
}

function Gate({ children }: { children: ReactNode }) {
  const { state, signOutNow, recheck } = useAuth();
  const path = usePathname();
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
      return (
        <div className="shell">
          <nav className="nav">
            <p className="eyebrow">FITOS admin</p>
            {NAV.map((n) => (
              <Link key={n.href} href={n.href} className={(n.href === '/' ? path === '/' : path.startsWith(n.href)) ? 'active' : ''}>
                {n.label}
              </Link>
            ))}
            <div className="nav-foot">
              <p className="muted small">{state.email}</p>
              <button className="button small" onClick={() => void signOutNow()}>Sign out</button>
            </div>
          </nav>
          <main className="content">{children}</main>
        </div>
      );
  }
}

export function Shell({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <Gate>{children}</Gate>
    </AuthProvider>
  );
}
