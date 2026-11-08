'use client';

import type { AdminClubList, AdminCommunityMemberList, AdminCommunityReport, AdminCommunityReportList } from '@fitos/contracts';
import { COUNTRIES } from '@fitos/contracts';
import { useState } from 'react';

import { Badge, Header, SearchBox, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

type Tab = 'reports' | 'members' | 'clubs';

const REASONS: Record<AdminCommunityReport['reason'], string> = {
  handle: 'Handle',
  'club-name': 'Club name',
  cheating: 'Cheating',
  harassment: 'Harassment',
  other: 'Other',
};

const country = (c: string | null): string => (c === null ? '—' : (COUNTRIES as Record<string, string>)[c] ?? c);

/**
 * Beta 5.8 (ADR-057): Community's reports, members and clubs. Hide takes a
 * member off every board and out of search; Rename gives an unsuitable
 * handle a new one; Delete removes a club. Everything is audited. Counts and
 * health data are never shown here.
 */
export default function Social() {
  const [tab, setTab] = useState<Tab>('reports');
  const [status, setStatus] = useState<'open' | 'closed'>('open');
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [sure, setSure] = useState<string | null>(null);

  const reports = useGet<AdminCommunityReportList>(tab === 'reports' ? `/admin/community/reports?status=${status}` : null);
  const members = useGet<AdminCommunityMemberList>(tab === 'members' ? `/admin/community/members${query === '' ? '' : `?q=${encodeURIComponent(query)}`}` : null);
  const clubs = useGet<AdminClubList>(tab === 'clubs' ? '/admin/community/clubs' : null);

  const act = async (method: 'POST' | 'PATCH' | 'DELETE', path: string, body: unknown, reload: () => void) => {
    setError(null);
    try {
      await api<unknown>(method, path, body);
      setSure(null);
      reload();
    } catch (e) {
      setError(errorText(e));
    }
  };

  const hide = (userId: string, hidden: boolean, reload: () => void) => act('PATCH', `/admin/community/members/${userId}`, { hidden }, reload);
  const rename = (userId: string, current: string, reload: () => void) => {
    const handle = window.prompt(`A new handle for @${current} (3–20 of a–z, 0–9, _):`, `member_${userId.slice(0, 6)}`);
    if (handle !== null && handle.trim() !== '') void act('PATCH', `/admin/community/members/${userId}`, { handle: handle.trim() }, reload);
  };

  return (
    <>
      <Header eyebrow="People" title="Community">
        Friends, clubs and the world board (beta 5.8). People join with a handle; they are never shown here with their name or email. Hide
        takes someone off every board and out of search; Rename replaces an unsuitable handle; Delete removes a club for everyone. All are
        audited. The App features page switches Community off for everyone.
      </Header>
      <p>
        {(['reports', 'members', 'clubs'] as const).map((t) => (
          <button key={t} className={`button${tab === t ? ' active' : ''}`} onClick={() => setTab(t)}>
            {t}
          </button>
        ))}
      </p>
      {error !== null && <p className="error">{error}</p>}

      {tab === 'reports' && (
        <>
          <p>
            {(['open', 'closed'] as const).map((s) => (
              <button key={s} className={`button small${status === s ? ' active' : ''}`} onClick={() => setStatus(s)}>
                {s}
              </button>
            ))}
          </p>
          <Status error={reports.error} loading={reports.loading} />
          <table>
            <thead><tr><th>Reported</th><th>Why</th><th>By</th><th>When</th><th /></tr></thead>
            <tbody>
              {(reports.data?.items ?? []).map((r) => (
                <tr key={r.id}>
                  <td>
                    {r.target.handle !== null && <strong>@{r.target.handle}</strong>}
                    {r.target.clubName !== null && <strong>Club: {r.target.clubName}</strong>}
                    {r.target.hidden === true && <> <Badge tone="muted">hidden</Badge></>}
                  </td>
                  <td>
                    {REASONS[r.reason]}
                    {r.note !== null && <div className="muted small">&ldquo;{r.note}&rdquo;</div>}
                  </td>
                  <td className="small">{r.reporterHandle === null ? '—' : `@${r.reporterHandle}`}</td>
                  <td className="small">{when(r.createdAt)}</td>
                  <td>
                    {r.target.userId !== null && r.target.handle !== null && (
                      <>
                        <button className="button small" onClick={() => void hide(r.target.userId!, r.target.hidden !== true, reports.reload)}>
                          {r.target.hidden === true ? 'Show' : 'Hide'}
                        </button>{' '}
                        <button className="button small" onClick={() => rename(r.target.userId!, r.target.handle!, reports.reload)}>Rename</button>{' '}
                      </>
                    )}
                    {r.target.clubId !== null && (
                      sure === r.target.clubId ? (
                        <button className="button small danger" onClick={() => void act('DELETE', `/admin/community/clubs/${r.target.clubId}`, undefined, reports.reload)}>Delete club: sure?</button>
                      ) : (
                        <button className="button small" onClick={() => setSure(r.target.clubId)}>Delete club</button>
                      )
                    )}{' '}
                    {r.status === 'open' && (
                      <button className="button small" onClick={() => void act('POST', `/admin/community/reports/${r.id}/close`, undefined, reports.reload)}>Close</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {reports.data?.items.length === 0 && <p className="muted">No {status} reports.</p>}
        </>
      )}

      {tab === 'members' && (
        <>
          <SearchBox value={q} onChange={setQ} onSubmit={() => setQuery(q.trim().replace(/^@/, ''))} placeholder="Find a handle" />
          <Status error={members.error} loading={members.loading} />
          {members.data !== null && <p className="muted small">{members.data.total} members</p>}
          <table>
            <thead><tr><th>Handle</th><th>Country</th><th>World board</th><th>Joined</th><th /></tr></thead>
            <tbody>
              {(members.data?.items ?? []).map((m) => (
                <tr key={m.userId}>
                  <td>
                    <strong>@{m.handle}</strong>
                    {m.hidden && <> <Badge tone="muted">hidden</Badge></>}
                  </td>
                  <td className="small">{country(m.country)}</td>
                  <td>{m.onWorld ? <Badge tone="ok">on</Badge> : <Badge tone="muted">off</Badge>}</td>
                  <td className="small">{when(m.joinedAt)}</td>
                  <td>
                    <button className="button small" onClick={() => void hide(m.userId, !m.hidden, members.reload)}>{m.hidden ? 'Show' : 'Hide'}</button>{' '}
                    <button className="button small" onClick={() => rename(m.userId, m.handle, members.reload)}>Rename</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {tab === 'clubs' && (
        <>
          <Status error={clubs.error} loading={clubs.loading} />
          <table>
            <thead><tr><th>Club</th><th>Made by</th><th>Members</th><th>Made</th><th /></tr></thead>
            <tbody>
              {(clubs.data?.items ?? []).map((c) => (
                <tr key={c.id}>
                  <td><strong>{c.name}</strong></td>
                  <td className="small">{c.ownerHandle === null ? '—' : `@${c.ownerHandle}`}</td>
                  <td>{c.members}</td>
                  <td className="small">{when(c.createdAt)}</td>
                  <td>
                    {sure === c.id ? (
                      <button className="button small danger" onClick={() => void act('DELETE', `/admin/community/clubs/${c.id}`, undefined, clubs.reload)}>Delete: sure?</button>
                    ) : (
                      <button className="button small" onClick={() => setSure(c.id)}>Delete</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {clubs.data?.items.length === 0 && <p className="muted">No clubs yet.</p>}
        </>
      )}
    </>
  );
}
