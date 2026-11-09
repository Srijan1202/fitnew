'use client';

import { ALTERNATIVE_REASONS, MAX_ALTERNATIVES, type AdminAlternative, type AdminExercise, type AdminExerciseSummary, type AlternativeReason } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Badge, SearchBox, useGet } from '@/components/ui';
import { api, errorText } from '@/lib/api';

const REASON_HELP: Record<AlternativeReason, string> = {
  equipment: 'when the equipment is missing (kept both ways)',
  injury: 'gentler, for a limitation (this way only)',
  preference: 'a close variation (kept both ways)',
};

type Draft = { id: string; slug: string; name: string; reason: AlternativeReason; retiredAt: string | null };

/**
 * Beta 6.1 (E19): the swaps the app offers for this exercise. The server
 * holds §12.6's rules (same movement, a shared primary muscle) and adds or
 * removes the reverse of an equipment or preference link on the other
 * exercise.
 */
export function ExerciseAlternatives({ exercise }: { exercise: AdminExercise }) {
  const path = `/admin/exercises/${encodeURIComponent(exercise.id)}/alternatives`;
  const { data, error, reload } = useGet<{ items: AdminAlternative[] }>(path);
  const [draft, setDraft] = useState<Draft[] | null>(null);
  const [q, setQ] = useState('');
  const [found, setFound] = useState<AdminExerciseSummary[]>([]);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    if (data !== null) setDraft(data.items.map((a) => ({ id: a.id, slug: a.slug, name: a.name, reason: a.reason, retiredAt: a.retiredAt })));
  }, [data]);

  const search = async () => {
    if (q.trim() === '') return setFound([]);
    try {
      const r = await api<{ items: AdminExerciseSummary[] }>('GET', `/admin/exercises?q=${encodeURIComponent(q.trim())}`);
      // Same movement only; the server checks the shared muscle.
      setFound(r.items.filter((x) => x.id !== exercise.id && x.movementPattern === exercise.movementPattern));
    } catch (e) {
      setMessage({ ok: false, text: errorText(e) });
    }
  };

  const save = async () => {
    if (draft === null) return;
    setMessage(null);
    try {
      await api('PUT', path, { items: draft.map((a) => ({ id: a.id, reason: a.reason })) });
      setMessage({ ok: true, text: 'Saved.' });
      reload();
    } catch (e) {
      setMessage({ ok: false, text: errorText(e) });
    }
  };

  if (error !== null) return <p className="error">{error}</p>;
  if (draft === null) return <p className="muted">Loading alternatives…</p>;
  const changed = data !== null && JSON.stringify(draft.map((a) => [a.id, a.reason])) !== JSON.stringify(data.items.map((a) => [a.id, a.reason]));

  return (
    <fieldset>
      <legend>Alternatives ({draft.length} of {MAX_ALTERNATIVES})</legend>
      <p className="muted small">
        What the app offers in place of this exercise. Each must be the same movement ({exercise.movementPattern}) and share a primary muscle. Saving makes every exercise it touches yours: the seed leaves them alone.
      </p>
      {draft.length === 0 && <p className="muted">None yet.</p>}
      {draft.map((a, i) => (
        <div key={`${a.id}:${i}`} className="row">
          <span className="grow">
            {a.name} <span className="muted small">{a.slug}</span> {a.retiredAt !== null && <Badge tone="muted">retired</Badge>}
          </span>
          <select
            value={a.reason}
            aria-label={`Reason for ${a.name}`}
            onChange={(e) => setDraft(draft.map((x, j) => (j === i ? { ...x, reason: e.target.value as AlternativeReason } : x)))}
          >
            {ALTERNATIVE_REASONS.map((r) => <option key={r} value={r}>{r}: {REASON_HELP[r]}</option>)}
          </select>
          <button className="button small" onClick={() => setDraft(draft.filter((_, j) => j !== i))}>Remove</button>
        </div>
      ))}
      {draft.length < MAX_ALTERNATIVES && (
        <>
          <SearchBox value={q} onChange={setQ} onSubmit={() => void search()} placeholder="Find an exercise to add" />
          {found.map((x) => (
            <div key={x.id} className="row">
              <span className="grow">{x.name} <span className="muted small">{x.slug}</span></span>
              <button
                className="button small"
                disabled={draft.some((a) => a.id === x.id && a.reason === 'equipment')}
                onClick={() => {
                  setDraft([...draft, { id: x.id, slug: x.slug, name: x.name, reason: 'equipment', retiredAt: x.retiredAt }]);
                  setFound(found.filter((f) => f.id !== x.id));
                }}
              >
                Add
              </button>
            </div>
          ))}
        </>
      )}
      <div className="row">
        <button className="button primary" disabled={!changed} onClick={() => void save()}>Save alternatives</button>
        {changed && <button className="button" onClick={() => setDraft(data!.items.map((a) => ({ id: a.id, slug: a.slug, name: a.name, reason: a.reason, retiredAt: a.retiredAt })))}>Undo changes</button>}
        {message !== null && <span className={message.ok ? 'ok' : 'error'}>{message.text}</span>}
      </div>
    </fieldset>
  );
}
