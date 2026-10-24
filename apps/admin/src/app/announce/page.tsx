'use client';

import type { AdminUpdatePushResult, AdminUpdatePushStatus } from '@fitos/contracts';
import { useState } from 'react';

import { Badge, Header, Status, useGet, when } from '@/components/ui';
import { api, errorText } from '@/lib/api';

/**
 * Beta 3.5: after a release, tell every phone with notifications on that the
 * new beta is out. The version is the website's own; once per build.
 */
export default function Announce() {
  const { data, error, loading, reload } = useGet<AdminUpdatePushStatus>('/admin/push/update');
  const [result, setResult] = useState<AdminUpdatePushResult | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const send = async () => {
    if (data?.latest == null) return;
    if (!window.confirm(`Send "FITOS ${data.latest.label} is out" to ${data.devices} phones? This can be done once for this build.`)) return;
    setBusy(true);
    setActionError(null);
    try {
      setResult(await api<AdminUpdatePushResult>('POST', '/admin/push/update'));
      reload();
    } catch (e) {
      setActionError(errorText(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <Header eyebrow="Releases" title="Announce update">
        After a new APK is on the website, send one notification to every phone with notifications on: &ldquo;FITOS beta N is out. Tap to
        update.&rdquo; Tapping it opens FITOS, which shows the update dialog. Once per build; audited. Phones whose app was uninstalled are
        cleaned up.
      </Header>
      <Status error={error} loading={loading && data === null} />
      {actionError !== null && <p className="error">{actionError}</p>}
      {data !== null && (
        <div className="card">
          {data.latest === null ? (
            <p className="muted">Could not read the website&apos;s latest version (tryfitos.me/version.json).</p>
          ) : (
            <>
              <p>
                <strong>On the website:</strong> FITOS {data.latest.label} (build {data.latest.build}){' '}
                {data.sentAt === null ? <Badge tone="warn">not announced</Badge> : <Badge tone="ok">announced {when(data.sentAt)}</Badge>}
              </p>
              <p className="muted">{data.devices} phones can be notified.</p>
              <button className="button primary" disabled={busy || data.sentAt !== null || data.devices === 0} onClick={() => void send()}>
                {data.sentAt === null ? `Notify ${data.devices} phones` : 'Already announced'}
              </button>
            </>
          )}
        </div>
      )}
      {result !== null && (
        <p className="card">
          Sent to {result.sent} of {result.devices} phones for {result.label}
          {result.removed > 0 ? `; ${result.removed} uninstalled ones removed` : ''}.
        </p>
      )}
    </>
  );
}
