'use client';

import type { AdminFood } from '@fitos/contracts';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';

import { Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

type Row = AdminFood['nutrition'][number];
const NUMS = ['kcalLow', 'kcalHigh', 'proteinLow', 'proteinHigh', 'carbLow', 'carbHigh', 'fatLow', 'fatHigh', 'fibreLow', 'fibreHigh'] as const;

/** Correct one FITOS food: name, aliases, verified, its nutrition rows. Logged meals keep their numbers. */
export default function FoodEditor() {
  const { id } = useParams<{ id: string }>();
  const { data, error, loading } = useGet<AdminFood>(`/admin/foods/${id}`);
  const [name, setName] = useState('');
  const [aliases, setAliases] = useState('');
  const [verified, setVerified] = useState(false);
  const [rows, setRows] = useState<Row[]>([]);
  const [reason, setReason] = useState('');
  const [saved, setSaved] = useState<AdminFood | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    const f = saved ?? data;
    if (f === null) return;
    setName(f.name);
    setAliases(f.aliases.join(', '));
    setVerified(f.isVerified);
    setRows(f.nutrition);
  }, [data, saved]);

  const setNum = (i: number, k: (typeof NUMS)[number], v: string) =>
    setRows((rs) => rs.map((r, j) => (j === i ? { ...r, [k]: v === '' ? null : Number(v) } : r)));

  const save = async () => {
    setSaveError(null);
    try {
      const out = await api<AdminFood>('PUT', `/admin/foods/${id}`, {
        name: name.trim(),
        aliases: aliases.split(',').map((a) => a.trim()).filter((a) => a !== ''),
        isVerified: verified,
        nutrition: rows,
        reason,
      });
      setSaved(out);
    } catch (e) {
      setSaveError(errorText(e));
    }
  };

  const f = saved ?? data;
  return (
    <>
      <p><Link href="/foods">← Foods</Link></p>
      <Status error={error} loading={loading && data === null} />
      {f !== null && (
        <>
          <Header eyebrow={`${f.source} · ${f.slug}`} title={f.name}>
            {f.adminEditedAt === null ? 'From the seed.' : `Corrected here ${when(f.adminEditedAt)} — the seed leaves it alone.`}
            {f.sourceRef !== null && <div className="muted small">{f.sourceRef}</div>}
          </Header>
          <div className="stack">
            <label>Name <input value={name} onChange={(e) => setName(e.target.value)} /></label>
            <label>Aliases (comma-separated) <input value={aliases} onChange={(e) => setAliases(e.target.value)} /></label>
            <label className="inline">
              <input type="checkbox" checked={verified} onChange={(e) => setVerified(e.target.checked)} disabled={f.source === 'estimated'} />{' '}
              Verified {f.source === 'estimated' && <span className="muted small">(an estimate is never verified)</span>}
            </label>
          </div>
          <h2>Nutrition rows</h2>
          <div className="scroll-x">
            <table className="dense">
              <thead>
                <tr><th>Basis</th><th>Serving</th><th>g</th>{NUMS.map((k) => <th key={k}>{k}</th>)}<th>Confidence</th></tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={i}>
                    <td>{r.basis}</td>
                    <td><input value={r.servingLabel} onChange={(e) => setRows((rs) => rs.map((x, j) => (j === i ? { ...x, servingLabel: e.target.value } : x)))} /></td>
                    <td><input type="number" value={r.servingGrams ?? ''} onChange={(e) => setRows((rs) => rs.map((x, j) => (j === i ? { ...x, servingGrams: e.target.value === '' ? null : Number(e.target.value) } : x)))} /></td>
                    {NUMS.map((k) => (
                      <td key={k}><input type="number" step="0.1" value={r[k] ?? ''} onChange={(e) => setNum(i, k, e.target.value)} /></td>
                    ))}
                    <td>
                      <select value={r.confidence} onChange={(e) => setRows((rs) => rs.map((x, j) => (j === i ? { ...x, confidence: e.target.value as Row['confidence'] } : x)))}>
                        <option>high</option><option>medium</option><option>low</option>
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="stack">
            <label>Reason (kept in the audit log) <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. weighed at the mess" /></label>
            <div className="row">
              <button className="button primary" disabled={reason.trim().length < 3} onClick={() => void save()}>Save correction</button>
              {saved !== null && <span className="ok">Saved.</span>}
            </div>
            {saveError !== null && <p className="error">{saveError}</p>}
          </div>
        </>
      )}
    </>
  );
}
