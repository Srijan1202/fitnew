-- Down for 0047_demos_third_round_wait (beta 5.6.2). Hand-written: drizzle-kit is forward-only (§25).
-- Nothing to undo in the schema; the cleared rejections are not restored
-- (each one, with its note, is in the audit log as demo.unapprove).
SELECT 1;
