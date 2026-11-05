-- Beta 5.6.1 (owner, 2026-11-05: 19 of the 62 redrawn demos rejected again
-- with new notes): the 19 redrawn a second time wait for approval again.
-- Only a rejection is cleared; their notes stay in the audit log
-- (demo.unapprove).
DELETE FROM "exercise_demo_approvals" WHERE NOT "approved" AND "demo_slug" IN (
  'arnold-press', 'band-lat-pulldown', 'cable-woodchopper', 'concentration-curl',
  'curtsy-lunge', 'dumbbell-pullover', 'machine-crunch', 'machine-lateral-raise',
  'machine-preacher-curl', 'machine-row', 'machine-shoulder-press', 'machine-triceps-extension',
  'pec-deck', 'reverse-pec-deck', 'russian-twist', 'side-plank',
  'suitcase-carry', 'sumo-deadlift', 'upright-row'
);
