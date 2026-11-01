'use client';

import type { AdminFoodSummary } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { FoodEditor } from '@/components/FoodEditor';
import { Badge, Drawer, Empty, Header, SearchBox, Status, useGet, useQueryParam, useSort, when } from '@/components/ui';

/** §20: food database corrections — FITOS foods only, never anyone's own. Beta 5.3: search as you type, sort, edit in a side panel. */
export default function Foods() {
  const start = useQueryParam('q');
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState<AdminFoodSummary | null>(null);
  useEffect(() => {
    setQ(start);
    setQuery(start);
  }, [start]);
  // Searches a moment after typing stops.
  useEffect(() => {
    const t = setTimeout(() => setQuery(q.trim()), 300);
    return () => clearTimeout(t);
  }, [q]);
  const { data, error, loading, reload } = useGet<{ items: AdminFoodSummary[] }>(`/admin/foods?q=${encodeURIComponent(query)}`);
  const { rows, th } = useSort(data?.items ?? [], {
    name: (f) => f.name,
    source: (f) => f.source,
    verified: (f) => (f.isVerified ? 0 : 1),
    edited: (f) => f.adminEditedAt,
  });

  return (
    <>
      <Header eyebrow="Library" title="Foods">
        The FITOS food database. A food you correct here keeps your correction: the seed leaves it alone from then on.
      </Header>
      <div className="toolbar">
        <SearchBox value={q} onChange={setQ} onSubmit={() => setQuery(q.trim())} placeholder="Search foods by name" autoFocus />
      </div>
      <Status error={error} loading={loading && data === null} />
      {data !== null && data.items.length === 0 && (
        <Empty icon="search" title="No food matches">
          Try another spelling, or fewer words.
        </Empty>
      )}
      {data !== null && data.items.length > 0 && (
        <table>
          <thead>
            <tr>
              {th('name', 'Name')}
              {th('source', 'Source')}
              {th('verified', 'Verified')}
              {th('edited', 'Edited here')}
            </tr>
          </thead>
          <tbody>
            {rows.map((f) => (
              <tr key={f.id} className="clickable" onClick={() => setOpen(f)}>
                <td>
                  <a
                    href={`/foods/edit?id=${f.id}`}
                    onClick={(e) => {
                      e.preventDefault();
                      setOpen(f);
                    }}
                  >
                    {f.name}
                  </a>
                  <div className="muted small">{f.slug}</div>
                </td>
                <td>{f.source}</td>
                <td>{f.isVerified ? <Badge tone="ok">verified</Badge> : <Badge tone="muted">estimate</Badge>}</td>
                <td>{when(f.adminEditedAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {data !== null && data.items.length === 100 && <p className="muted small">Showing the first 100; narrow the search.</p>}
      {open !== null && (
        <Drawer
          title={open.name}
          onClose={() => {
            setOpen(null);
            reload();
          }}
        >
          <FoodEditor id={open.id} inPanel />
        </Drawer>
      )}
    </>
  );
}
