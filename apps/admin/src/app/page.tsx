/**
 * Phase 0 placeholder. Real screens (mess correction queue, food corrections,
 * exercise CRUD, provider health) land in Phase 16.
 *
 * Nothing here is wired to data: §"Never fake functionality" forbids buttons
 * that do nothing, so this page states what it is rather than mocking a
 * dashboard.
 */
export default function AdminHome() {
  return (
    <main>
      <p className="eyebrow">FitOS</p>
      <h1>Admin</h1>
      <p className="lede">
        Scaffold only. This panel is built in Phase 16 — mess correction queue, food
        database corrections, exercise CRUD, provider health and feature flags.
      </p>
      <hr />
      <dl>
        <dt>Access</dt>
        <dd>Firebase custom claim <code>role: admin</code>, enforced server-side on every request.</dd>
        <dt>Audit</dt>
        <dd>Every admin action writes to <code>audit_logs</code>.</dd>
        <dt>Never exposed here</dt>
        <dd>Body photos and raw food logs.</dd>
      </dl>
    </main>
  );
}
