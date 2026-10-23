'use client';

import type { AdminCommunityFood, AdminCommunityFoodList } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Badge, Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

type Filter = 'reported' | 'community' | 'hidden' | 'all';

const amount = (v: number): string => (Number.isInteger(v) ? String(v) : v.toFixed(1));

/** Beta 3.2 (ADR-032): foods people shared, most-reported first. Never who added them. */
export default function CommunityFoods() {
  const [filter, setFilter] = useState<Filter>('reported');
  const [items, setItems] = useState<AdminCommunityFood[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await api<AdminCommunityFoodList>('GET', `/admin/foods/community?filter=${filter}`);
      setItems(page.items);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  const set = async (id: string, visibility: 'community' | 'hidden') => {
    setError(null);
    try {
      const updated = await api<AdminCommunityFood>('PATCH', `/admin/foods/community/${id}`, { visibility });
      setItems((xs) => xs.map((x) => (x.id === id ? updated : x)));
    } catch (e) {
      setError(errorText(e));
    }
  };

  return (
    <>
      <Header eyebrow="Community foods" title="Shared by people">
        Foods people added from a label and shared with everyone, shown in the app as Community · unverified. Most-reported first. Who
        added them is never shown here. Hide sends a food back to its owner only; Show shares it again. Both are audited.
      </Header>
      <p>
        {(['reported', 'community', 'hidden', 'all'] as const).map((f) => (
          <button key={f} className={`button${filter === f ? ' active' : ''}`} disabled={loading} onClick={() => setFilter(f)}>
            {f === 'community' ? 'shown' : f}
          </button>
        ))}
      </p>
      {error !== null && <p className="error">{error}</p>}
      <table>
        <thead><tr><th>Food</th><th>Label</th><th>Reports</th><th>Shared</th><th>Status</th><th /></tr></thead>
        <tbody>
          {items.map((f) => (
            <tr key={f.id}>
              <td><strong>{f.name}</strong>{f.brand !== null && <div className="muted small">{f.brand}</div>}</td>
              <td className="small">
                {f.basis === 'per_100g' ? 'per 100 g' : f.servingLabel ?? 'per serving'}: {amount(f.kcal)} kcal · P {amount(f.proteinG)} · C {amount(f.carbG)} · F {amount(f.fatG)}
              </td>
              <td>
                {f.reports}
                {f.notes.map((n, i) => (
                  <div key={i} className="muted small">&ldquo;{n}&rdquo;</div>
                ))}
              </td>
              <td className="small">{when(f.createdAt)}</td>
              <td><Badge tone={f.visibility === 'hidden' ? 'muted' : f.reports > 0 ? 'warn' : 'ok'}>{f.visibility === 'hidden' ? 'hidden' : 'shown'}</Badge></td>
              <td>
                {f.visibility === 'hidden' ? (
                  <button className="button small" onClick={() => void set(f.id, 'community')}>Show</button>
                ) : (
                  <button className="button small" onClick={() => void set(f.id, 'hidden')}>Hide</button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {items.length === 0 && !loading && <p className="muted">Nothing here.</p>}
    </>
  );
}
