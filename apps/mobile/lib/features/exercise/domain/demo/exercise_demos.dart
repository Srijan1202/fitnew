import 'dart:ui' show Offset;

import 'demo_rig.dart';

/// Beta 5.0 (owner): the 30 lifts with a demo, keyed by the exercise's slug.
/// Each is a few key moments; [Pose.cue] is the index of the written
/// instruction (exercises.json) that moment shows.
///
/// Standing lifts keep the near ankle at (0, ankle height); facing right.
const Map<String, Demo> exerciseDemos = {
  /* ------------------------------------------------------------ squat -- */
  'barbell-back-squat': Demo(
    gear: [Plate(at: Joint.upperBack)],
    elbowToward: Offset(-0.5, -1),
    frames: [
      Pose(
        trunk: 5,
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 1,
        hold: 0.4,
      ),
      Pose(
        trunk: 25,
        leg: Limb(140, 195),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
      ),
      Pose(
        trunk: 42,
        leg: Limb(96, 200),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        hold: 0.3,
      ),
    ],
  ),
  'goblet-squat': Demo(
    gear: [Dumbbells(single: true)],
    frames: [
      Pose(
        trunk: 3,
        hands: Offset.zero,
        handsFrom: Joint.chest,
        cue: 0,
        seconds: 0.3,
        hold: 0.2,
      ),
      Pose(
        trunk: 25,
        leg: Limb(100, 210),
        hands: Offset.zero,
        handsFrom: Joint.chest,
        cue: 1,
        seconds: 2,
        hold: 0.6,
      ),
      Pose(
        trunk: 3,
        hands: Offset.zero,
        handsFrom: Joint.chest,
        cue: 2,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),
  'leg-press': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.45),
    kneeToward: Offset(-1, 1),
    gear: [
      Bench(
        from: -0.3,
        to: 0.12,
        height: 0.36,
        backAngle: -50,
        backAt: -0.28,
        backLength: 0.75,
      ),
      Platform(angle: 45, rail: (Offset(0.25, 0.45), Offset(1.15, 1.35))),
    ],
    frames: [
      Pose(
        trunk: -50,
        head: 25,
        foot: -45,
        feet: Offset(0.6, 1.05),
        hands: Offset(0.05, 0.47),
        cue: 0,
        seconds: 0.3,
        hold: 0.2,
      ),
      Pose(
        trunk: -50,
        head: 25,
        foot: -45,
        feet: Offset(0.43, 0.88),
        hands: Offset(0.05, 0.47),
        cue: 1,
        seconds: 2,
        hold: 0.2,
      ),
      Pose(
        trunk: -50,
        head: 25,
        foot: -45,
        feet: Offset(0.6, 1.05),
        hands: Offset(0.05, 0.47),
        cue: 2,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),

  /* ------------------------------------------------------------ hinge -- */
  'conventional-deadlift': Demo(
    anchor: Joint.hand,
    gear: [Plate()],
    frames: [
      Pose(
        trunk: 52,
        arm: Limb(180, 180),
        feet: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.225),
        cue: 0,
        seconds: 1,
        hold: 0.4,
      ),
      Pose(
        trunk: 2,
        arm: Limb(180, 180),
        feet: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.86),
        cue: 2,
        seconds: 1.6,
        hold: 0.5,
      ),
      Pose(
        trunk: 45,
        arm: Limb(180, 180),
        feet: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.52),
        cue: 3,
        seconds: 1,
      ),
    ],
  ),
  'romanian-deadlift': Demo(
    anchor: Joint.hand,
    gear: [Plate()],
    frames: [
      Pose(
        trunk: 2,
        arm: Limb(180, 180),
        feet: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.85),
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 35,
        arm: Limb(180, 180),
        feet: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.66),
        cue: 1,
      ),
      Pose(
        trunk: 65,
        arm: Limb(180, 180),
        feet: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.45),
        cue: 2,
        hold: 0.3,
      ),
    ],
  ),
  'hip-thrust': Demo(
    anchor: Joint.shoulder,
    anchorAt: Offset(-0.12, 0.5),
    kneeToward: Offset(0, 1),
    elbowToward: Offset(0, 1),
    gear: [Bench(from: -0.7, to: -0.12), Plate(at: Joint.lap, radius: 0.17)],
    frames: [
      Pose(
        trunk: -55,
        head: 30,
        feet: Offset(0.78, Body.ankleHeight),
        hands: Offset.zero,
        handsFrom: Joint.lap,
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        head: 20,
        feet: Offset(0.78, Body.ankleHeight),
        hands: Offset.zero,
        handsFrom: Joint.lap,
        cue: 1,
      ),
      Pose(
        trunk: -90,
        head: 10,
        feet: Offset(0.78, Body.ankleHeight),
        hands: Offset.zero,
        handsFrom: Joint.lap,
        cue: 2,
        seconds: 0.2,
        hold: 0.6,
      ),
    ],
  ),

  /* ------------------------------------------------------------ lunge -- */
  'walking-lunge': Demo(
    anchor: Joint.hip,
    gear: [Dumbbells()],
    frames: [
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.45, Body.ankleHeight),
        feetFar: Offset(-0.42, 0.13),
        anchorAt: Offset(0.01, 0.82),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.45, Body.ankleHeight),
        feetFar: Offset(-0.42, 0.13),
        anchorAt: Offset(0.01, 0.52),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.45, Body.ankleHeight),
        feetFar: Offset(-0.42, 0.13),
        anchorAt: Offset(0.01, 0.82),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'bulgarian-split-squat': Demo(
    anchor: Joint.hip,
    gear: [Bench(from: -0.95, to: -0.5), Dumbbells()],
    frames: [
      Pose(
        trunk: 5,
        footFar: -90,
        feet: Offset(0.25, Body.ankleHeight),
        feetFar: Offset(-0.6, 0.5),
        anchorAt: Offset(-0.05, 0.84),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 10,
        footFar: -90,
        feet: Offset(0.25, Body.ankleHeight),
        feetFar: Offset(-0.6, 0.5),
        anchorAt: Offset(-0.05, 0.55),
        cue: 1,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 5,
        footFar: -90,
        feet: Offset(0.25, Body.ankleHeight),
        feetFar: Offset(-0.6, 0.5),
        anchorAt: Offset(-0.05, 0.84),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),

  /* -------------------------------------------------- horizontal push -- */
  'barbell-bench-press': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0.25, 0.53),
    kneeToward: Offset(0, 1),
    gear: [Bench(from: -0.7, to: 0.4), Plate()],
    frames: [
      Pose(
        trunk: -90,
        feet: Offset(0.8, Body.ankleHeight),
        hands: Offset(-0.2, 1.1),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: Offset(0.8, Body.ankleHeight),
        hands: Offset(-0.12, 0.7),
        cue: 1,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: Offset(0.8, Body.ankleHeight),
        hands: Offset(-0.2, 1.1),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'dumbbell-bench-press': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0.25, 0.53),
    kneeToward: Offset(0, 1),
    gear: [Bench(from: -0.7, to: 0.4), Dumbbells()],
    frames: [
      Pose(
        trunk: -90,
        feet: Offset(0.8, Body.ankleHeight),
        hands: Offset(-0.2, 0.72),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: Offset(0.8, Body.ankleHeight),
        hands: Offset(-0.22, 1.1),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: Offset(0.8, Body.ankleHeight),
        hands: Offset(-0.2, 0.74),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'push-up': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0, 0.01),
    elbowToward: Offset(-1, 0.6),
    frames: [
      Pose(
        trunk: 74,
        leg: Limb(254, 254),
        foot: 165,
        hands: Offset(1.27, 0.03),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 84,
        leg: Limb(264, 264),
        foot: 165,
        hands: Offset(1.27, 0.03),
        cue: 1,
        seconds: 1.6,
        hold: 0.2,
      ),
      Pose(
        trunk: 74,
        leg: Limb(254, 254),
        foot: 165,
        hands: Offset(1.27, 0.03),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),

  /* ---------------------------------------------------- vertical push -- */
  'overhead-press': Demo(
    gear: [Plate()],
    elbowToward: Offset(1, -1),
    frames: [
      Pose(
        head: -12,
        hands: Offset(0.1, 1.38),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(head: -15, hands: Offset(0.05, 1.62), cue: 1, seconds: 0.6),
      Pose(hands: Offset(0.02, 1.97), cue: 2, seconds: 0.6, hold: 0.4),
    ],
  ),
  'seated-dumbbell-shoulder-press': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [
      Bench(
        from: -0.25,
        to: 0.2,
        height: 0.45,
        backAngle: -5,
        backAt: -0.22,
        backLength: 0.75,
      ),
      Dumbbells(),
    ],
    frames: [
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0.03, 1.1),
        cue: 0,
        seconds: 0.4,
        hold: 0.2,
      ),
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0, 1.58),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0.03, 1.18),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),

  /* -------------------------------------------------- horizontal pull -- */
  'barbell-row': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(-0.28, 0.82),
    elbowToward: Offset(-1, 0.3),
    gear: [Plate()],
    frames: [
      Pose(
        trunk: 50,
        feet: Offset(0, Body.ankleHeight),
        hands: Offset(0.1, 0.58),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 50,
        feet: Offset(0, Body.ankleHeight),
        hands: Offset(0.04, 0.86),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),
  'dumbbell-row': Demo(
    anchor: Joint.kneeFar,
    anchorAt: Offset(0.1, 0.47),
    gear: [Bench(from: -0.4, to: 0.7), Dumbbells(nearOnly: true)],
    frames: [
      Pose(
        trunk: 78,
        leg: Limb(190, 175),
        legFar: Limb(180, -90),
        footFar: -90,
        armFar: Limb(180, 180),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 78,
        leg: Limb(190, 175),
        legFar: Limb(180, -90),
        footFar: -90,
        arm: Limb(-70, 180),
        armFar: Limb(180, 180),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 78,
        leg: Limb(190, 175),
        legFar: Limb(180, -90),
        footFar: -90,
        arm: Limb(178, 178),
        armFar: Limb(180, 180),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'seated-cable-row': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.46),
    kneeToward: Offset(0, 1),
    elbowToward: Offset(-1, 0),
    gear: [
      Bench(from: -0.25, to: 0.25, height: 0.38),
      Platform(angle: 90, length: 0.35),
      Cable(Offset(0.98, 0.4), handle: true),
    ],
    frames: [
      Pose(
        trunk: 2,
        foot: 0,
        feet: Offset(0.8, 0.42),
        hands: Offset(0.56, 0.8),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: -4,
        foot: 0,
        feet: Offset(0.8, 0.42),
        hands: Offset(0.2, 0.74),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 4,
        foot: 0,
        feet: Offset(0.8, 0.42),
        hands: Offset(0.57, 0.8),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),

  /* ---------------------------------------------------- vertical pull -- */
  'pull-up': Demo(
    anchor: Joint.hand,
    anchorAt: Offset(0, 2.25),
    gear: [PullBar(Offset(0, 2.25))],
    frames: [
      Pose(
        arm: Limb(4, 2),
        leg: Limb(185, 205),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: -10,
        head: 10,
        arm: Limb(150, 15),
        leg: Limb(185, 205),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(arm: Limb(4, 2), leg: Limb(185, 205), cue: 2, seconds: 1.8),
    ],
  ),
  'lat-pulldown': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.54),
    elbowToward: Offset(-0.3, -1),
    gear: [
      Bench(from: -0.25, to: 0.2, height: 0.46),
      Pad(Joint.knee, from: Joint.hip, side: 0.1, along: -0.06),
      Cable(Offset(0, 2.2), handle: true),
    ],
    frames: [
      Pose(
        trunk: -8,
        leg: Limb(95, 180),
        hands: Offset(0, 1.58),
        cue: 0,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(
        trunk: -12,
        leg: Limb(95, 180),
        hands: Offset(0.04, 1.0),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -8,
        leg: Limb(95, 180),
        hands: Offset(0, 1.58),
        cue: 2,
        seconds: 1.8,
      ),
    ],
  ),

  /* -------------------------------------------------------------- arms -- */
  'dumbbell-curl': Demo(
    gear: [Dumbbells()],
    frames: [
      Pose(arm: Limb(178, 178), cue: 0, seconds: 0.8, hold: 0.2),
      Pose(arm: Limb(175, 15), cue: 1, seconds: 1, hold: 0.3),
      Pose(arm: Limb(177, 100), cue: 2, seconds: 0.9),
    ],
  ),
  'hammer-curl': Demo(
    gear: [Dumbbells(neutral: true)],
    frames: [
      Pose(arm: Limb(178, 178), cue: 0, seconds: 0.8, hold: 0.2),
      Pose(arm: Limb(175, 15), cue: 1, seconds: 1, hold: 0.3),
      Pose(arm: Limb(177, 100), cue: 2, seconds: 0.9),
    ],
  ),
  'triceps-pushdown': Demo(
    gear: [Cable(Offset(0.32, 2.15), handle: true)],
    frames: [
      Pose(trunk: 8, arm: Limb(176, 80), cue: 0, seconds: 0.3, hold: 0.2),
      Pose(trunk: 8, arm: Limb(178, 178), cue: 1, seconds: 1, hold: 0.3),
      Pose(trunk: 8, arm: Limb(176, 75), cue: 2, seconds: 1.6),
    ],
  ),
  'overhead-triceps-extension': Demo(
    gear: [Dumbbells(single: true)],
    frames: [
      Pose(arm: Limb(5, 3), cue: 0, seconds: 1, hold: 0.3),
      Pose(arm: Limb(8, 200), cue: 1, seconds: 1.6, hold: 0.2),
      Pose(arm: Limb(5, 3), cue: 2, seconds: 1),
    ],
  ),

  /* --------------------------------------------------------- shoulders -- */
  'dumbbell-lateral-raise': Demo(
    view: DemoView.front,
    gear: [Dumbbells()],
    frames: [
      Pose(arm: Limb(172, 168), cue: 0, seconds: 0.9, hold: 0.2),
      Pose(arm: Limb(92, 100), cue: 1, seconds: 1, hold: 0.3),
      Pose(arm: Limb(130, 135), cue: 2, seconds: 0.9),
    ],
  ),
  'rear-delt-fly': Demo(
    view: DemoView.front,
    gear: [Dumbbells()],
    frames: [
      Pose(trunk: 70, arm: Limb(180, 180), cue: 0, seconds: 0.9, hold: 0.2),
      Pose(trunk: 70, arm: Limb(95, 100), cue: 1, seconds: 1, hold: 0.3),
      Pose(trunk: 70, arm: Limb(140, 145), cue: 2, seconds: 0.9),
    ],
  ),

  /* ------------------------------------------------------------- chest -- */
  'cable-fly': Demo(
    view: DemoView.front,
    gear: [Cable(Offset(0.85, 1.55), handle: true, mirrored: true)],
    frames: [
      Pose(hands: Offset(0.72, 1.42), cue: 0, seconds: 0.2, hold: 0.3),
      Pose(hands: Offset(0.06, 1.24), cue: 1, seconds: 1.2, hold: 0.3),
      Pose(hands: Offset(0.72, 1.42), cue: 2, seconds: 1.8),
    ],
  ),

  /* -------------------------------------------------------------- legs -- */
  'leg-extension': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.58),
    gear: [
      Bench(
        from: -0.3,
        to: 0.15,
        height: 0.5,
        backAngle: -12,
        backAt: -0.28,
        backLength: 0.7,
      ),
      Pad(Joint.ankle, from: Joint.knee, side: 0.07),
    ],
    frames: [
      Pose(
        trunk: -12,
        leg: Limb(90, 178),
        arm: Limb(180, 160),
        cue: 0,
        seconds: 0.9,
        hold: 0.2,
      ),
      Pose(
        trunk: -12,
        leg: Limb(90, 92),
        arm: Limb(180, 160),
        cue: 1,
        seconds: 1,
        hold: 0.5,
      ),
      Pose(
        trunk: -12,
        leg: Limb(90, 135),
        arm: Limb(180, 160),
        cue: 2,
        seconds: 0.9,
      ),
    ],
  ),
  'seated-leg-curl': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.58),
    gear: [
      Bench(
        from: -0.3,
        to: 0.15,
        height: 0.5,
        backAngle: -15,
        backAt: -0.28,
        backLength: 0.7,
      ),
      Pad(Joint.knee, from: Joint.hip, side: 0.1, along: -0.08),
      Pad(Joint.ankle, from: Joint.knee, side: -0.07),
    ],
    frames: [
      Pose(
        trunk: -15,
        leg: Limb(92, 95),
        arm: Limb(180, 160),
        cue: 0,
        seconds: 0.9,
        hold: 0.2,
      ),
      Pose(
        trunk: -15,
        leg: Limb(92, 200),
        arm: Limb(180, 160),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -15,
        leg: Limb(92, 140),
        arm: Limb(180, 160),
        cue: 2,
        seconds: 0.9,
      ),
    ],
  ),
  'standing-calf-raise': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0.18, 0.14),
    gear: [
      Block(from: -0.02, to: 0.24, height: 0.12),
      Pad(Joint.shoulder, from: Joint.hip, along: 0.07),
    ],
    frames: [
      Pose(cue: 0, seconds: 0.6, hold: 0.2),
      Pose(foot: 140, cue: 1, seconds: 1, hold: 0.5),
      Pose(foot: 68, cue: 2, seconds: 1.5, hold: 0.3),
    ],
  ),

  /* -------------------------------------------------------------- core -- */
  'plank': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0, 0.01),
    holdOnly: true,
    frames: [
      Pose(
        trunk: 84,
        leg: Limb(264, 264),
        foot: 170,
        arm: Limb(180, 90),
        cue: 0,
        seconds: 1,
        hold: 1.2,
      ),
      Pose(
        trunk: 84.5,
        leg: Limb(264.5, 264.5),
        foot: 170,
        arm: Limb(180, 90),
        cue: 1,
        seconds: 1,
        hold: 1.2,
      ),
      Pose(
        trunk: 84,
        leg: Limb(264, 264),
        foot: 170,
        arm: Limb(180, 90),
        cue: 2,
        seconds: 1,
        hold: 1.2,
      ),
    ],
  ),
  'hanging-leg-raise': Demo(
    anchor: Joint.hand,
    anchorAt: Offset(0, 2.25),
    gear: [PullBar(Offset(0, 2.25))],
    frames: [
      Pose(arm: Limb(2, 2), cue: 0, seconds: 0.3, hold: 0.3),
      Pose(
        trunk: -12,
        arm: Limb(2, 2),
        leg: Limb(88, 88),
        cue: 1,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(trunk: -5, arm: Limb(2, 2), leg: Limb(135, 135), cue: 2, seconds: 1),
    ],
  ),
};

/// Close variants that share a demo: the movement is the same; [note]
/// says what differs. Listed one by one, never guessed from the pattern.
const Map<String, (String, String)> demoVariants = {
  'kettlebell-goblet-squat': (
    'goblet-squat',
    'Hold the kettlebell by the horns.'
  ),
  'chin-up': ('pull-up', 'Palms facing you.'),
  'neutral-grip-pull-up': ('pull-up', 'Palms facing each other.'),
  'band-assisted-pull-up': (
    'pull-up',
    'A band under your knees takes some of your weight.'
  ),
  'close-grip-lat-pulldown': ('lat-pulldown', 'A close, palms-in handle.'),
  'rope-pushdown': (
    'triceps-pushdown',
    'A rope: spread its ends at the bottom.'
  ),
  'barbell-bulgarian-split-squat': (
    'bulgarian-split-squat',
    'A barbell on your upper back instead of dumbbells.'
  ),
  'dumbbell-romanian-deadlift': (
    'romanian-deadlift',
    'Dumbbells instead of a bar.'
  ),
  'dumbbell-calf-raise': (
    'standing-calf-raise',
    'Dumbbells at your sides instead of the machine.'
  ),
  'band-lateral-raise': (
    'dumbbell-lateral-raise',
    'A band under your feet instead of dumbbells.'
  ),
  'hanging-knee-raise': (
    'hanging-leg-raise',
    'Bend your knees as they come up: easier.'
  ),
  'ez-bar-curl': ('dumbbell-curl', 'An EZ bar in both hands.'),
};

/// The demo for an exercise, with the note when it is a variant's.
({Demo demo, String? note})? demoFor(String slug) {
  final own = exerciseDemos[slug];
  if (own != null) return (demo: own, note: null);
  final v = demoVariants[slug];
  if (v == null) return null;
  return (demo: exerciseDemos[v.$1]!, note: v.$2);
}
