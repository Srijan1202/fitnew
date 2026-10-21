'use client';

import type { UserSupport } from '@fitos/contracts';
import { useState, type FormEvent } from 'react';

import { Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/**
 * §20: user support lookup — counts and dates only. No body photos, no food
 * log contents, no weights. Every lookup is written to the audit log.
 */
export default function Support() {
  const [q, setQ] = useState('');
  const [user, setUser] = useState<UserSupport | null>(null);
  const [error, setError] = useState<string | null>(null);

  const lookup = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setUser(null);
    const v = q.trim();
    const param = /^[0-9a-f-]{36}$/i.test(v) ? `id=${v}` : `email=${encodeURIComponent(v)}`;
    try {
      setUser(await api<UserSupport>('GET', `/admin/users?${param}`));
    } catch (err) {
      setError(errorText(err));
    }
  };

  return (
    <>
      <Header eyebrow="Support" title="Look up an account">
        By email or user id. Shows what helps answer a support question — never food log contents, weights or photos.
        Each lookup is recorded in the audit log.
      </Header>
      <form className="row" onSubmit={lookup}>
        <input className="grow" placeholder="student@vit.ac.in or a user id" value={q} onChange={(e) => setQ(e.target.value)} required />
        <button className="button primary" type="submit">Look up</button>
      </form>
      {error !== null && <p className="error">{error}</p>}
      {user !== null && (
        <article className="card">
          <h3>{user.displayName ?? 'No name yet'}</h3>
          <p className="muted small">{user.email ?? 'no email'} · {user.userId}</p>
          <dl className="facts">
            <dt>Joined</dt><dd>{when(user.createdAt)}</dd>
            <dt>Time zone</dt><dd>{user.timezone}</dd>
            <dt>Onboarding</dt><dd>{user.onboardingStage ?? '—'}</dd>
            <dt>Goal</dt><dd>{user.goal ?? '—'}</dd>
            <dt>Programme</dt><dd>{user.programme === null ? 'none' : `${user.programme.name} (${user.programme.splitType})`}</dd>
            <dt>Workouts</dt><dd>{user.counts.sessions} · last {when(user.lastActivity.session)}</dd>
            <dt>Food logs</dt><dd>{user.counts.foodLogs} · last {when(user.lastActivity.foodLog)}</dd>
            <dt>Weigh-ins</dt><dd>{user.counts.weighIns} · last {user.lastActivity.weighIn ?? '—'}</dd>
            <dt>Check-ins</dt><dd>{user.counts.checkIns} · last {user.lastActivity.checkIn ?? '—'}</dd>
            <dt>FITOS AI, 7 days</dt><dd>{user.counts.aiCalls7d} calls</dd>
            <dt>Reminders</dt><dd>{user.notifications.enabled ? `on, ${user.notifications.tone}` : 'off'}</dd>
          </dl>
        </article>
      )}
    </>
  );
}
