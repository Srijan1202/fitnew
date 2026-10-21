'use client';

import type { AdminOverview } from '@fitos/contracts';
import Link from 'next/link';
import { useState } from 'react';

import { Badge, Header, Status, pct, useGet, when } from '@/components/ui';

const STATE_TONE = { ok: 'ok', stale: 'warn', failing: 'bad', never: 'muted' } as const;

/** §20: provider health (per-endpoint staleness) and the acceptance-rate dashboards. */
export default function Overview() {
  const [days, setDays] = useState(30);
  const { data, error, loading, reload } = useGet<AdminOverview>(`/admin/overview?days=${days}`);

  return (
    <>
      <Header eyebrow="Overview" title="How FITOS is doing">
        Mess menu mirror health, the correction queue, and how people respond to TODAY and to reminders.
      </Header>
      <div className="row">
        {[7, 30, 90].map((d) => (
          <button key={d} className={`button small ${d === days ? 'primary' : ''}`} onClick={() => setDays(d)}>
            Last {d} days
          </button>
        ))}
        <button className="button small" onClick={reload}>Refresh</button>
      </div>
      <Status error={error} loading={loading && data === null} />
      {data !== null && (
        <>
          <section className="tiles">
            <div className="tile">
              <p className="eyebrow">Users</p>
              <p className="big">{data.users.total}</p>
              <p className="muted small">{data.users.active7d} active in the last 7 days</p>
            </div>
            <Link href="/mess" className="tile link">
              <p className="eyebrow">Corrections waiting</p>
              <p className="big">{data.pendingCorrections}</p>
              <p className="muted small">Review the queue →</p>
            </Link>
            <div className="tile">
              <p className="eyebrow">Menu endpoints</p>
              <p className="big">
                {data.endpoints.filter((e) => e.state === 'ok').length}/{data.endpoints.length}
              </p>
              <p className="muted small">healthy right now</p>
            </div>
          </section>

          <h2>Menu mirror — per endpoint</h2>
          <table>
            <thead>
              <tr>
                <th>Mess</th><th>State</th><th>Last success</th><th>Since</th><th>Last change</th><th>Failures</th><th>Last error</th>
              </tr>
            </thead>
            <tbody>
              {data.endpoints.map((e) => (
                <tr key={e.code}>
                  <td>{e.label}<div className="muted small">{e.code}</div></td>
                  <td><Badge tone={STATE_TONE[e.state]}>{e.state}</Badge></td>
                  <td>{when(e.lastSuccessAt)}</td>
                  <td>{e.hoursSinceSuccess === null ? '—' : `${e.hoursSinceSuccess} h`}</td>
                  <td>{when(e.lastChangedAt)}</td>
                  <td>{e.consecutiveFailures}</td>
                  <td>{e.lastError ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="muted small">Stale: no successful fetch for over 26 hours. Failing: 3 or more failures in a row.</p>

          <h2>TODAY suggestions — last {data.days} days</h2>
          {data.recommendations.length === 0 ? (
            <p className="muted">No TODAY events in this window.</p>
          ) : (
            <table>
              <thead>
                <tr><th>Kind</th><th>Shown</th><th>Opened</th><th>Accepted</th><th>Dismissed</th><th>Completed</th><th>Accept rate</th><th>Dismiss rate</th></tr>
              </thead>
              <tbody>
                {data.recommendations.map((r) => (
                  <tr key={r.kind}>
                    <td>{r.kind}</td><td>{r.shown}</td><td>{r.opened}</td><td>{r.accepted}</td><td>{r.dismissed}</td><td>{r.completed}</td>
                    <td><b>{pct(r.acceptRate)}</b></td><td>{pct(r.dismissRate)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          <h2>Reminders — last {data.days} days</h2>
          {data.notifications.length === 0 ? (
            <p className="muted">No reminders sent in this window.</p>
          ) : (
            <table>
              <thead>
                <tr><th>Kind</th><th>Sent</th><th>Opened</th><th>Cancelled (done first)</th><th>Open rate</th></tr>
              </thead>
              <tbody>
                {data.notifications.map((r) => (
                  <tr key={r.kind}>
                    <td>{r.kind}</td><td>{r.sent}</td><td>{r.opened}</td><td>{r.cancelled}</td><td><b>{pct(r.openRate)}</b></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <p className="muted small">Generated {when(data.generatedAt)}.</p>
        </>
      )}
    </>
  );
}
