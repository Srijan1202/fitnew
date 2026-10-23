'use client';

import type { FeatureFlag } from '@fitos/contracts';
import { useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/**
 * §20 and beta 3.3 (ADR-033): the app's feature switches, then any other
 * flag. A switch is on until turned off; the app hides what is off within a
 * few minutes and the server refuses it at once.
 */
export default function Flags() {
  const { data, error, loading, reload } = useGet<{ items: FeatureFlag[] }>('/admin/flags');
  const [key, setKey] = useState('');
  const [description, setDescription] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const put = async (k: string, enabled: boolean, desc?: string) => {
    setActionError(null);
    setBusy(k);
    try {
      await api('PUT', `/admin/flags/${encodeURIComponent(k)}`, { enabled, ...(desc !== undefined ? { description: desc } : {}) });
      reload();
    } catch (e) {
      setActionError(errorText(e));
    } finally {
      setBusy(null);
    }
  };

  const switches = data?.items.filter((f) => f.name !== null) ?? [];
  const others = data?.items.filter((f) => f.name === null) ?? [];

  return (
    <>
      <Header eyebrow="Configuration" title="App features">
        Turn a feature off and the app hides it the next time it opens or comes back (within a few minutes); the server refuses it at once, so older
        versions of the app cannot use it either. Everything is on until you turn it off. Each change is audited.
      </Header>
      <Status error={error} loading={loading && data === null} />
      {actionError !== null && <p className="error">{actionError}</p>}

      {switches.map((f) => (
        <div key={f.key} className="switch-row">
          <div className="grow">
            <strong>{f.name}</strong> {f.enabled ? <Badge tone="ok">on</Badge> : <Badge tone="bad">off</Badge>}
            <div className="muted small">{f.description}</div>
            <div className="muted small">
              <code>{f.key}</code> · {f.updatedAt === null ? 'never changed' : `changed ${when(f.updatedAt)}`}
            </div>
          </div>
          <button
            className={`button${f.enabled ? '' : ' primary'}`}
            disabled={busy === f.key}
            onClick={() => void put(f.key, !f.enabled)}
          >
            {f.enabled ? 'Turn off' : 'Turn on'}
          </button>
        </div>
      ))}

      <h2>Other flags</h2>
      {data !== null && others.length === 0 && <p className="muted">None. These are for switches the app does not know yet.</p>}
      {others.length > 0 && (
        <table>
          <thead><tr><th>Flag</th><th>Description</th><th>State</th><th>Changed</th><th /></tr></thead>
          <tbody>
            {others.map((f) => (
              <tr key={f.key}>
                <td><code>{f.key}</code></td>
                <td>{f.description || <span className="muted">—</span>}</td>
                <td>{f.enabled ? <Badge tone="ok">on</Badge> : <Badge tone="muted">off</Badge>}</td>
                <td>{when(f.updatedAt)}</td>
                <td><button className="button small" disabled={busy === f.key} onClick={() => void put(f.key, !f.enabled)}>{f.enabled ? 'Turn off' : 'Turn on'}</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <form className="row wrap" onSubmit={(e) => { e.preventDefault(); void put(key.trim(), false, description.trim()).then(() => { setKey(''); setDescription(''); }); }}>
        <input placeholder="key, e.g. new-home" value={key} onChange={(e) => setKey(e.target.value)} pattern="[a-z][a-z0-9-]{1,48}" required />
        <input className="grow" placeholder="What it switches" value={description} onChange={(e) => setDescription(e.target.value)} />
        <button className="button" type="submit">Add (off)</button>
      </form>
    </>
  );
}
