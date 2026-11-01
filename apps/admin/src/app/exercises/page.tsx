'use client';

import type { AdminExerciseSummary } from '@fitos/contracts';
import Link from 'next/link';
import { useEffect, useState } from 'react';

import { ExerciseEditor } from '@/components/ExerciseEditor';
import { Icon } from '@/components/icons';
import { Badge, Drawer, Empty, Header, SearchBox, Status, useGet, useQueryParam, useSort, when } from '@/components/ui';

/** §20: exercise CRUD. Retired exercises leave the library and new programmes; history keeps them. Beta 5.3: search as you type, sort, edit in a side panel. */
export default function Exercises() {
  const start = useQueryParam('q');
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [retired, setRetired] = useState(false);
  const [open, setOpen] = useState<AdminExerciseSummary | null>(null);
  useEffect(() => {
    setQ(start);
    setQuery(start);
  }, [start]);
  useEffect(() => {
    const t = setTimeout(() => setQuery(q.trim()), 300);
    return () => clearTimeout(t);
  }, [q]);
  const { data, error, loading, reload } = useGet<{ items: AdminExerciseSummary[] }>(`/admin/exercises?q=${encodeURIComponent(query)}&retired=${retired}`);
  const { rows, th } = useSort(data?.items ?? [], {
    name: (x) => x.name,
    movement: (x) => x.movementPattern,
    equipment: (x) => x.equipment.join(', '),
    status: (x) => (x.retiredAt !== null ? 2 : x.adminEditedAt !== null ? 1 : 0),
  });

  return (
    <>
      <Header
        eyebrow="Library"
        title="Exercises"
        actions={
          <Link className="button primary" href="/exercises/new">
            <Icon name="plus" size={16} /> New exercise
          </Link>
        }
      >
        Edits and new exercises are kept through a re-seed. Retiring removes an exercise from the library and from new programmes; past sessions and
        existing programmes keep it.
      </Header>
      <div className="toolbar">
        <SearchBox value={q} onChange={setQ} onSubmit={() => setQuery(q.trim())} placeholder="Search exercises by name" autoFocus />
        <div className="segmented" role="group" aria-label="Which exercises" style={{ margin: 0 }}>
          <button className={!retired ? 'active' : ''} onClick={() => setRetired(false)}>
            In the library
          </button>
          <button className={retired ? 'active' : ''} onClick={() => setRetired(true)}>
            With retired
          </button>
        </div>
      </div>
      <Status error={error} loading={loading && data === null} />
      {data !== null && data.items.length === 0 && (
        <Empty icon="search" title="No exercise matches">
          Try another name, or include retired ones.
        </Empty>
      )}
      {data !== null && data.items.length > 0 && (
        <table>
          <thead>
            <tr>
              {th('name', 'Name')}
              {th('movement', 'Movement')}
              {th('equipment', 'Equipment')}
              {th('status', 'Status')}
            </tr>
          </thead>
          <tbody>
            {rows.map((x) => (
              <tr key={x.id} className="clickable" onClick={() => setOpen(x)}>
                <td>
                  <a
                    href={`/exercises/edit?id=${x.id}`}
                    onClick={(e) => {
                      e.preventDefault();
                      setOpen(x);
                    }}
                  >
                    {x.name}
                  </a>
                  <div className="muted small">{x.slug}</div>
                </td>
                <td>{x.movementPattern}</td>
                <td>{x.equipment.join(', ')}</td>
                <td>
                  {x.retiredAt !== null ? (
                    <Badge tone="muted">retired {when(x.retiredAt)}</Badge>
                  ) : x.adminEditedAt !== null ? (
                    <Badge tone="warn">edited here</Badge>
                  ) : (
                    <Badge tone="ok">seed</Badge>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {open !== null && (
        <Drawer
          title={open.name}
          onClose={() => {
            setOpen(null);
            reload();
          }}
        >
          <ExerciseEditor id={open.id} inPanel />
        </Drawer>
      )}
    </>
  );
}
