'use client';

import type { AdminFoodSummary } from '@fitos/contracts';
import Link from 'next/link';
import { useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';

/** §20: food database corrections — FITOS foods only, never anyone's own. */
export default function Foods() {
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const { data, error, loading } = useGet<{ items: AdminFoodSummary[] }>(`/admin/foods?q=${encodeURIComponent(query)}`);
  return (
    <>
      <Header eyebrow="Library" title="Foods">
        The FITOS food database. A food you correct here keeps your correction: the seed leaves it alone from then on.
      </Header>
      <form className="row" onSubmit={(e) => { e.preventDefault(); setQuery(q.trim()); }}>
        <input className="grow" placeholder="Search by name" value={q} onChange={(e) => setQ(e.target.value)} />
        <button className="button primary" type="submit">Search</button>
      </form>
      <Status error={error} loading={loading && data === null} />
      {data !== null && (
        <table>
          <thead><tr><th>Name</th><th>Source</th><th>Verified</th><th>Edited here</th></tr></thead>
          <tbody>
            {data.items.map((f) => (
              <tr key={f.id}>
                <td><Link href={`/foods/${f.id}`}>{f.name}</Link><div className="muted small">{f.slug}</div></td>
                <td>{f.source}</td>
                <td>{f.isVerified ? <Badge tone="ok">verified</Badge> : <Badge tone="muted">estimate</Badge>}</td>
                <td>{when(f.adminEditedAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {data !== null && data.items.length === 100 && <p className="muted small">Showing the first 100; narrow the search.</p>}
    </>
  );
}
