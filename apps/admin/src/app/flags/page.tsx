'use client';

import type { FeatureFlag } from '@fitos/contracts';
import { useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/** §20: feature flags, served to every signed-in user by GET /meta/config. */
export default function Flags() {
  const { data, error, loading, reload } = useGet<{ items: FeatureFlag[] }>('/admin/flags');
  const [key, setKey] = useState('');
  const [description, setDescription] = useState('');
  const [actionError, setActionError] = useState<string | null>(null);

  const put = async (k: string, enabled: boolean, desc?: string) => {
    setActionError(null);
    try {
      await api('PUT', `/admin/flags/${encodeURIComponent(k)}`, { enabled, ...(desc !== undefined ? { description: desc } : {}) });
      reload();
    } catch (e) {
      setActionError(errorText(e));
    }
  };

  return (
    <>
      <Header eyebrow="Configuration" title="Feature flags">
        Switches the app can read from <code>GET /v1/meta/config</code>. A new flag starts off.
      </Header>
      <Status error={error} loading={loading && data === null} />
      {actionError !== null && <p className="error">{actionError}</p>}
      {data !== null && data.items.length === 0 && <p className="muted">No flags yet.</p>}
      {data !== null && data.items.length > 0 && (
        <table>
          <thead><tr><th>Flag</th><th>Description</th><th>State</th><th>Changed</th><th /></tr></thead>
          <tbody>
            {data.items.map((f) => (
              <tr key={f.key}>
                <td><code>{f.key}</code></td>
                <td>{f.description || <span className="muted">—</span>}</td>
                <td>{f.enabled ? <Badge tone="ok">on</Badge> : <Badge tone="muted">off</Badge>}</td>
                <td>{when(f.updatedAt)}</td>
                <td><button className="button small" onClick={() => void put(f.key, !f.enabled)}>{f.enabled ? 'Turn off' : 'Turn on'}</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <h2>Add a flag</h2>
      <form className="row wrap" onSubmit={(e) => { e.preventDefault(); void put(key.trim(), false, description.trim()).then(() => { setKey(''); setDescription(''); }); }}>
        <input placeholder="key, e.g. new-home" value={key} onChange={(e) => setKey(e.target.value)} pattern="[a-z][a-z0-9-]{1,48}" required />
        <input className="grow" placeholder="What it switches" value={description} onChange={(e) => setDescription(e.target.value)} />
        <button className="button primary" type="submit">Add (off)</button>
      </form>
    </>
  );
}
