-- Down for 0046_redrawn_demos_wait_again (beta 5.6.1). Hand-written: drizzle-kit is forward-only (§25).
-- Nothing to undo in the schema; the cleared rejections are not restored
-- (each one, with its note, is in the audit log as demo.unapprove).
SELECT 1;
