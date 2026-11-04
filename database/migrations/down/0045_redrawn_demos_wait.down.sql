-- Down for 0045_redrawn_demos_wait (beta 5.6). Hand-written: drizzle-kit is forward-only (§25).
-- Nothing to undo in the schema; the cleared rejections are not restored
-- (each one, with its note, is in the audit log as demo.unapprove).
SELECT 1;
