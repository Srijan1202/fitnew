'use client';

import type { AdminExerciseSummary } from '@fitos/contracts';
import Link from 'next/link';
import { useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';

/** §20: exercise CRUD. Retired exercises leave the library and new programmes; history keeps them. */
export default function Exercises() {
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [retired, setRetired] = useState(false);
  const { data, error, loading } = useGet<{ items: AdminExerciseSummary[] }>(`/admin/exercises?q=${encodeURIComponent(query)}&retired=${retired}`);
  return (
    <>
      <Header eyebrow="Library" title="Exercises">
        Edits and new exercises are kept through a re-seed. Retiring removes an exercise from the library and from new
        programmes; past sessions and existing programmes keep it.
      </Header>
      <div className="row wrap">
        <form className="row grow" onSubmit={(e) => { e.preventDefault(); setQuery(q.trim()); }}>
          <input className="grow" placeholder="Search by name" value={q} onChange={(e) => setQ(e.target.value)} />
          <button className="button" type="submit">Search</button>
        </form>
        <button className={`button small ${retired ? 'primary' : ''}`} onClick={() => setRetired((r) => !r)}>
          {retired ? 'Showing retired' : 'Show retired'}
        </button>
        <Link className="button primary" href="/exercises/new">New exercise</Link>
      </div>
      <Status error={error} loading={loading && data === null} />
      {data !== null && (
        <table>
          <thead><tr><th>Name</th><th>Movement</th><th>Equipment</th><th>Status</th></tr></thead>
          <tbody>
            {data.items.map((x) => (
              <tr key={x.id}>
                <td><Link href={`/exercises/${x.id}`}>{x.name}</Link><div className="muted small">{x.slug}</div></td>
                <td>{x.movementPattern}</td>
                <td>{x.equipment.join(', ')}</td>
                <td>
                  {x.retiredAt !== null ? <Badge tone="muted">retired {when(x.retiredAt)}</Badge> : x.adminEditedAt !== null ? <Badge tone="warn">edited here</Badge> : <Badge tone="ok">seed</Badge>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}
