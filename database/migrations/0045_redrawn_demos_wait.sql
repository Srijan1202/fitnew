-- Beta 5.6 (owner, 2026-11-04: "check and correct all then add them to waiting"):
-- the 62 demos redrawn after the owner's rejection notes wait for approval
-- again. Only a rejection is cleared; their notes stay in the audit log
-- (demo.unapprove).
DELETE FROM "exercise_demo_approvals" WHERE NOT "approved" AND "demo_slug" IN (
  'arnold-press', 'back-extension', 'band-face-pull', 'band-lat-pulldown',
  'band-pallof-press', 'band-pull-apart', 'barbell-curl', 'barbell-front-squat',
  'barbell-preacher-curl', 'belt-squat', 'bicycle-crunch', 'bird-dog',
  'cable-crunch', 'cable-hammer-curl', 'cable-pull-through', 'cable-rear-delt-fly',
  'cable-woodchopper', 'cable-y-raise', 'concentration-curl', 'curtsy-lunge',
  'dead-bug', 'decline-barbell-bench-press', 'decline-dumbbell-bench-press', 'decline-push-up',
  'dumbbell-fly', 'dumbbell-pullover', 'dumbbell-skull-crusher', 'face-pull',
  'floor-press', 'glute-kickback-machine', 'hack-squat', 'handstand-push-up',
  'high-to-low-cable-fly', 'hip-abduction-machine', 'incline-dumbbell-fly', 'incline-push-up',
  'landmine-press', 'leg-press-calf-raise', 'low-to-high-cable-fly', 'lying-leg-curl',
  'machine-chest-press', 'machine-crunch', 'machine-lateral-raise', 'machine-preacher-curl',
  'machine-row', 'machine-shoulder-press', 'machine-triceps-extension', 'pec-deck',
  'push-press', 'reverse-pec-deck', 'russian-twist', 'side-plank',
  'single-leg-calf-raise', 'single-leg-glute-bridge', 'smith-machine-bench-press', 'smith-machine-incline-press',
  'smith-machine-squat', 'stiff-leg-deadlift', 'suitcase-carry', 'sumo-deadlift',
  'sumo-squat', 'upright-row'
);
