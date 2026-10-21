'use client';

import type { AdminExercise } from '@fitos/contracts';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';

import { ExerciseForm } from '@/components/ExerciseForm';
import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

export default function ExerciseEditor() {
  const { id } = useParams<{ id: string }>();
  const { data, error, loading, reload } = useGet<AdminExercise>(`/admin/exercises/${id}`);
  const [saved, setSaved] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const retire = async (yes: boolean) => {
    setActionError(null);
    try {
      await api('POST', `/admin/exercises/${id}/${yes ? 'retire' : 'restore'}`);
      reload();
    } catch (e) {
      setActionError(errorText(e));
    }
  };

  return (
    <>
      <p><Link href="/exercises">← Exercises</Link></p>
      <Status error={error} loading={loading && data === null} />
      {data !== null && (
        <>
          <Header eyebrow={data.slug} title={data.name}>
            {data.retiredAt !== null ? <Badge tone="muted">retired {when(data.retiredAt)}</Badge> : data.adminEditedAt !== null ? `Edited here ${when(data.adminEditedAt)}.` : 'From the seed.'}
          </Header>
          <div className="row">
            {data.retiredAt === null ? (
              <button className="button" onClick={() => void retire(true)}>Retire</button>
            ) : (
              <button className="button primary" onClick={() => void retire(false)}>Restore</button>
            )}
            {saved && <span className="ok">Saved.</span>}
          </div>
          {actionError !== null && <p className="error">{actionError}</p>}
          <hr />
          <ExerciseForm
            key={data.adminEditedAt ?? 'seed'}
            initial={data}
            id={data.id}
            onSaved={() => {
              setSaved(true);
              reload();
            }}
          />
        </>
      )}
    </>
  );
}
