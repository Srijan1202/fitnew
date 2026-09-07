# @fitos/contracts — not yet implemented

Reserved by spec §29. This package will hold the Zod schemas and the generated
OpenAPI document that keep `apps/api`, `apps/admin` and the generated Dart client
in lockstep.

It is intentionally empty at Phase 0 and is **not** a pnpm workspace member yet —
an empty package would show up in `pnpm -r test` as a phantom. It joins the
workspace in Phase 1, when `/auth/session` gives it its first real schema.
