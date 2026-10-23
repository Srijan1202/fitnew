'use client';

import { MESS_RATING_MIN_SHOWN, type AdminMessRating, type AdminMessRatings, type MessesResponse } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Header, Status, useGet } from '@/components/ui';
import { api, errorText } from '@/lib/api';

const pct = (r: AdminMessRating): number => Math.round((100 * r.up) / (r.up + r.down));

/** Beta 3.3 (ADR-014 amendment): how students rated each mess's dishes. Never who voted. */
export default function MessRatings() {
  const messes = useGet<MessesResponse>('/mess/providers/vit-vellore/messes');
  const [code, setCode] = useState<string | null>(null);
  const [data, setData] = useState<AdminMessRatings | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (code === null && messes.data !== null && messes.data.items.length > 0) setCode(messes.data.items[0]!.code);
  }, [code, messes.data]);

  useEffect(() => {
    if (code === null) return;
    setError(null);
    api<AdminMessRatings>('GET', `/admin/mess/ratings?mess=${encodeURIComponent(code)}`)
      .then(setData)
      .catch((e: unknown) => setError(errorText(e)));
  }, [code]);

  const enough = data?.items.filter((r) => r.up + r.down >= MESS_RATING_MIN_SHOWN) ?? [];
  const best = enough.slice(0, 10);
  const worst = [...enough].reverse().slice(0, 10);
  const few = data?.items.filter((r) => r.up + r.down < MESS_RATING_MIN_SHOWN) ?? [];

  const table = (rows: AdminMessRating[]) => (
    <table>
      <thead><tr><th>Dish</th><th>👍</th><th>👎</th><th>Liked</th></tr></thead>
      <tbody>
        {rows.map((r) => (
          <tr key={r.slug}>
            <td>{r.name}</td>
            <td>{r.up}</td>
            <td>{r.down}</td>
            <td>{pct(r)} %</td>
          </tr>
        ))}
      </tbody>
    </table>
  );

  return (
    <>
      <Header eyebrow="Mess" title="Mess ratings">
        How students rated the dishes their mess served, best liked first. The app shows a dish&apos;s share of 👍 once it has {MESS_RATING_MIN_SHOWN}{' '}
        votes. Who voted is never shown here or in the app.
      </Header>
      <Status error={messes.error} loading={messes.loading && messes.data === null} />
      <p>
        {messes.data?.items.map((m) => (
          <button key={m.code} className={`button small${code === m.code ? ' active' : ''}`} onClick={() => setCode(m.code)}>
            {m.hostelLabel} · {m.messLabel}
          </button>
        ))}
      </p>
      {error !== null && <p className="error">{error}</p>}
      {data !== null && data.items.length === 0 && <p className="muted">No ratings for this mess yet.</p>}
      {best.length > 0 && (
        <>
          <h2>Best liked</h2>
          {table(best)}
          <h2>Least liked</h2>
          {table(worst)}
        </>
      )}
      {few.length > 0 && (
        <>
          <h2>Fewer than {MESS_RATING_MIN_SHOWN} votes</h2>
          {table(few)}
        </>
      )}
    </>
  );
}
