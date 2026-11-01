'use client';

import type { AdminOverview } from '@fitos/contracts';
import Link from 'next/link';
import { useState } from 'react';

import { Icon, type IconName } from '@/components/icons';
import { Badge, Bars, Empty, Header, Status, pct, useGet, when } from '@/components/ui';

const STATE_TONE = { ok: 'ok', stale: 'warn', failing: 'bad', never: 'muted' } as const;

/** One number on the dashboard; a link when it leads somewhere to act. */
function Stat({ label, value, detail, icon, href }: { label: string; value: string | number; detail: string; icon: IconName; href?: string }) {
  const body = (
    <>
      <span className="tile-icon">
        <Icon name={icon} size={17} />
      </span>
      <p className="eyebrow">{label}</p>
      <p className="big">{value}</p>
      <p className="muted small">{detail}</p>
    </>
  );
  return href === undefined ? (
    <div className="tile">{body}</div>
  ) : (
    <Link href={href} className="tile link">
      {body}
    </Link>
  );
}

/** §20, beta 5.3: the dashboard — the numbers first, then how people respond, then the menu mirror's health. */
export default function Overview() {
  const [days, setDays] = useState(30);
  const { data, error, loading, reload } = useGet<AdminOverview>(`/admin/overview?days=${days}`);
  const healthy = data?.endpoints.filter((e) => e.state === 'ok').length ?? 0;

  return (
    <>
      <Header
        eyebrow="Overview"
        title="How FITOS is doing"
        actions={
          <>
            <div className="segmented" role="group" aria-label="Period">
              {[7, 30, 90].map((d) => (
                <button key={d} className={d === days ? 'active' : ''} onClick={() => setDays(d)}>
                  {d} days
                </button>
              ))}
            </div>
            <button className="icon-button" aria-label="Refresh" title="Refresh" onClick={reload}>
              <Icon name="refresh" />
            </button>
          </>
        }
      >
        People, the correction queue, how people respond to TODAY suggestions and to reminders, and the mess menu mirror&apos;s health.
      </Header>
      <Status error={error} loading={loading && data === null} />
      {data !== null && (
        <>
          <section className="tiles">
            <Stat label="People" value={data.users.total} detail={`${data.users.active7d} active in the last 7 days`} icon="users" href="/users" />
            <Stat
              label="Active this week"
              value={data.users.total === 0 ? '—' : `${Math.round((data.users.active7d / data.users.total) * 100)}%`}
              detail="of everyone signed up"
              icon="activity"
            />
            <Stat label="Corrections waiting" value={data.pendingCorrections} detail="Review the queue →" icon="mess" href="/mess" />
            <Stat
              label="Menu endpoints"
              value={`${healthy}/${data.endpoints.length}`}
              detail={healthy === data.endpoints.length ? 'all healthy' : 'need a look'}
              icon="activity"
            />
          </section>

          <div className="panels">
            <section className="card">
              <div className="panel-head">
                <h3>TODAY suggestions accepted</h3>
                <span className="muted small">last {data.days} days</span>
              </div>
              {data.recommendations.length === 0 ? (
                <Empty title="No TODAY events yet">Nothing was shown in this period.</Empty>
              ) : (
                <>
                  <Bars rows={data.recommendations.map((r) => ({ label: r.kind, value: r.acceptRate }))} max={100} format={(v) => `${v}%`} />
                  <p className="muted small" style={{ marginBottom: 0 }}>
                    {data.recommendations.reduce((s, r) => s + r.shown, 0)} shown ·{' '}
                    {data.recommendations.reduce((s, r) => s + r.accepted, 0)} accepted ·{' '}
                    {data.recommendations.reduce((s, r) => s + r.dismissed, 0)} dismissed
                  </p>
                </>
              )}
            </section>
            <section className="card">
              <div className="panel-head">
                <h3>Reminders opened</h3>
                <span className="muted small">last {data.days} days</span>
              </div>
              {data.notifications.length === 0 ? (
                <Empty title="No reminders sent">Nothing went out in this period.</Empty>
              ) : (
                <>
                  <Bars rows={data.notifications.map((r) => ({ label: r.kind, value: r.openRate }))} max={100} format={(v) => `${v}%`} />
                  <p className="muted small" style={{ marginBottom: 0 }}>
                    {data.notifications.reduce((s, r) => s + r.sent, 0)} sent · {data.notifications.reduce((s, r) => s + r.opened, 0)} opened ·{' '}
                    {data.notifications.reduce((s, r) => s + r.cancelled, 0)} cancelled (done first)
                  </p>
                </>
              )}
            </section>
          </div>

          <details className="card" style={{ marginTop: 14 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 600 }}>The numbers behind the charts</summary>
            {data.recommendations.length > 0 && (
              <table>
                <thead>
                  <tr>
                    <th>Kind</th><th>Shown</th><th>Opened</th><th>Accepted</th><th>Dismissed</th><th>Completed</th><th>Accept rate</th><th>Dismiss rate</th>
                  </tr>
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
            {data.notifications.length > 0 && (
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
          </details>

          <h2>Menu mirror</h2>
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
          <p className="muted small">Stale: no successful fetch for over 26 hours. Failing: 3 or more failures in a row. Generated {when(data.generatedAt)}.</p>
        </>
      )}
    </>
  );
}
