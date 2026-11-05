-- Beta 5.6.2 (owner, 2026-11-05: 7 of the 19 demos redrawn in 5.6.1
-- rejected with new notes): the 7 redrawn a third time wait for approval
-- again. Only a rejection is cleared; their notes stay in the audit log
-- (demo.unapprove).
DELETE FROM "exercise_demo_approvals" WHERE NOT "approved" AND "demo_slug" IN (
  'band-lat-pulldown', 'cable-woodchopper', 'curtsy-lunge', 'dumbbell-pullover',
  'machine-crunch', 'machine-row', 'russian-twist'
);
