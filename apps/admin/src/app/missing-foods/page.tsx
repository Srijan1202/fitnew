'use client';

import { FOOD_REQUEST_STATUSES, type AdminFoodRequest, type AdminFoodRequestList, type FoodRequestStatus } from '@fitos/contracts';
import { useEffect, useState } from 'react';

import { Badge, Header, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

const LABEL: Record<FoodRequestStatus, string> = {
  open: 'open',
  added: 'added',
  'already-there': 'already there',
  ignored: 'ignored',
};
const TONE: Record<FoodRequestStatus, 'warn' | 'ok' | 'muted'> = { open: 'warn', added: 'ok', 'already-there': 'muted', ignored: 'muted' };

/** Beta 3.2 (ADR-032): what people searched for and did not find, most-wanted first. */
export default function MissingFoods() {
  const [filter, setFilter] = useState<FoodRequestStatus | 'all'>('open');
  const [items, setItems] = useState<AdminFoodRequest[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await api<AdminFoodRequestList>('GET', `/admin/foods/requests?status=${filter}`);
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

  const mark = async (id: string, status: FoodRequestStatus) => {
    setError(null);
    try {
      const updated = await api<AdminFoodRequest>('PATCH', `/admin/foods/requests/${id}`, { status });
      setItems((xs) => (filter === 'all' || filter === status ? xs.map((x) => (x.id === id ? updated : x)) : xs.filter((x) => x.id !== id)));
    } catch (e) {
      setError(errorText(e));
    }
  };

  return (
    <>
      <Header eyebrow="Missing foods" title="Searched, not found">
        What people typed in the food search and found nothing for, most-wanted first. Counted anonymously: each person once a day
        (searches) and once overall (people); &ldquo;asked&rdquo; is people who tapped Ask us to add it. Add the food (or an alias on an
        existing one under Foods), then mark it. Marking is audited.
      </Header>
      <p>
        {(['open', 'added', 'already-there', 'ignored', 'all'] as const).map((f) => (
          <button key={f} className={`button${filter === f ? ' active' : ''}`} disabled={loading} onClick={() => setFilter(f)}>
            {f === 'all' ? 'all' : LABEL[f]}
          </button>
        ))}
      </p>
      {error !== null && <p className="error">{error}</p>}
      <table>
        <thead><tr><th>Searched for</th><th>People</th><th>Asked</th><th>Searches</th><th>Last seen</th><th>Status</th><th /></tr></thead>
        <tbody>
          {items.map((r) => (
            <tr key={r.id}>
              <td><strong>{r.query}</strong><div className="muted small">first {when(r.firstSeenAt)}</div></td>
              <td>{r.people}</td>
              <td>{r.asked}</td>
              <td>{r.searches}</td>
              <td className="small">{when(r.lastSeenAt)}</td>
              <td><Badge tone={TONE[r.status]}>{LABEL[r.status]}</Badge></td>
              <td>
                {FOOD_REQUEST_STATUSES.filter((s) => s !== r.status).map((s) => (
                  <button key={s} className="button small" onClick={() => void mark(r.id, s)}>{LABEL[s]}</button>
                ))}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {items.length === 0 && !loading && <p className="muted">Nothing here.</p>}
    </>
  );
}
