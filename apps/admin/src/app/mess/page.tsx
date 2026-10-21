'use client';

import type { CorrectionGroup, CorrectionReport } from '@fitos/contracts';
import { useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

type Status_ = 'pending' | 'accepted' | 'rejected';
const FIELDS = ['kcal', 'protein', 'carb', 'fat'] as const;
const UNIT: Record<string, string> = { kcal: 'kcal', protein: 'g protein', carb: 'g carbs', fat: 'g fat' };

function range(low: number, high: number): string {
  return low === high ? `${low}` : `${low}–${high}`;
}

function ReportRow({ report, onDone }: { report: CorrectionReport; onDone: () => void }) {
  const numeric = report.field !== 'diet' && report.field !== 'other';
  const [low, setLow] = useState(String(report.valueLow ?? ''));
  const [high, setHigh] = useState(String(report.valueHigh ?? ''));
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const review = async (decision: 'accept' | 'reject') => {
    setBusy(true);
    setError(null);
    try {
      await api('POST', `/admin/mess/corrections/${report.id}/review`, {
        decision,
        ...(decision === 'accept' && numeric ? { valueLow: Number(low), valueHigh: Number(high) } : {}),
        ...(note.trim() !== '' ? { note: note.trim() } : {}),
      });
      onDone();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="report">
      <div className="row between">
        <div>
          <b>{report.field}</b>{' '}
          {numeric && <span>→ {range(report.valueLow ?? 0, report.valueHigh ?? 0)} {UNIT[report.field]}</span>}
          {report.field === 'diet' && <span>→ {report.dietValue}</span>}
          <span className="muted small"> · {when(report.createdAt)}</span>
        </div>
        <Badge tone={report.status === 'pending' ? 'warn' : report.status === 'accepted' ? 'ok' : 'muted'}>{report.status}</Badge>
      </div>
      {report.note !== null && <p className="quote">“{report.note}”</p>}
      {report.status === 'pending' && (
        <div className="row wrap">
          {numeric && (
            <>
              <label className="inline">Low <input type="number" value={low} onChange={(e) => setLow(e.target.value)} step="0.1" min="0" /></label>
              <label className="inline">High <input type="number" value={high} onChange={(e) => setHigh(e.target.value)} step="0.1" min="0" /></label>
            </>
          )}
          <input className="grow" placeholder="Review note (optional)" value={note} onChange={(e) => setNote(e.target.value)} />
          <button className="button primary" disabled={busy} onClick={() => void review('accept')}>
            {report.field === 'other' ? 'Mark resolved' : 'Accept'}
          </button>
          <button className="button" disabled={busy} onClick={() => void review('reject')}>Reject</button>
        </div>
      )}
      {error !== null && <p className="error">{error}</p>}
    </div>
  );
}

function DishTools({ group, onDone }: { group: CorrectionGroup; onDone: () => void }) {
  const [field, setField] = useState<(typeof FIELDS)[number]>('kcal');
  const [low, setLow] = useState('');
  const [high, setHigh] = useState('');
  const [diet, setDiet] = useState<string>(group.dietOverride ?? '');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const run = async (f: () => Promise<unknown>) => {
    setError(null);
    try {
      await f();
      onDone();
    } catch (e) {
      setError(errorText(e));
    }
  };
  return (
    <details className="tools">
      <summary>Edit this dish directly</summary>
      <div className="stack">
        <input placeholder="Reason (kept in the audit log)" value={reason} onChange={(e) => setReason(e.target.value)} />
        {group.estimate !== null && (
          <div className="row wrap">
            <select value={field} onChange={(e) => setField(e.target.value as (typeof FIELDS)[number])}>
              {FIELDS.map((f) => <option key={f}>{f}</option>)}
            </select>
            <input type="number" placeholder="low" value={low} onChange={(e) => setLow(e.target.value)} />
            <input type="number" placeholder="high" value={high} onChange={(e) => setHigh(e.target.value)} />
            <button
              className="button"
              onClick={() => void run(() => api('PUT', `/admin/mess/dishes/${group.dishSlug}/estimate`, { field, low: Number(low), high: Number(high), reason }))}
            >
              Save estimate
            </button>
          </div>
        )}
        <div className="row wrap">
          <select value={diet} onChange={(e) => setDiet(e.target.value)}>
            <option value="">As parsed (no override)</option>
            <option value="veg">veg</option>
            <option value="egg">egg</option>
            <option value="nonveg">nonveg</option>
          </select>
          <button className="button" onClick={() => void run(() => api('PUT', `/admin/mess/dishes/${group.dishSlug}/diet`, { diet: diet === '' ? null : diet, reason }))}>
            Save diet
          </button>
        </div>
        {error !== null && <p className="error">{error}</p>}
      </div>
    </details>
  );
}

/** §20: the mess correction queue. A correction accepted here applies by slug to every future menu. */
export default function MessCorrections() {
  const [status, setStatus] = useState<Status_>('pending');
  const { data, error, loading, reload } = useGet<{ items: CorrectionGroup[] }>(`/admin/mess/corrections?status=${status}`);
  return (
    <>
      <Header eyebrow="Mess" title="Correction queue">
        Students report a dish&apos;s numbers or diet. Accepting applies to that dish everywhere it appears, on every future
        menu; meals already logged keep the numbers they were logged with.
      </Header>
      <div className="row">
        {(['pending', 'accepted', 'rejected'] as const).map((s) => (
          <button key={s} className={`button small ${s === status ? 'primary' : ''}`} onClick={() => setStatus(s)}>{s}</button>
        ))}
      </div>
      <Status error={error} loading={loading && data === null} />
      {data !== null && data.items.length === 0 && <p className="muted">Nothing {status}.</p>}
      {data?.items.map((g) => (
        <article key={g.dishSlug} className="card">
          <div className="row between">
            <h3>{g.estimate?.name ?? g.dishSlug}</h3>
            {g.dietOverride !== null && <Badge tone="warn">diet override: {g.dietOverride}</Badge>}
          </div>
          <p className="muted small">{g.dishSlug}</p>
          {g.estimate === null ? (
            <p className="muted">No estimate stored for this dish.</p>
          ) : (
            <p>
              {g.estimate.servingLabel}: <b>{range(g.estimate.kcalLow, g.estimate.kcalHigh)} kcal</b> ·{' '}
              {range(g.estimate.proteinLow, g.estimate.proteinHigh)} g protein · {range(g.estimate.carbLow, g.estimate.carbHigh)} g carbs ·{' '}
              {range(g.estimate.fatLow, g.estimate.fatHigh)} g fat <span className="muted small">({g.estimate.confidence})</span>
            </p>
          )}
          {g.reports.map((r) => <ReportRow key={r.id} report={r} onDone={reload} />)}
          <DishTools group={g} onDone={reload} />
        </article>
      ))}
    </>
  );
}
