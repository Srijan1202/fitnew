import 'dart:ui' show Offset;

import 'demo_rig.dart';

/// Beta 5.2 (owner): the rest of the library's lifts, by movement family,
/// on the same rig and conventions as the first 30 (exercise_demos.dart).
/// Each shows in the app only once approved in the admin panel.
const Map<String, Demo> moreDemos = {
  ..._squats,
  ..._hinges,
  ..._lunges,
  ..._horizontalPush,
  ..._verticalPush,
  ..._horizontalPull,
  ..._verticalPull,
  ..._arms,
  ..._shoulders,
  ..._chest,
  ..._legs,
  ..._calves,
  ..._core,
  ..._carries,
};

const _ankle = Offset(0, Body.ankleHeight);

/* -------------------------------------------------------------- squats -- */

const Map<String, Demo> _squats = {
  'barbell-front-squat': Demo(
    // Beta 5.6 (owner: "wrong angle and position"): the bar in the front
    // rack, on the shoulders with the elbows high and forward; the torso
    // stays upright.
    gear: [Plate()],
    elbowToward: Offset(1, 0),
    frames: [
      Pose(
        trunk: 4,
        hands: Offset(0.03, 0.08),
        handsFrom: Joint.shoulder,
        cue: 0,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 12,
        leg: Limb(128, 206),
        hands: Offset(0.03, 0.08),
        handsFrom: Joint.shoulder,
        cue: 1,
        seconds: 1.2,
      ),
      Pose(
        trunk: 16,
        leg: Limb(95, 218),
        hands: Offset(0.03, 0.08),
        handsFrom: Joint.shoulder,
        cue: 2,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),
  'dumbbell-squat': Demo(
    gear: [Dumbbells()],
    frames: [
      Pose(trunk: 3, arm: Limb(180, 180), cue: 0, seconds: 1, hold: 0.3),
      Pose(
        trunk: 32,
        leg: Limb(98, 205),
        arm: Limb(178, 178),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(trunk: 3, arm: Limb(180, 180), cue: 2, seconds: 1, hold: 0.2),
    ],
  ),
  'bodyweight-squat': Demo(
    frames: [
      Pose(trunk: 3, arm: Limb(90, 90), cue: 0, seconds: 1, hold: 0.3),
      Pose(
        trunk: 35,
        leg: Limb(96, 202),
        arm: Limb(85, 85),
        cue: 1,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(trunk: 0, arm: Limb(180, 180), cue: 2, seconds: 1, hold: 0.3),
    ],
  ),
  'hack-squat': Demo(
    // Beta 5.6 (owner: "wrong machine depiction"): the back on a pad that
    // rides rails leaning back; the hips travel down and forward along them,
    // the feet on an angled platform.
    anchor: Joint.hip,
    kneeToward: Offset(1, 0.3),
    elbowToward: Offset(0.3, -1),
    gear: [
      Line(Offset(-0.29, 0.33), Offset(-1.01, 1.58), width: 0.05),
      Line(Offset(-0.29, 0.33), Offset(-0.29, 0), width: 0.04),
      Line(Offset(-1.01, 1.58), Offset(-1.01, 0), width: 0.04),
      Sled(from: Joint.hip, to: Joint.shoulder, side: 0.11, past: 0.12),
      Block(from: -0.2, to: 0.35, height: 0.08),
      Platform(angle: 190, length: 0.45),
      Pad(Joint.shoulder, from: Joint.hip, along: 0.05, radius: 0.07),
    ],
    frames: [
      Pose(
        trunk: -30,
        foot: 100,
        feet: Offset(0, 0.15),
        anchorAt: Offset(-0.425, 0.886),
        hands: Offset(0.12, 0.02),
        handsFrom: Joint.shoulder,
        cue: 0,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: -30,
        foot: 100,
        feet: Offset(0, 0.15),
        anchorAt: Offset(-0.215, 0.522),
        hands: Offset(0.12, 0.02),
        handsFrom: Joint.shoulder,
        cue: 1,
        seconds: 2.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -30,
        foot: 100,
        feet: Offset(0, 0.15),
        anchorAt: Offset(-0.425, 0.886),
        hands: Offset(0.12, 0.02),
        handsFrom: Joint.shoulder,
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'smith-machine-squat': Demo(
    // Beta 5.6 (owner): the bar rides straight up and down the Smith
    // machine's rail; the feet stay a little ahead of it.
    anchor: Joint.upperBack,
    gear: [
      Line(Offset(0, 0), Offset(0, 2.15), width: 0.035),
      Plate(at: Joint.upperBack),
    ],
    elbowToward: Offset(-0.5, -1),
    frames: [
      Pose(
        trunk: 6,
        feet: Offset(0.14, Body.ankleHeight),
        anchorAt: Offset(0, 1.39),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 22,
        feet: Offset(0.14, Body.ankleHeight),
        anchorAt: Offset(0, 0.98),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 2.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 6,
        feet: Offset(0.14, Body.ankleHeight),
        anchorAt: Offset(0, 1.39),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'box-squat': Demo(
    gear: [
      Block(from: -0.5, to: -0.12, height: 0.42),
      Plate(at: Joint.upperBack),
    ],
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
        trunk: 38,
        leg: Limb(92, 190),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 2,
        hold: 0.6,
      ),
      Pose(
        trunk: 5,
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),
  'sumo-squat': Demo(
    // Beta 5.6 (owner: "leg moving too much and slipping"): the feet stay
    // planted wide; the hips sink straight down, knees out.
    view: DemoView.front,
    anchor: Joint.hip,
    kneeToward: Offset(1, 0),
    gear: [Dumbbells(single: true)],
    frames: [
      Pose(
        feet: Offset(0.36, Body.ankleHeight),
        anchorAt: Offset(0, 0.89),
        hands: Offset(0.02, 0.86),
        handsFar: Offset(-0.02, 0.86),
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 10,
        feet: Offset(0.36, Body.ankleHeight),
        thighScale: 0.75,
        anchorAt: Offset(0, 0.6),
        hands: Offset(0.02, 0.56),
        handsFar: Offset(-0.02, 0.56),
        cue: 1,
        seconds: 2.2,
        hold: 0.3,
      ),
      Pose(
        feet: Offset(0.36, Body.ankleHeight),
        anchorAt: Offset(0, 0.89),
        hands: Offset(0.02, 0.86),
        handsFar: Offset(-0.02, 0.86),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'band-squat': Demo(
    elbowToward: Offset(0.3, -1),
    gear: [Link(fromJoint: Joint.toe, band: true), Handles()],
    frames: [
      Pose(
        trunk: 3,
        hands: Offset(0.06, -0.05),
        handsFrom: Joint.shoulder,
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 32,
        leg: Limb(98, 204),
        hands: Offset(0.06, -0.05),
        handsFrom: Joint.shoulder,
        cue: 1,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        hands: Offset(0.06, -0.05),
        handsFrom: Joint.shoulder,
        cue: 2,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),
  'jump-squat': Demo(
    frames: [
      Pose(
        trunk: 35,
        leg: Limb(100, 200),
        arm: Limb(200, 200),
        anchorAt: _ankle,
        cue: 0,
        seconds: 0.4,
        hold: 0.2,
      ),
      Pose(
        trunk: 0,
        foot: 150,
        footFar: 150,
        arm: Limb(30, 30),
        anchorAt: Offset(0, 0.32),
        seconds: 0.45,
      ),
      Pose(
        trunk: 8,
        leg: Limb(160, 190),
        arm: Limb(120, 120),
        anchorAt: _ankle,
        cue: 1,
        seconds: 0.45,
      ),
      Pose(
        trunk: 35,
        leg: Limb(100, 200),
        arm: Limb(200, 200),
        anchorAt: _ankle,
        cue: 2,
        seconds: 0.5,
        hold: 0.3,
      ),
    ],
  ),
  'pistol-squat': Demo(
    frames: [
      Pose(
        trunk: 3,
        legFar: Limb(110, 110),
        arm: Limb(90, 90),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 38,
        leg: Limb(80, 205),
        legFar: Limb(88, 88),
        arm: Limb(85, 85),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        legFar: Limb(110, 110),
        arm: Limb(90, 90),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'belt-squat': Demo(
    // Beta 5.6 (owner: "completely wrong"): from the front, standing on two
    // boxes with the plate hanging from the hip belt between them.
    view: DemoView.front,
    anchor: Joint.hip,
    kneeToward: Offset(1, 0),
    elbowToward: Offset(1, -0.6),
    gear: [
      Block(from: 0.2, to: 0.55, height: 0.42),
      Block(from: -0.55, to: -0.2, height: 0.42),
      Hang(length: 0.78),
    ],
    frames: [
      Pose(
        feet: Offset(0.32, 0.49),
        anchorAt: Offset(0, 1.325),
        hands: Offset(0.04, 1.655),
        handsFar: Offset(-0.04, 1.655),
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        feet: Offset(0.32, 0.49),
        thighScale: 0.5,
        anchorAt: Offset(0, 1.06),
        hands: Offset(0.04, 1.39),
        handsFar: Offset(-0.04, 1.39),
        cue: 1,
        seconds: 2.2,
        hold: 0.3,
      ),
      Pose(
        feet: Offset(0.32, 0.49),
        anchorAt: Offset(0, 1.325),
        hands: Offset(0.04, 1.655),
        handsFar: Offset(-0.04, 1.655),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
};

/* -------------------------------------------------------------- hinges -- */

const Map<String, Demo> _hinges = {
  'sumo-deadlift': Demo(
    // Beta 5.6.1 (owner: "weird hand movement"): the arms hang straight
    // from the shoulders the whole lift, inside the knees; only the hips
    // and the chest rise, so the bar goes straight up.
    view: DemoView.front,
    anchor: Joint.hip,
    kneeToward: Offset(1, 0),
    gear: [Bar()],
    frames: [
      Pose(
        trunk: 58,
        feet: Offset(0.36, Body.ankleHeight),
        thighScale: 0.8,
        anchorAt: Offset(0, 0.6),
        arm: Limb(184, 184),
        cue: 0,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 30,
        feet: Offset(0.36, Body.ankleHeight),
        thighScale: 0.9,
        anchorAt: Offset(0, 0.78),
        arm: Limb(184, 184),
        cue: 1,
        seconds: 1,
      ),
      Pose(
        feet: Offset(0.36, Body.ankleHeight),
        anchorAt: Offset(0, 0.89),
        arm: Limb(184, 184),
        cue: 2,
        seconds: 0.9,
        hold: 0.5,
      ),
      Pose(
        trunk: 30,
        feet: Offset(0.36, Body.ankleHeight),
        thighScale: 0.9,
        anchorAt: Offset(0, 0.78),
        arm: Limb(184, 184),
        seconds: 1.1,
      ),
    ],
  ),
  'single-leg-romanian-deadlift': Demo(
    gear: [Dumbbells(nearOnly: true)],
    frames: [
      Pose(
        trunk: 2,
        leg: Limb(180, 182),
        legFar: Limb(185, 185),
        cue: 0,
        seconds: 0.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 78,
        leg: Limb(172, 192),
        legFar: Limb(256, 256),
        arm: Limb(180, 180),
        armFar: Limb(150, 180),
        cue: 1,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 2,
        leg: Limb(180, 182),
        legFar: Limb(185, 185),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'kettlebell-swing': Demo(
    gear: [Kettlebell(single: true)],
    elbowToward: Offset(0, -1),
    frames: [
      Pose(
        trunk: 55,
        leg: Limb(150, 195),
        arm: Limb(205, 205),
        cue: 0,
        seconds: 0.6,
        hold: 0.2,
      ),
      Pose(trunk: -3, arm: Limb(90, 92), cue: 1, seconds: 0.6, hold: 0.15),
      Pose(
        trunk: 50,
        leg: Limb(152, 194),
        arm: Limb(200, 200),
        cue: 2,
        seconds: 0.6,
      ),
    ],
  ),
  'kettlebell-deadlift': Demo(
    anchor: Joint.hand,
    gear: [Kettlebell(single: true)],
    frames: [
      Pose(
        trunk: 48,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(0.04, 0.2),
        cue: 0,
        seconds: 1,
        hold: 0.4,
      ),
      Pose(
        trunk: 2,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(0.04, 0.86),
        cue: 1,
        seconds: 1.4,
        hold: 0.4,
      ),
      Pose(
        trunk: 40,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(0.04, 0.48),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'good-morning': Demo(
    gear: [Plate(at: Joint.upperBack)],
    elbowToward: Offset(-0.5, -1),
    frames: [
      Pose(
        trunk: 3,
        leg: Limb(178, 184),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 75,
        leg: Limb(160, 190),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        leg: Limb(178, 184),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'dumbbell-hip-thrust': Demo(
    anchor: Joint.shoulder,
    anchorAt: Offset(-0.12, 0.5),
    kneeToward: Offset(0, 1),
    elbowToward: Offset(0, 1),
    gear: [Bench(from: -0.7, to: -0.12), Dumbbells(single: true)],
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
  'glute-bridge': Demo(
    anchor: Joint.shoulder,
    anchorAt: Offset(-0.25, 0.1),
    kneeToward: Offset(0, 1),
    frames: [
      Pose(
        trunk: -90,
        arm: Limb(92, 92),
        feet: Offset(0.6, Body.ankleHeight),
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: -122,
        arm: Limb(95, 95),
        feet: Offset(0.6, Body.ankleHeight),
        cue: 1,
        seconds: 1,
        hold: 0.2,
      ),
      Pose(
        trunk: -125,
        arm: Limb(96, 96),
        feet: Offset(0.6, Body.ankleHeight),
        cue: 2,
        seconds: 0.2,
        hold: 0.8,
      ),
    ],
  ),
  'single-leg-glute-bridge': Demo(
    anchor: Joint.shoulder,
    anchorAt: Offset(-0.25, 0.1),
    kneeToward: Offset(0, 1),
    frames: [
      // Beta 5.6 (owner: "why feet rotated"): the raised foot keeps square
      // to its leg.
      Pose(
        trunk: -90,
        arm: Limb(92, 92),
        feet: Offset(0.6, Body.ankleHeight),
        feetFar: Offset(1.1, 1.1),
        footFar: -40,
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: -122,
        arm: Limb(95, 95),
        feet: Offset(0.6, Body.ankleHeight),
        feetFar: Offset(1.4, 1.0),
        footFar: -17,
        cue: 1,
        seconds: 1,
        hold: 0.4,
      ),
      Pose(
        trunk: -90,
        arm: Limb(92, 92),
        feet: Offset(0.6, Body.ankleHeight),
        feetFar: Offset(1.1, 1.1),
        footFar: -40,
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'back-extension': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0.05, 1.0),
    gear: [
      Line(Offset(-0.05, 0.93), Offset(0.17, 1.05), width: 0.07),
      Line(Offset(-0.6, 0.35), Offset(-0.48, 0.24), width: 0.06),
      Line(Offset(0.05, 0.93), Offset(0.05, 0), width: 0.04),
      Line(Offset(-0.55, 0.3), Offset(-0.55, 0), width: 0.04),
    ],
    frames: [
      // Beta 5.6 (owner: "weird hand movement"): the arms stay folded on
      // the chest and turn with the body.
      Pose(
        trunk: 45,
        leg: Limb(225, 225),
        foot: 135,
        arm: Limb(215, 55),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 162,
        leg: Limb(225, 225),
        foot: 135,
        arm: Limb(332, 172),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 45,
        leg: Limb(225, 225),
        foot: 135,
        arm: Limb(215, 55),
        cue: 2,
        seconds: 1.4,
        hold: 0.3,
      ),
    ],
  ),
  'cable-pull-through': Demo(
    anchor: Joint.hip,
    gear: [Cable(Offset(-0.7, 0.15), handle: true)],
    elbowToward: Offset(1, 0),
    frames: [
      // Beta 5.6 (owner: "weird hand position"): straight arms, the rope
      // between the legs; it pulls the hands back as the hips hinge.
      Pose(
        trunk: 3,
        feet: _ankle,
        anchorAt: Offset(0.0, 0.92),
        hands: Offset(0.05, 0.89),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 62,
        feet: _ankle,
        anchorAt: Offset(-0.3, 0.84),
        hands: Offset(-0.05, 0.58),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        feet: _ankle,
        anchorAt: Offset(0.0, 0.92),
        hands: Offset(0.05, 0.89),
        cue: 2,
        seconds: 1.2,
        hold: 0.4,
      ),
    ],
  ),
  'stiff-leg-deadlift': Demo(
    // Beta 5.6 (owner: "lower leg should be straight"): the shins stay
    // nearly vertical, the hips go back, the knees barely bend.
    gear: [Plate()],
    elbowToward: Offset(-1, 0),
    frames: [
      Pose(
        trunk: 2,
        leg: Limb(178, 180),
        hands: Offset(0.06, 0.9),
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 40,
        leg: Limb(171, 180),
        hands: Offset(0.16, 0.78),
        seconds: 1.1,
      ),
      Pose(
        trunk: 78,
        leg: Limb(165, 180),
        hands: Offset(0.24, 0.51),
        cue: 1,
        seconds: 1.1,
        hold: 0.3,
      ),
      Pose(
        trunk: 40,
        leg: Limb(171, 180),
        hands: Offset(0.16, 0.78),
        seconds: 0.7,
      ),
      Pose(
        trunk: 2,
        leg: Limb(178, 180),
        hands: Offset(0.06, 0.9),
        cue: 2,
        seconds: 0.7,
        hold: 0.3,
      ),
    ],
  ),
  'band-good-morning': Demo(
    gear: [Link(fromJoint: Joint.toe, toJoint: Joint.upperBack, band: true)],
    elbowToward: Offset(-0.5, -1),
    frames: [
      Pose(
        trunk: 3,
        leg: Limb(178, 184),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 72,
        leg: Limb(160, 190),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 1.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 0,
        leg: Limb(180, 182),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1.2,
        hold: 0.4,
      ),
    ],
  ),
  'trap-bar-deadlift': Demo(
    anchor: Joint.hand,
    gear: [Plate()],
    frames: [
      Pose(
        trunk: 2,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(-0.02, 0.86),
        cue: 0,
        seconds: 0.4,
        hold: 0.4,
      ),
      Pose(
        trunk: 30,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(-0.02, 0.5),
        seconds: 0.8,
      ),
      Pose(
        trunk: 38,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(-0.02, 0.24),
        cue: 1,
        seconds: 0.6,
        hold: 0.4,
      ),
      Pose(
        trunk: 30,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(-0.02, 0.5),
        seconds: 0.6,
      ),
      Pose(
        trunk: 2,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(-0.02, 0.86),
        cue: 2,
        seconds: 0.7,
        hold: 0.3,
      ),
    ],
  ),
  'rack-pull': Demo(
    anchor: Joint.hand,
    gear: [
      Line(Offset(0.2, 0), Offset(0.2, 1.2), width: 0.04),
      Line(Offset(0.0, 0.48), Offset(0.24, 0.48), width: 0.035),
      Plate(),
    ],
    frames: [
      Pose(
        trunk: 42,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(0.08, 0.52),
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 42,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(0.08, 0.52),
        cue: 1,
        seconds: 0.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 2,
        arm: Limb(180, 180),
        feet: _ankle,
        anchorAt: Offset(0.08, 0.86),
        cue: 2,
        seconds: 1,
        hold: 0.5,
      ),
    ],
  ),
};

/* -------------------------------------------------------------- lunges -- */

// Standing on both feet, hips over them (the lunges' start).
const _hipsUp = Offset(0, 0.93);

const Map<String, Demo> _lunges = {
  'reverse-lunge': Demo(
    anchor: Joint.hip,
    gear: [Dumbbells()],
    frames: [
      Pose(
        trunk: 3,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        footFar: 125,
        feet: _ankle,
        feetFar: Offset(-0.45, 0.24),
        anchorAt: Offset(-0.2, 0.88),
        seconds: 0.5,
      ),
      Pose(
        trunk: 3,
        footFar: 135,
        feet: _ankle,
        feetFar: Offset(-0.86, 0.13),
        anchorAt: Offset(-0.43, 0.82),
        seconds: 0.5,
      ),
      Pose(
        trunk: 3,
        footFar: 135,
        feet: _ankle,
        feetFar: Offset(-0.86, 0.13),
        anchorAt: Offset(-0.43, 0.52),
        cue: 1,
        seconds: 1.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        footFar: 125,
        feet: _ankle,
        feetFar: Offset(-0.45, 0.24),
        anchorAt: Offset(-0.2, 0.88),
        cue: 2,
        seconds: 1,
      ),
      Pose(
        trunk: 3,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        seconds: 0.4,
      ),
    ],
  ),
  'bodyweight-lunge': Demo(
    anchor: Joint.hip,
    frames: [
      Pose(
        trunk: 3,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 120,
        feet: Offset(0.45, 0.24),
        feetFar: _ankle,
        anchorAt: Offset(0.2, 0.88),
        seconds: 0.5,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.87, Body.ankleHeight),
        feetFar: Offset(0.01, 0.13),
        anchorAt: Offset(0.44, 0.52),
        cue: 0,
        seconds: 1.3,
        hold: 0.2,
      ),
      Pose(
        trunk: 0,
        foot: 90,
        footFar: 135,
        feet: Offset(0.87, Body.ankleHeight),
        feetFar: Offset(0.01, 0.13),
        anchorAt: Offset(0.44, 0.52),
        cue: 1,
        seconds: 0.3,
        hold: 0.4,
      ),
      Pose(
        trunk: 3,
        foot: 120,
        feet: Offset(0.45, 0.24),
        feetFar: _ankle,
        anchorAt: Offset(0.2, 0.88),
        cue: 2,
        seconds: 1,
      ),
      Pose(
        trunk: 3,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        seconds: 0.4,
      ),
    ],
  ),
  'barbell-lunge': Demo(
    anchor: Joint.hip,
    gear: [Plate(at: Joint.upperBack)],
    elbowToward: Offset(-0.5, -1),
    frames: [
      Pose(
        trunk: 3,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 120,
        feet: Offset(0.45, 0.24),
        feetFar: _ankle,
        anchorAt: Offset(0.2, 0.88),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        seconds: 0.5,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.87, Body.ankleHeight),
        feetFar: Offset(0.01, 0.13),
        anchorAt: Offset(0.44, 0.82),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 0.5,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.87, Body.ankleHeight),
        feetFar: Offset(0.01, 0.13),
        anchorAt: Offset(0.44, 0.52),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 1.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 120,
        feet: Offset(0.45, 0.24),
        feetFar: _ankle,
        anchorAt: Offset(0.2, 0.88),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1,
      ),
      Pose(
        trunk: 3,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        seconds: 0.4,
      ),
    ],
  ),
  'step-up': Demo(
    anchor: Joint.hip,
    gear: [Block(from: 0.18, to: 0.62, height: 0.45), Dumbbells()],
    frames: [
      Pose(
        trunk: 8,
        foot: 90,
        feet: Offset(0.36, 0.52),
        feetFar: _ankle,
        anchorAt: Offset(0.02, 0.92),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 140,
        feet: Offset(0.36, 0.52),
        feetFar: Offset(0.2, 0.68),
        anchorAt: Offset(0.33, 1.37),
        cue: 1,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 8,
        foot: 90,
        feet: Offset(0.36, 0.52),
        feetFar: _ankle,
        anchorAt: Offset(0.02, 0.92),
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'bodyweight-step-up': Demo(
    anchor: Joint.hip,
    gear: [Block(from: 0.18, to: 0.62, height: 0.45)],
    frames: [
      Pose(
        trunk: 8,
        foot: 90,
        feet: Offset(0.36, 0.52),
        feetFar: _ankle,
        anchorAt: Offset(0.02, 0.92),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 140,
        feet: Offset(0.36, 0.52),
        feetFar: Offset(0.2, 0.68),
        anchorAt: Offset(0.33, 1.37),
        cue: 1,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 8,
        foot: 90,
        feet: Offset(0.36, 0.52),
        feetFar: _ankle,
        anchorAt: Offset(0.02, 0.92),
        seconds: 1.4,
      ),
    ],
  ),
  'lateral-lunge': Demo(
    view: DemoView.front,
    anchor: Joint.hip,
    gear: [Dumbbells(single: true)],
    frames: [
      Pose(
        feet: Offset(0.02, Body.ankleHeight),
        feetFar: Offset(-0.22, Body.ankleHeight),
        anchorAt: Offset(-0.1, 0.93),
        hands: Offset(-0.06, 1.2),
        handsFar: Offset(-0.14, 1.2),
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 10,
        feet: Offset(0.95, Body.ankleHeight),
        feetFar: Offset(-0.22, Body.ankleHeight),
        anchorAt: Offset(0.37, 0.8),
        hands: Offset(0.41, 1.07),
        handsFar: Offset(0.33, 1.07),
        cue: 0,
        seconds: 0.8,
      ),
      Pose(
        trunk: 30,
        feet: Offset(0.95, Body.ankleHeight),
        feetFar: Offset(-0.22, Body.ankleHeight),
        anchorAt: Offset(0.52, 0.6),
        hands: Offset(0.56, 0.84),
        handsFar: Offset(0.48, 0.84),
        cue: 1,
        seconds: 1.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 10,
        feet: Offset(0.95, Body.ankleHeight),
        feetFar: Offset(-0.22, Body.ankleHeight),
        anchorAt: Offset(0.37, 0.8),
        hands: Offset(0.41, 1.07),
        handsFar: Offset(0.33, 1.07),
        cue: 2,
        seconds: 1,
      ),
      Pose(
        feet: Offset(0.02, Body.ankleHeight),
        feetFar: Offset(-0.22, Body.ankleHeight),
        anchorAt: Offset(-0.1, 0.93),
        hands: Offset(-0.06, 1.2),
        handsFar: Offset(-0.14, 1.2),
        seconds: 0.8,
      ),
    ],
  ),
  'curtsy-lunge': Demo(
    // Beta 5.6.1 (owner: "give front view", and before that "hind leg
    // should be at 90 degree"): from the front, the back leg steps behind
    // and across; its thigh drops almost straight down to the knee by the
    // floor and its shin points back and out (short, seen from the front)
    // — the 90° bend. The back leg is drawn behind the body.
    view: DemoView.front,
    anchor: Joint.hip,
    farLegBehind: true,
    gear: [Dumbbells()],
    frames: [
      Pose(
        feet: Offset(0.11, Body.ankleHeight),
        feetFar: Offset(-0.11, Body.ankleHeight),
        anchorAt: Offset(0, 0.93),
        seconds: 0.6,
        hold: 0.3,
      ),
      Pose(
        feet: Offset(0.11, Body.ankleHeight),
        feetFar: Offset(0.28, 0.1),
        thighScale: 0.8,
        thighScaleFar: 1,
        shinScaleFar: 0.85,
        anchorAt: Offset(0.03, 0.82),
        cue: 0,
        seconds: 0.8,
      ),
      Pose(
        trunk: 10,
        feet: Offset(0.11, Body.ankleHeight),
        feetFar: Offset(0.3, 0.07),
        thighScale: 0.2,
        thighScaleFar: 1,
        shinScaleFar: 0.6,
        anchorAt: Offset(0.06, 0.56),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        feet: Offset(0.11, Body.ankleHeight),
        feetFar: Offset(0.28, 0.1),
        thighScale: 0.8,
        thighScaleFar: 1,
        shinScaleFar: 0.85,
        anchorAt: Offset(0.03, 0.82),
        cue: 2,
        seconds: 1,
      ),
      Pose(
        feet: Offset(0.11, Body.ankleHeight),
        feetFar: Offset(-0.11, Body.ankleHeight),
        anchorAt: Offset(0, 0.93),
        seconds: 0.6,
      ),
    ],
  ),
  'split-squat': Demo(
    anchor: Joint.hip,
    frames: [
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.43, Body.ankleHeight),
        feetFar: Offset(-0.43, 0.13),
        anchorAt: Offset(0, 0.82),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.43, Body.ankleHeight),
        feetFar: Offset(-0.43, 0.13),
        anchorAt: Offset(0, 0.52),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.43, Body.ankleHeight),
        feetFar: Offset(-0.43, 0.13),
        anchorAt: Offset(0, 0.82),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'smith-machine-lunge': Demo(
    anchor: Joint.hip,
    gear: [
      Line(Offset(-0.07, 0), Offset(-0.07, 2.15), width: 0.035),
      Plate(at: Joint.upperBack),
    ],
    elbowToward: Offset(-0.5, -1),
    frames: [
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.43, Body.ankleHeight),
        feetFar: Offset(-0.43, 0.13),
        anchorAt: Offset(0, 0.82),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.43, Body.ankleHeight),
        feetFar: Offset(-0.43, 0.13),
        anchorAt: Offset(0, 0.52),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        foot: 90,
        footFar: 135,
        feet: Offset(0.43, Body.ankleHeight),
        feetFar: Offset(-0.43, 0.13),
        anchorAt: Offset(0, 0.82),
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
};

/* ----------------------------------------------------- horizontal push -- */

// Lying on a flat bench (as the bench press).
const _flatHip = Offset(0.25, 0.53);
const _flatFeet = Offset(0.8, Body.ankleHeight);
const _flatBench = Bench(from: -0.7, to: 0.4);

// A 30-degree incline: seated, the back at -60; the shoulders at
// (-0.33, 0.75).
const _inclineHip = Offset(0.1, 0.5);
const _inclineFeet = Offset(0.62, Body.ankleHeight);
const _inclineBench = Bench(
  from: -0.12,
  to: 0.25,
  height: 0.42,
  backAngle: -60,
  backAt: -0.06,
  backLength: 0.85,
);

// A decline: head down, legs hooked over the end; the shoulders at
// (-0.23, 0.47).
const _declineHip = Offset(0.25, 0.6);
const _declineFeet = Offset(0.56, 0.32);
const _declineBench = [
  Line(Offset(-0.62, 0.24), Offset(0.4, 0.51), width: 0.07),
  Line(Offset(0.3, 0.48), Offset(0.3, 0), width: 0.04),
  Line(Offset(-0.5, 0.27), Offset(-0.5, 0), width: 0.04),
  Line(Offset(0.42, 0.5), Offset(0.62, 0.3), width: 0.04),
  Pad(Joint.ankle, from: Joint.knee, side: -0.06),
];

const Map<String, Demo> _horizontalPush = {
  'incline-barbell-bench-press': Demo(
    anchor: Joint.hip,
    anchorAt: _inclineHip,
    kneeToward: Offset(0, 1),
    gear: [_inclineBench, Plate()],
    frames: [
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.31, 1.3),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.2, 0.87),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.31, 1.3),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'decline-barbell-bench-press': Demo(
    // Beta 5.6 (owner: "the bar is not going to the top"): it locks out
    // over the shoulders, arms straight.
    anchor: Joint.hip,
    anchorAt: _declineHip,
    kneeToward: Offset(0, 1),
    gear: [..._declineBench, Plate()],
    frames: [
      Pose(
        trunk: -105,
        feet: _declineFeet,
        foot: 45,
        hands: Offset(-0.21, 1.035),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -105,
        feet: _declineFeet,
        foot: 45,
        hands: Offset(-0.1, 0.68),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: -105,
        feet: _declineFeet,
        foot: 45,
        hands: Offset(-0.21, 1.035),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'incline-dumbbell-bench-press': Demo(
    anchor: Joint.hip,
    anchorAt: _inclineHip,
    kneeToward: Offset(0, 1),
    gear: [_inclineBench, Dumbbells()],
    frames: [
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.24, 0.88),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.31, 1.3),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.24, 0.9),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'floor-press': Demo(
    // Beta 5.6 (owner: "show the top view with the angle written between
    // the chest and the arm"): seen from above, lying on the floor. The
    // upper arms rest at 45° from the body; the forearms point up at you
    // (short), then the dumbbells press straight up over the chest.
    view: DemoView.front,
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.94),
    floor: false,
    gear: [
      Dumbbells(across: true),
      AngleMark(at: Joint.shoulder, from: 180, to: Joint.elbow, label: '45°'),
    ],
    frames: [
      Pose(
        arm: Limb(135, 135),
        upperScale: 0.12,
        foreScale: 0.12,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        arm: Limb(135, 135),
        foreScale: 0.15,
        cue: 1,
        seconds: 2,
        hold: 0.5,
      ),
      Pose(
        arm: Limb(135, 135),
        upperScale: 0.12,
        foreScale: 0.12,
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'incline-push-up': Demo(
    // Beta 5.6 (owner: "arms straight at the top").
    anchor: Joint.toe,
    anchorAt: Offset(0, 0.01),
    elbowToward: Offset(-1, 0.6),
    gear: [Bench(from: 0.95, to: 1.45, height: 0.45)],
    frames: [
      Pose(
        trunk: 52,
        leg: Limb(232, 232),
        foot: 150,
        hands: Offset(1.12, 0.45),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 61,
        leg: Limb(241, 241),
        foot: 150,
        hands: Offset(1.12, 0.45),
        cue: 1,
        seconds: 1.8,
        hold: 0.2,
      ),
      Pose(
        trunk: 52,
        leg: Limb(232, 232),
        foot: 150,
        hands: Offset(1.12, 0.45),
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'decline-push-up': Demo(
    // Beta 5.6 (owner: "hand should not be ahead of the head"): the hands
    // under the shoulders.
    anchor: Joint.toe,
    anchorAt: Offset(0, 0.61),
    elbowToward: Offset(-1, 0.6),
    gear: [Bench(from: -0.35, to: 0.1, height: 0.6)],
    frames: [
      Pose(
        trunk: 98,
        leg: Limb(278, 278),
        foot: 180,
        hands: Offset(1.3, 0.03),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 108,
        leg: Limb(288, 288),
        foot: 180,
        hands: Offset(1.3, 0.03),
        cue: 1,
        seconds: 1.8,
        hold: 0.2,
      ),
      Pose(
        trunk: 98,
        leg: Limb(278, 278),
        foot: 180,
        hands: Offset(1.3, 0.03),
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'diamond-push-up': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0, 0.01),
    elbowToward: Offset(-1, 0.2),
    frames: [
      Pose(
        trunk: 74,
        leg: Limb(254, 254),
        foot: 165,
        hands: Offset(1.2, 0.03),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 84,
        leg: Limb(264, 264),
        foot: 165,
        hands: Offset(1.2, 0.03),
        cue: 1,
        seconds: 1.6,
        hold: 0.2,
      ),
      Pose(
        trunk: 74,
        leg: Limb(254, 254),
        foot: 165,
        hands: Offset(1.2, 0.03),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'machine-chest-press': Demo(
    // Beta 5.6 (owner: "machine rod not showing"): the handles on lever
    // arms hung from the top of the machine.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    elbowToward: Offset(-1, -0.3),
    gear: [
      Bench(
        from: -0.25,
        to: 0.2,
        height: 0.45,
        backAngle: -8,
        backAt: -0.22,
        backLength: 0.8,
      ),
      Line(Offset(-0.42, 0), Offset(-0.42, 1.86), width: 0.06),
      Line(Offset(-0.42, 1.86), Offset(0.32, 1.86), width: 0.06),
      Lever(Offset(0.29, 1.78)),
    ],
    frames: [
      Pose(
        trunk: -8,
        leg: Limb(92, 180),
        hands: Offset(0.14, 0.95),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -8,
        leg: Limb(92, 180),
        hands: Offset(0.48, 0.96),
        cue: 1,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -8,
        leg: Limb(92, 180),
        hands: Offset(0.14, 0.95),
        cue: 2,
        seconds: 2.2,
      ),
    ],
  ),
  'smith-machine-bench-press': Demo(
    // Beta 5.6 (owner: "arms not straight at the top").
    anchor: Joint.hip,
    anchorAt: _flatHip,
    kneeToward: Offset(0, 1),
    gear: [
      _flatBench,
      Line(Offset(-0.1, 0), Offset(-0.1, 1.6), width: 0.035),
      Plate(),
    ],
    frames: [
      Pose(
        trunk: -90,
        feet: _flatFeet,
        hands: Offset(-0.1, 1.074),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        hands: Offset(-0.1, 0.7),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        hands: Offset(-0.1, 1.074),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'close-grip-bench-press': Demo(
    anchor: Joint.hip,
    anchorAt: _flatHip,
    kneeToward: Offset(0, 1),
    elbowToward: Offset(1, -1),
    gear: [_flatBench, Plate()],
    frames: [
      Pose(
        trunk: -90,
        feet: _flatFeet,
        hands: Offset(-0.25, 1.1),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        hands: Offset(-0.02, 0.7),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        hands: Offset(-0.25, 1.1),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'band-chest-press': Demo(
    elbowToward: Offset(-1, -0.3),
    gear: [
      Line(Offset(-0.62, 0), Offset(-0.62, 1.5), width: 0.05),
      Link(from: Offset(-0.6, 1.25), band: true),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: 5,
        legFar: Limb(195, 195),
        hands: Offset(0.16, 1.23),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 5,
        legFar: Limb(195, 195),
        hands: Offset(0.58, 1.27),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 5,
        legFar: Limb(195, 195),
        hands: Offset(0.16, 1.23),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'chest-dip': Demo(
    anchor: Joint.hand,
    anchorAt: Offset(0, 1.25),
    gear: [
      Line(Offset(-0.3, 1.25), Offset(-0.3, 0), width: 0.04),
      Line(Offset(0.3, 1.25), Offset(0.3, 0), width: 0.04),
      Line(Offset(-0.36, 1.25), Offset(0.36, 1.25), width: 0.045),
    ],
    frames: [
      Pose(
        trunk: 10,
        arm: Limb(182, 182),
        leg: Limb(190, 250),
        cue: 0,
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 32,
        arm: Limb(-75, 178),
        leg: Limb(200, 255),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 10,
        arm: Limb(182, 182),
        leg: Limb(190, 250),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'smith-machine-incline-press': Demo(
    // Beta 5.6 (owner: "arms not straight at the top").
    anchor: Joint.hip,
    anchorAt: _inclineHip,
    kneeToward: Offset(0, 1),
    gear: [
      _inclineBench,
      Line(Offset(-0.22, 0), Offset(-0.22, 1.75), width: 0.035),
      Plate(),
    ],
    frames: [
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.22, 1.303),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.22, 0.88),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: -60,
        feet: _inclineFeet,
        hands: Offset(-0.22, 1.303),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'decline-dumbbell-bench-press': Demo(
    // Beta 5.6 (owner: "the dumbbell is not going to the full top").
    anchor: Joint.hip,
    anchorAt: _declineHip,
    kneeToward: Offset(0, 1),
    gear: [..._declineBench, Dumbbells()],
    frames: [
      Pose(
        trunk: -105,
        feet: _declineFeet,
        foot: 45,
        hands: Offset(-0.2, 1.035),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -105,
        feet: _declineFeet,
        foot: 45,
        hands: Offset(-0.12, 0.66),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: -105,
        feet: _declineFeet,
        foot: 45,
        hands: Offset(-0.2, 1.035),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
};

/* ------------------------------------------------------- vertical push -- */

const Map<String, Demo> _verticalPush = {
  'standing-dumbbell-shoulder-press': Demo(
    gear: [Dumbbells()],
    frames: [
      Pose(hands: Offset(0.07, 1.5), cue: 0, seconds: 0.4, hold: 0.3),
      Pose(hands: Offset(0.01, 2.0), cue: 1, seconds: 1, hold: 0.3),
      Pose(hands: Offset(0.07, 1.52), cue: 2, seconds: 1.6),
    ],
  ),
  'arnold-press': Demo(
    // Beta 5.6.1 (owner: "dumbbell should also rotate"): the dumbbells turn
    // with the hands — across with the palms toward you, end-on halfway as
    // the elbows swing out, across again with the palms forward overhead.
    view: DemoView.front,
    seated: true,
    gear: [
      Bench(from: -0.26, to: 0.26, height: 0.47),
      Dumbbells(across: true),
    ],
    frames: [
      Pose(
        arm: Limb(200, 0),
        upperScale: 0.45,
        cue: 0,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(arm: Limb(100, 2), turn: 90, seconds: 0.8),
      Pose(arm: Limb(12, 6), turn: 180, cue: 1, seconds: 0.8, hold: 0.4),
      Pose(arm: Limb(100, 2), turn: 90, cue: 2, seconds: 1.2),
    ],
  ),
  'machine-shoulder-press': Demo(
    // Beta 5.6.1 (owner: "design the machine better"): a whole machine —
    // the weight stack behind, its frame up to the levers' pivot, the seat
    // and back pads; the handles on lever arms swing up from behind.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [
      WeightStack(-0.8, height: 1.82),
      Line(Offset(-0.95, 0.025), Offset(0.4, 0.025), width: 0.05),
      Line(Offset(0, 0.02), Offset(0, 0.44), width: 0.05),
      Line(Offset(-0.54, 0.02), Offset(-0.54, 1.82), width: 0.05),
      Line(Offset(-0.8, 1.82), Offset(-0.54, 1.82), width: 0.05),
      Line(Offset(-0.24, 0.475), Offset(0.22, 0.475), width: 0.08, pad: true),
      Line(Offset(-0.134, 0.57), Offset(-0.196, 1.27), width: 0.09, pad: true),
      Lever(Offset(-0.54, 1.3)),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0.05, 1.12),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0, 1.59),
        cue: 1,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0.05, 1.12),
        cue: 2,
        seconds: 2.2,
      ),
    ],
  ),
  'push-press': Demo(
    gear: [Plate(radius: 0.2)],
    elbowToward: Offset(1, -1),
    frames: [
      Pose(
        head: -10,
        hands: Offset(0.16, -0.04),
        handsFrom: Joint.shoulder,
        cue: 0,
        seconds: 0.6,
        hold: 0.4,
      ),
      Pose(
        head: -10,
        leg: Limb(160, 202),
        hands: Offset(0.16, -0.04),
        handsFrom: Joint.shoulder,
        cue: 1,
        seconds: 0.4,
      ),
      Pose(
        trunk: -3,
        head: -28,
        hands: Offset(0.17, 0.18),
        handsFrom: Joint.shoulder,
        seconds: 0.25,
      ),
      // Beta 5.6 (owner): the arms lock out straight at the top.
      Pose(
        hands: Offset(0.03, 0.565),
        handsFrom: Joint.shoulder,
        cue: 2,
        seconds: 0.35,
        hold: 0.5,
      ),
      Pose(
        trunk: -3,
        head: -28,
        hands: Offset(0.17, 0.18),
        handsFrom: Joint.shoulder,
        seconds: 0.9,
      ),
    ],
  ),
  'pike-push-up': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0, 0.01),
    elbowToward: Offset(-1, 0),
    frames: [
      Pose(
        trunk: 130,
        leg: Limb(208, 208),
        foot: 150,
        hands: Offset(0.82, 0.06),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 150,
        leg: Limb(225, 225),
        foot: 150,
        hands: Offset(0.82, 0.06),
        cue: 1,
        seconds: 1.6,
        hold: 0.2,
      ),
      Pose(
        trunk: 130,
        leg: Limb(208, 208),
        foot: 150,
        hands: Offset(0.82, 0.06),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'handstand-push-up': Demo(
    anchor: Joint.hand,
    anchorAt: Offset(0, 0.03),
    gear: [Line(Offset(0.24, 0), Offset(0.24, 2.2), width: 0.05)],
    frames: [
      // Beta 5.6 (owner: "feet wrong side"): the heels on the wall, the
      // toes pointing up and away from it.
      Pose(
        trunk: 180,
        arm: Limb(180, 180),
        leg: Limb(8, 8),
        foot: -20,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 180,
        arm: Limb(-75, 180),
        leg: Limb(8, 8),
        foot: -20,
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 180,
        arm: Limb(180, 180),
        leg: Limb(8, 8),
        foot: -20,
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'landmine-press': Demo(
    elbowToward: Offset(1, -1),
    // Beta 5.6 (owner: "add plates to the rod"): the loaded sleeve just
    // past the hands.
    gear: [Link(from: Offset(1.75, 0.05), band: true, plate: 0.16)],
    frames: [
      Pose(
        trunk: 8,
        legFar: Limb(195, 195),
        hands: Offset(0.14, 1.4),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 8,
        legFar: Limb(195, 195),
        hands: Offset(0.46, 1.83),
        cue: 1,
        seconds: 1.1,
        hold: 0.3,
      ),
      Pose(
        trunk: 8,
        legFar: Limb(195, 195),
        hands: Offset(0.14, 1.4),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'kettlebell-press': Demo(
    gear: [Kettlebell(nearOnly: true)],
    frames: [
      Pose(
        arm: Limb(165, 5),
        armFar: Limb(180, 180),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        arm: Limb(2, 2),
        armFar: Limb(180, 180),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(arm: Limb(165, 5), armFar: Limb(180, 180), cue: 2, seconds: 1.4),
    ],
  ),
  'band-shoulder-press': Demo(
    gear: [Link(fromJoint: Joint.toe, band: true), Handles()],
    frames: [
      Pose(hands: Offset(0.07, 1.5), cue: 0, seconds: 0.4, hold: 0.3),
      Pose(hands: Offset(0.01, 2.0), cue: 1, seconds: 1, hold: 0.3),
      Pose(hands: Offset(0.07, 1.52), cue: 2, seconds: 1.6),
    ],
  ),
};

/* ----------------------------------------------------- horizontal pull -- */

const Map<String, Demo> _horizontalPull = {
  'pendlay-row': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(-0.42, 0.7),
    elbowToward: Offset(-1, 0.3),
    gear: [Plate()],
    frames: [
      Pose(
        trunk: 82,
        feet: _ankle,
        hands: Offset(0.07, 0.225),
        cue: 0,
        seconds: 0.7,
        hold: 0.4,
      ),
      Pose(
        trunk: 82,
        feet: _ankle,
        hands: Offset(-0.06, 0.6),
        cue: 1,
        seconds: 0.45,
        hold: 0.2,
      ),
      Pose(
        trunk: 82,
        feet: _ankle,
        hands: Offset(0.07, 0.225),
        cue: 2,
        seconds: 0.7,
      ),
    ],
  ),
  'chest-supported-dumbbell-row': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(-0.25, 0.85),
    gear: [
      Line(Offset(-0.17, 0.71), Offset(0.22, 1.04), width: 0.07),
      Line(Offset(0.0, 0.85), Offset(0.0, 0), width: 0.04),
      Dumbbells(),
    ],
    frames: [
      Pose(
        trunk: 50,
        feet: Offset(-0.62, 0.12),
        foot: 135,
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 50,
        feet: Offset(-0.62, 0.12),
        foot: 135,
        arm: Limb(-100, 180),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 50,
        feet: Offset(-0.62, 0.12),
        foot: 135,
        arm: Limb(178, 178),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'machine-row': Demo(
    // Beta 5.6.1 (owner: "use machine which is connected to bottom and
    // elbow should go back"): the handles on levers rising from a pivot at
    // the foot of the machine; the pull swings them down and back to the
    // waist, the elbows driving well behind the body.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    elbowToward: Offset(-1, -0.5),
    gear: [
      WeightStack(1.02, height: 1.3),
      Line(Offset(-0.3, 0.025), Offset(1.17, 0.025), width: 0.05),
      Line(Offset(0, 0.02), Offset(0, 0.44), width: 0.05),
      Line(Offset(0.33, 0.02), Offset(0.16, 0.9), width: 0.045),
      Line(Offset(0.75, 0.02), Offset(0.75, 0.15), width: 0.07),
      Line(Offset(-0.24, 0.475), Offset(0.22, 0.475), width: 0.08, pad: true),
      Line(Offset(0.155, 0.86), Offset(0.155, 1.18), width: 0.09, pad: true),
      Lever(Offset(0.75, 0.15)),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: 2,
        leg: Limb(92, 180),
        hands: Offset(0.5, 1.07),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        leg: Limb(92, 180),
        hands: Offset(0.1, 0.843),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 2,
        leg: Limb(92, 180),
        hands: Offset(0.5, 1.07),
        cue: 2,
        seconds: 2.2,
      ),
    ],
  ),
  't-bar-row': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(-0.28, 0.82),
    elbowToward: Offset(-1, 0.3),
    gear: [Link(from: Offset(-1.3, 0.05), band: true), Plate(radius: 0.2)],
    frames: [
      Pose(
        trunk: 48,
        feet: _ankle,
        hands: Offset(0.1, 0.58),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 48,
        feet: _ankle,
        hands: Offset(0.04, 0.86),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 48,
        feet: _ankle,
        hands: Offset(0.1, 0.58),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'inverted-row': Demo(
    anchorAt: Offset(1.2, Body.ankleHeight),
    elbowToward: Offset(0.3, -1),
    gear: [
      Line(Offset(0.4, 0), Offset(0.4, 1.1), width: 0.04),
      Line(Offset(0.28, 1.03), Offset(0.42, 1.03), width: 0.05),
    ],
    frames: [
      Pose(
        trunk: -65,
        leg: Limb(115, 115),
        foot: 25,
        hands: Offset(0.34, 1.03),
        cue: 0,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -52,
        leg: Limb(128, 128),
        foot: 38,
        hands: Offset(0.34, 1.03),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -65,
        leg: Limb(115, 115),
        foot: 25,
        hands: Offset(0.34, 1.03),
        cue: 2,
        seconds: 1.8,
      ),
    ],
  ),
  'band-row': Demo(
    elbowToward: Offset(-1, 0),
    gear: [
      Line(Offset(1.22, 0), Offset(1.22, 1.4), width: 0.05),
      Link(from: Offset(1.2, 1.2), band: true),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: 3,
        leg: Limb(175, 185),
        hands: Offset(0.5, 1.2),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: -2,
        leg: Limb(175, 185),
        hands: Offset(0.06, 1.05),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 3,
        leg: Limb(175, 185),
        hands: Offset(0.5, 1.2),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'kettlebell-row': Demo(
    anchor: Joint.kneeFar,
    anchorAt: Offset(0.1, 0.47),
    gear: [Bench(from: -0.4, to: 0.7), Kettlebell(nearOnly: true)],
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
        arm: Limb(-80, 175),
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
  'face-pull': Demo(
    // Beta 5.6 (owner: "too fast, make it slow with a controlled rep").
    elbowToward: Offset(-0.6, 1),
    gear: [Cable(Offset(1.05, 1.62), handle: true)],
    frames: [
      Pose(
        trunk: 3,
        legFar: Limb(190, 190),
        hands: Offset(0.5, 1.56),
        cue: 0,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 0,
        legFar: Limb(190, 190),
        hands: Offset(0.12, 1.62),
        cue: 1,
        seconds: 1.1,
        hold: 0.2,
      ),
      Pose(
        trunk: 0,
        legFar: Limb(190, 190),
        hands: Offset(0.08, 1.64),
        cue: 2,
        seconds: 0.3,
        hold: 0.5,
      ),
    ],
  ),
  'band-face-pull': Demo(
    // Beta 5.6 (owner: "too fast on the release"): a slow, controlled
    // return.
    elbowToward: Offset(-0.6, 1),
    gear: [
      Line(Offset(1.07, 0), Offset(1.07, 1.8), width: 0.05),
      Link(from: Offset(1.05, 1.62), band: true),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: 3,
        legFar: Limb(190, 190),
        hands: Offset(0.5, 1.56),
        cue: 0,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 0,
        legFar: Limb(190, 190),
        hands: Offset(0.12, 1.62),
        cue: 1,
        seconds: 1.1,
        hold: 0.2,
      ),
      Pose(
        trunk: 0,
        legFar: Limb(190, 190),
        hands: Offset(0.08, 1.64),
        cue: 2,
        seconds: 0.3,
        hold: 0.5,
      ),
    ],
  ),
  'landmine-row': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(-0.28, 0.82),
    elbowToward: Offset(-1, 0.3),
    gear: [Link(from: Offset(-1.3, 0.05), band: true), Plate(radius: 0.2)],
    frames: [
      Pose(
        trunk: 50,
        feet: _ankle,
        hands: Offset(0.12, 0.6),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 50,
        feet: _ankle,
        hands: Offset(0.04, 0.87),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 50,
        feet: _ankle,
        hands: Offset(0.12, 0.6),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
};

/* ------------------------------------------------------- vertical pull -- */

const Map<String, Demo> _verticalPull = {
  'band-lat-pulldown': Demo(
    // Beta 5.6.1 (owner: "do it in one movement"): one smooth pull from
    // overhead to the shoulders, no stop halfway; the elbows sweep down to
    // the sides with the forearms upright.
    anchor: Joint.knee,
    anchorAt: Offset(0, 0.06),
    gear: [
      Line(Offset(0.47, 0), Offset(0.47, 2.3), width: 0.05),
      Link(from: Offset(0.45, 2.2), band: true),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: -3,
        leg: Limb(180, -90),
        foot: -100,
        arm: Limb(18, 18),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: -10,
        leg: Limb(180, -90),
        foot: -100,
        arm: Limb(195, 16),
        upperScale: 0.85,
        cue: 1,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -3,
        leg: Limb(180, -90),
        foot: -100,
        arm: Limb(18, 18),
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
  'straight-arm-pulldown': Demo(
    gear: [Cable(Offset(0.95, 2.15), handle: true)],
    frames: [
      Pose(
        trunk: 18,
        leg: Limb(172, 188),
        arm: Limb(40, 45),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 18,
        leg: Limb(172, 188),
        arm: Limb(165, 160),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: 18,
        leg: Limb(172, 188),
        arm: Limb(40, 45),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  'dumbbell-pullover': Demo(
    // Beta 5.6.1 (owner: "the movement should be from head level to behind
    // the head"): the dumbbell starts over the face, not the chest, and
    // goes back behind the head until the arms are in line with the body.
    anchor: Joint.hip,
    anchorAt: _flatHip,
    kneeToward: Offset(0, 1),
    gear: [_flatBench, Dumbbells(single: true)],
    frames: [
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-22, -16),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        head: -10,
        feet: _flatFeet,
        arm: Limb(-92, -88),
        cue: 1,
        seconds: 2.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-22, -16),
        cue: 2,
        seconds: 1.4,
        hold: 0.3,
      ),
    ],
  ),
};

/* ---------------------------------------------------------------- arms -- */

// A preacher or machine pad under the upper arms, seated (shoulders at
// (0.04, 1.0)).
const _preacherPad = [
  Bench(from: -0.25, to: 0.25, height: 0.47),
  Line(Offset(0.07, 0.9), Offset(0.36, 0.66), width: 0.06),
  Line(Offset(0.28, 0.7), Offset(0.28, 0), width: 0.04),
];

/// Beta 5.6.1 (owner: "design the machine better"): a preacher machine —
/// the seat and arm pads on their posts, the weight stack in front, and a
/// bracket up to the cam beside the elbow.
const _preacherMachine = [
  WeightStack(0.95, height: 1.5),
  Line(Offset(-0.3, 0.025), Offset(1.1, 0.025), width: 0.05),
  Line(Offset(0, 0.02), Offset(0, 0.44), width: 0.05),
  Line(Offset(0.3, 0.02), Offset(0.3, 0.7), width: 0.05),
  Line(Offset(0.3, 0.7), _preacherCam, width: 0.04),
  Line(Offset(0.83, 1.5), Offset(0.6, 1.5), width: 0.05),
  Line(Offset(-0.24, 0.475), Offset(0.22, 0.475), width: 0.08, pad: true),
  Line(Offset(0.05, 0.92), Offset(0.37, 0.65), width: 0.09, pad: true),
];

/// The preacher machine's cam, beside the elbow.
const _preacherCam = Offset(0.273, 0.835);

const Map<String, Demo> _arms = {
  'barbell-curl': Demo(
    // Beta 5.6 (owner: "slower and controlled"): a steady curl and a
    // lowering twice as long.
    gear: [Plate(radius: 0.13)],
    frames: [
      Pose(arm: Limb(178, 178), cue: 0, seconds: 1.3, hold: 0.3),
      Pose(arm: Limb(175, 15), cue: 1, seconds: 1.2, hold: 0.4),
      Pose(arm: Limb(177, 100), cue: 2, seconds: 1.3),
    ],
  ),
  'incline-dumbbell-curl': Demo(
    anchor: Joint.hip,
    anchorAt: _inclineHip,
    kneeToward: Offset(0, 1),
    gear: [
      Bench(
        from: -0.12,
        to: 0.25,
        height: 0.42,
        backAngle: -45,
        backAt: -0.08,
        backLength: 0.85,
      ),
      Dumbbells(),
    ],
    frames: [
      Pose(
        trunk: -45,
        head: 20,
        feet: _inclineFeet,
        arm: Limb(180, 180),
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: -45,
        head: 20,
        feet: _inclineFeet,
        arm: Limb(178, 25),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -45,
        head: 20,
        feet: _inclineFeet,
        arm: Limb(180, 120),
        cue: 2,
        seconds: 0.8,
      ),
    ],
  ),
  'machine-preacher-curl': Demo(
    // Beta 5.6.1 (owner: "completely wrong redraw"): the arm pad on its
    // post, the upper arm lying on it; the machine's arm turns on a cam
    // beside the elbow and runs alongside the forearm (below it, then in
    // front) to the handle. The lowering takes twice as long as the curl.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [
      ..._preacherMachine,
      Lever(_preacherCam, side: -0.1, over: true),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 122),
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 10),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 65),
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'cable-curl': Demo(
    gear: [Cable(Offset(0.38, 0.12), handle: true)],
    frames: [
      Pose(trunk: 3, arm: Limb(178, 178), cue: 0, seconds: 0.8, hold: 0.2),
      Pose(trunk: 3, arm: Limb(175, 15), cue: 1, seconds: 1, hold: 0.3),
      Pose(trunk: 3, arm: Limb(177, 100), cue: 2, seconds: 0.9),
    ],
  ),
  'concentration-curl': Demo(
    // Beta 5.6.1 (owner: "still on down position hand going too much down
    // and weird angle"): the elbow stays braced on the inside of the
    // thigh; at the bottom the forearm points down and forward, the arm
    // not locked, the dumbbell in front of the knee.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [
      Bench(from: -0.25, to: 0.25, height: 0.47),
      Dumbbells(nearOnly: true),
    ],
    frames: [
      Pose(
        trunk: 40,
        leg: Limb(92, 180),
        arm: Limb(168, 140),
        armFar: Limb(150, 150),
        cue: 0,
        seconds: 1.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 40,
        leg: Limb(92, 180),
        arm: Limb(168, 40),
        armFar: Limb(150, 150),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 40,
        leg: Limb(92, 180),
        arm: Limb(168, 95),
        armFar: Limb(150, 150),
        cue: 2,
        seconds: 1.3,
      ),
    ],
  ),
  'band-curl': Demo(
    gear: [Link(fromJoint: Joint.toe, band: true), Handles()],
    frames: [
      Pose(arm: Limb(178, 178), cue: 0, seconds: 0.8, hold: 0.2),
      Pose(arm: Limb(175, 15), cue: 1, seconds: 1, hold: 0.3),
      Pose(arm: Limb(177, 100), cue: 2, seconds: 0.9),
    ],
  ),
  'barbell-preacher-curl': Demo(
    // Beta 5.6 (owner: "slower and controlled").
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [..._preacherPad, Plate(radius: 0.13)],
    frames: [
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 125),
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 5),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 65),
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'reverse-curl': Demo(
    gear: [Plate(radius: 0.13)],
    frames: [
      Pose(arm: Limb(178, 178), cue: 0, seconds: 0.8, hold: 0.2),
      Pose(arm: Limb(175, 25), cue: 1, seconds: 1, hold: 0.3),
      Pose(arm: Limb(177, 100), cue: 2, seconds: 1.1),
    ],
  ),
  'cable-hammer-curl': Demo(
    // Beta 5.6 (owner: "why dumbbells if it is cable"): a rope's two ends
    // on the low pulley's cable.
    view: DemoView.front,
    gear: [
      Cable(Offset(0.03, 0.15), handle: true),
      Link(from: Offset(0.03, 0.15), toJoint: Joint.handFar),
      Handles(),
    ],
    frames: [
      Pose(arm: Limb(184, 184), cue: 0, seconds: 1.2, hold: 0.3),
      Pose(
        arm: Limb(184, 184),
        foreScale: -0.55,
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(arm: Limb(184, 184), foreScale: 0.3, cue: 2, seconds: 1.3),
    ],
  ),
  'cable-overhead-triceps-extension': Demo(
    gear: [Cable(Offset(-0.55, 0.15), handle: true)],
    frames: [
      Pose(
        trunk: 15,
        legFar: Limb(198, 198),
        arm: Limb(22, 24),
        cue: 0,
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 15,
        legFar: Limb(198, 198),
        arm: Limb(25, 240),
        cue: 1,
        seconds: 1.6,
        hold: 0.2,
      ),
      Pose(
        trunk: 15,
        legFar: Limb(198, 198),
        arm: Limb(22, 24),
        cue: 2,
        seconds: 1,
        hold: 0.3,
      ),
    ],
  ),
  'skull-crusher': Demo(
    anchor: Joint.hip,
    anchorAt: _flatHip,
    kneeToward: Offset(0, 1),
    gear: [_flatBench, Plate(radius: 0.13)],
    frames: [
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-5, -5),
        cue: 0,
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-10, -130),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(trunk: -90, feet: _flatFeet, arm: Limb(-5, -5), cue: 2, seconds: 1),
    ],
  ),
  'dumbbell-skull-crusher': Demo(
    // Beta 5.6 (owner: "wrong angle, full range of motion not there"): the
    // upper arms lean back toward the head, and the dumbbells come down
    // beside it.
    anchor: Joint.hip,
    anchorAt: _flatHip,
    kneeToward: Offset(0, 1),
    gear: [_flatBench, Dumbbells(neutral: true)],
    frames: [
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-15, -15),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-20, -155),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        feet: _flatFeet,
        arm: Limb(-15, -15),
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
    ],
  ),
  'bench-dip': Demo(
    anchor: Joint.hand,
    anchorAt: Offset(-0.12, 0.47),
    kneeToward: Offset(0, 1),
    gear: [Bench(from: -0.6, to: -0.08, height: 0.45)],
    frames: [
      Pose(
        trunk: 2,
        arm: Limb(190, 188),
        foot: 50,
        feet: Offset(0.68, Body.ankleHeight),
        cue: 0,
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 8,
        arm: Limb(-100, 172),
        foot: 50,
        feet: Offset(0.68, Body.ankleHeight),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 2,
        arm: Limb(190, 188),
        foot: 50,
        feet: Offset(0.68, Body.ankleHeight),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
  'triceps-kickback': Demo(
    gear: [Dumbbells(nearOnly: true)],
    frames: [
      Pose(
        trunk: 65,
        leg: Limb(168, 192),
        arm: Limb(-90, 178),
        armFar: Limb(150, 170),
        cue: 0,
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 65,
        leg: Limb(168, 192),
        arm: Limb(-92, -88),
        armFar: Limb(150, 170),
        cue: 1,
        seconds: 0.8,
        hold: 0.4,
      ),
      Pose(
        trunk: 65,
        leg: Limb(168, 192),
        arm: Limb(-90, 178),
        armFar: Limb(150, 170),
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'band-pushdown': Demo(
    gear: [
      Line(Offset(0.36, 0), Offset(0.36, 2.2), width: 0.05),
      Link(from: Offset(0.34, 2.1), band: true),
      Handles(),
    ],
    frames: [
      Pose(trunk: 8, arm: Limb(176, 80), cue: 0, seconds: 0.3, hold: 0.2),
      Pose(trunk: 8, arm: Limb(178, 178), cue: 1, seconds: 1, hold: 0.3),
      Pose(trunk: 8, arm: Limb(176, 75), cue: 2, seconds: 1.6),
    ],
  ),
  'machine-triceps-extension': Demo(
    // Beta 5.6.1 (owner: "design the machine better"): the arm pad on its
    // post with the weight stack in front; the machine's arm turns on a cam
    // beside the elbow and runs alongside the forearm to the handle, which
    // is pushed down and forward; a slow return.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [
      ..._preacherMachine,
      Lever(_preacherCam, side: -0.1, over: true),
      Handles(),
    ],
    frames: [
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 5),
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 128),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 5,
        leg: Limb(92, 180),
        arm: Limb(130, 65),
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
};

/* ----------------------------------------------------------- shoulders -- */

const Map<String, Demo> _shoulders = {
  'cable-lateral-raise': Demo(
    view: DemoView.front,
    gear: [Cable(Offset(-0.55, 0.12), handle: true)],
    frames: [
      Pose(
        arm: Limb(190, 192),
        armFar: Limb(150, 150),
        cue: 0,
        seconds: 0.9,
        hold: 0.2,
      ),
      Pose(
        arm: Limb(92, 100),
        armFar: Limb(150, 150),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(arm: Limb(135, 140), armFar: Limb(150, 150), cue: 2, seconds: 0.9),
    ],
  ),
  'machine-lateral-raise': Demo(
    // Beta 5.6.1 (owner: "completely wrong redraw"): sat against the back
    // pad, elbows bent with the forearms pointing toward you (they look
    // short), hands on the handles; a roller pad presses on the outside of
    // each elbow, on a machine arm turning about the shoulder from the
    // beam behind; the elbows lead up to shoulder height.
    view: DemoView.front,
    seated: true,
    gear: [
      Line(Offset(-0.5, 0.02), Offset(-0.5, 1.12), width: 0.05),
      Line(Offset(0.5, 0.02), Offset(0.5, 1.12), width: 0.05),
      Line(Offset(-0.5, 1.03), Offset(0.5, 1.03), width: 0.05),
      Line(Offset(-0.5, 0.025), Offset(0.5, 0.025), width: 0.05),
      Line(Offset(0, 0.02), Offset(0, 0.46), width: 0.05),
      Line(Offset(0, 0.62), Offset(0, 1.32), width: 0.3, pad: true),
      Line(Offset(-0.24, 0.49), Offset(0.24, 0.49), width: 0.07, pad: true),
      Lever(
        Offset(0.19, 1.03),
        to: Joint.elbow,
        side: 0.1,
        roller: true,
        handle: false,
        mirrored: true,
      ),
      Handles(),
    ],
    frames: [
      Pose(
        arm: Limb(178, 178),
        foreScale: 0.15,
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(arm: Limb(92, 92), foreScale: 0.15, cue: 1, seconds: 1.2, hold: 0.4),
      Pose(arm: Limb(140, 140), foreScale: 0.15, cue: 2, seconds: 1.2),
    ],
  ),
  'reverse-pec-deck': Demo(
    // Beta 5.6.1 (owner: "its not looking reverse"): facing the machine —
    // the chest pad and the levers are in front of the body. The hands
    // start together on the handles in front of the chest and the arms
    // open wide to a T, then come back slowly.
    view: DemoView.front,
    seated: true,
    gear: [
      Line(Offset(-0.6, 0.02), Offset(-0.6, 1.7), width: 0.05),
      Line(Offset(0.6, 0.02), Offset(0.6, 1.7), width: 0.05),
      Line(Offset(-0.6, 1.66), Offset(0.6, 1.66), width: 0.06),
      Line(Offset(-0.19, 1.66), Offset(-0.19, 1.55), width: 0.04),
      Line(Offset(0.19, 1.66), Offset(0.19, 1.55), width: 0.04),
      Line(Offset(-0.6, 0.025), Offset(0.6, 0.025), width: 0.05),
      Line(Offset(-0.24, 0.49), Offset(0.24, 0.49), width: 0.07, pad: true),
      Line(Offset(0, 0.2), Offset(0, 0.62), width: 0.05, over: true),
      Line(Offset(0, 0.64), Offset(0, 0.95), width: 0.26, over: true),
      Lever(Offset(0.19, 1.55), mirrored: true, over: true),
      Handles(),
    ],
    frames: [
      Pose(
        arm: Limb(93, 95),
        upperScale: -0.2,
        foreScale: -0.2,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(arm: Limb(93, 95), cue: 1, seconds: 1.2, hold: 0.4),
      Pose(
        arm: Limb(93, 95),
        upperScale: -0.2,
        foreScale: -0.2,
        cue: 2,
        seconds: 2.2,
      ),
    ],
  ),
  'cable-rear-delt-fly': Demo(
    // Beta 5.6 (owner: "completely wrong"): standing between two pulleys
    // at shoulder height, the cables crossed; the straight arms open from
    // crossed in front out to the sides.
    view: DemoView.front,
    gear: [Cable(Offset(-0.85, 1.43), handle: true, mirrored: true)],
    frames: [
      Pose(
        arm: Limb(92, 94),
        upperScale: -0.55,
        foreScale: -0.55,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(arm: Limb(92, 94), cue: 1, seconds: 1.2, hold: 0.4),
      Pose(
        arm: Limb(92, 94),
        upperScale: -0.55,
        foreScale: -0.55,
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
  'front-raise': Demo(
    gear: [Dumbbells()],
    frames: [
      Pose(arm: Limb(172, 172), cue: 0, seconds: 0.9, hold: 0.2),
      Pose(arm: Limb(90, 92), cue: 1, seconds: 1, hold: 0.3),
      Pose(arm: Limb(130, 132), cue: 2, seconds: 0.9),
    ],
  ),
  'band-pull-apart': Demo(
    // Beta 5.6 (owner: "no band visible"): the band drawn in front of the
    // body, between the hands.
    view: DemoView.front,
    gear: [Link(fromJoint: Joint.handFar, band: true, over: true)],
    frames: [
      Pose(
        arm: Limb(93, 93),
        upperScale: -0.12,
        foreScale: -0.12,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(arm: Limb(93, 93), cue: 1, seconds: 1.2, hold: 0.4),
      Pose(
        arm: Limb(93, 93),
        upperScale: -0.12,
        foreScale: -0.12,
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
  'upright-row': Demo(
    // Beta 5.6.1 (owner: "add longer bar with plates and add wider grip"):
    // a long barbell with a plate at each end; the hands a little wider
    // than the shoulders.
    view: DemoView.front,
    elbowToward: Offset(1, 1),
    gear: [Bar(length: 1.5, plates: true)],
    frames: [
      Pose(hands: Offset(0.28, 0.89), cue: 0, seconds: 1.4, hold: 0.3),
      Pose(hands: Offset(0.28, 1.3), cue: 1, seconds: 1.1, hold: 0.3),
      Pose(hands: Offset(0.28, 0.91), cue: 2, seconds: 1.4),
    ],
  ),
  'cable-y-raise': Demo(
    // Beta 5.6 (owner: "weird hand movement"): the cables cross from the
    // low pulleys; the straight arms sweep out and up into a Y.
    view: DemoView.front,
    gear: [Cable(Offset(-0.75, 0.12), handle: true, mirrored: true)],
    frames: [
      Pose(arm: Limb(207, 210), cue: 0, seconds: 0.5, hold: 0.3),
      Pose(arm: Limb(43, 40), cue: 1, seconds: 1.4, hold: 0.4),
      Pose(arm: Limb(207, 210), cue: 2, seconds: 2),
    ],
  ),
};

/* --------------------------------------------------------------- chest -- */

// A fly lying down, side on: the arms open out to the sides, toward you
// and away, so they look short and the dumbbells drop beside the bench.
const Map<String, Demo> _chest = {
  'dumbbell-fly': Demo(
    // Beta 5.6 (owner: "view it from the top"): seen from above, lying on
    // the bench. The dumbbells start over the chest (the arms pointing up
    // at you look short) and open out wide to the sides, elbows soft.
    view: DemoView.front,
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.94),
    floor: false,
    gear: [
      Line(Offset(0, 0.3), Offset(0, 1.62), width: 0.44),
      Dumbbells(neutral: true),
    ],
    frames: [
      Pose(
        arm: Limb(92, 100),
        upperScale: -0.2,
        foreScale: -0.2,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(arm: Limb(92, 100), cue: 1, seconds: 2.2, hold: 0.3),
      Pose(
        arm: Limb(92, 100),
        upperScale: -0.2,
        foreScale: -0.2,
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'incline-dumbbell-fly': Demo(
    // Beta 5.6 (owner: "show from the top view"): seen from above on the
    // incline bench (the raised back looks shorter); the arms open wide
    // and close over the upper chest.
    view: DemoView.front,
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.94),
    floor: false,
    gear: [
      Line(Offset(0, 0.3), Offset(0, 1.55), width: 0.44),
      Dumbbells(neutral: true),
    ],
    frames: [
      Pose(
        trunk: 30,
        arm: Limb(92, 100),
        upperScale: -0.2,
        foreScale: -0.2,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(trunk: 30, arm: Limb(92, 100), cue: 1, seconds: 2.2, hold: 0.3),
      Pose(
        trunk: 30,
        arm: Limb(92, 100),
        upperScale: -0.2,
        foreScale: -0.2,
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'low-to-high-cable-fly': Demo(
    // Beta 5.6 (owner: "movement not understandable"): the straight arms
    // come up and in on one smooth line, meeting at chin height.
    view: DemoView.front,
    gear: [Cable(Offset(0.85, 0.25), handle: true, mirrored: true)],
    frames: [
      Pose(arm: Limb(128, 124), cue: 0, seconds: 0.5, hold: 0.3),
      Pose(
        arm: Limb(128, 124),
        upperScale: -0.42,
        foreScale: -0.42,
        cue: 1,
        seconds: 1.3,
        hold: 0.4,
      ),
      Pose(arm: Limb(128, 124), cue: 2, seconds: 2),
    ],
  ),
  'high-to-low-cable-fly': Demo(
    // Beta 5.6 (owner: "too fast and clunky"): the straight arms come down
    // and in on one smooth line, seen short as they pass in front.
    view: DemoView.front,
    gear: [Cable(Offset(0.85, 1.95), handle: true, mirrored: true)],
    frames: [
      Pose(arm: Limb(30, 36), cue: 0, seconds: 0.5, hold: 0.3),
      Pose(
        arm: Limb(30, 36),
        upperScale: -0.85,
        foreScale: -0.8,
        cue: 1,
        seconds: 1.3,
        hold: 0.4,
      ),
      Pose(arm: Limb(30, 36), cue: 2, seconds: 2),
    ],
  ),
  'pec-deck': Demo(
    // Beta 5.6.1 (owner: "correct but design the machine bit better"): the
    // frame on its base, the back pad and seat, the pivots hung from the
    // beam; the long arms swing from out to the sides to together in front
    // of the chest (seen end-on in the middle of the swing).
    view: DemoView.front,
    seated: true,
    gear: [
      Line(Offset(-0.6, 0.02), Offset(-0.6, 1.7), width: 0.05),
      Line(Offset(0.6, 0.02), Offset(0.6, 1.7), width: 0.05),
      Line(Offset(-0.6, 1.66), Offset(0.6, 1.66), width: 0.06),
      Line(Offset(-0.19, 1.66), Offset(-0.19, 1.55), width: 0.04),
      Line(Offset(0.19, 1.66), Offset(0.19, 1.55), width: 0.04),
      Line(Offset(-0.6, 0.025), Offset(0.6, 0.025), width: 0.05),
      Line(Offset(0, 0.02), Offset(0, 0.46), width: 0.05),
      Line(Offset(0, 0.62), Offset(0, 1.38), width: 0.3, pad: true),
      Line(Offset(-0.24, 0.49), Offset(0.24, 0.49), width: 0.07, pad: true),
      Lever(Offset(0.19, 1.55), mirrored: true),
      Handles(),
    ],
    frames: [
      Pose(arm: Limb(92, 96), cue: 0, seconds: 0.5, hold: 0.3),
      Pose(
        arm: Limb(92, 96),
        upperScale: -0.27,
        foreScale: -0.27,
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(arm: Limb(92, 96), cue: 2, seconds: 2.2),
    ],
  ),
  'band-fly': Demo(
    view: DemoView.front,
    gear: [Link(from: Offset(0.9, 1.3), band: true, mirrored: true), Handles()],
    frames: [
      Pose(arm: Limb(93, 100), cue: 0, seconds: 0.3, hold: 0.3),
      Pose(
        arm: Limb(93, 100),
        upperScale: -0.28,
        foreScale: -0.32,
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(arm: Limb(93, 100), cue: 2, seconds: 1.8),
    ],
  ),
};

/* ---------------------------------------------------------------- legs -- */

// Kneeling, the shins along the floor behind.
const _kneel = Limb(180, -90);

const Map<String, Demo> _legs = {
  'lying-leg-curl': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.6),
    gear: [
      Bench(from: -0.4, to: 0.75, height: 0.5),
      Pad(Joint.ankle, from: Joint.knee, side: -0.07),
    ],
    frames: [
      // Beta 5.6 (owner: "weird feet movement"): the feet keep square to
      // the shins as they curl.
      Pose(
        trunk: 92,
        leg: Limb(-90, -90),
        foot: 180,
        arm: Limb(150, 180),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 92,
        leg: Limb(-90, 35),
        foot: -55,
        arm: Limb(150, 180),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 92,
        leg: Limb(-90, -90),
        foot: 180,
        arm: Limb(150, 180),
        cue: 2,
        seconds: 2.2,
      ),
    ],
  ),
  'nordic-hamstring-curl': Demo(
    anchor: Joint.knee,
    anchorAt: Offset(0, 0.06),
    gear: [Pad(Joint.ankle, from: Joint.knee, side: -0.07)],
    frames: [
      Pose(
        trunk: 0,
        leg: _kneel,
        foot: -100,
        hands: Offset(0.15, 0.86),
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 55,
        leg: Limb(235, -90),
        foot: -100,
        hands: Offset(0.95, 0.38),
        cue: 1,
        seconds: 2.4,
      ),
      Pose(
        trunk: 78,
        leg: Limb(258, -90),
        foot: -100,
        hands: Offset(1.05, 0.03),
        cue: 2,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 0,
        leg: _kneel,
        foot: -100,
        hands: Offset(0.15, 0.86),
        seconds: 1.2,
      ),
    ],
  ),
  'hip-abduction-machine': Demo(
    // Beta 5.6 (owner: "machine not shown"): the knee pads on levers rising
    // from under the seat.
    view: DemoView.front,
    seated: true,
    seatHeight: 0.62,
    gear: [
      Bench(from: -0.26, to: 0.26, height: 0.56),
      Lever(Offset(0.1, 0.3), to: Joint.knee, mirrored: true, over: true),
    ],
    frames: [
      Pose(
        leg: Limb(178, 180),
        thighScale: 0.25,
        arm: Limb(178, 178),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        leg: Limb(110, 172),
        thighScale: 0.55,
        arm: Limb(178, 178),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        leg: Limb(178, 180),
        thighScale: 0.25,
        arm: Limb(178, 178),
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
  'cable-hip-abduction': Demo(
    view: DemoView.front,
    gear: [
      Line(Offset(-0.62, 0), Offset(-0.62, 1.7), width: 0.06),
      Link(from: Offset(-0.58, 0.12), toJoint: Joint.ankle),
    ],
    frames: [
      Pose(
        legFar: Limb(180, 180),
        armFar: Limb(130, 130),
        cue: 0,
        seconds: 0.8,
        hold: 0.2,
      ),
      Pose(
        leg: Limb(142, 142),
        legFar: Limb(180, 180),
        armFar: Limb(130, 130),
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        legFar: Limb(180, 180),
        armFar: Limb(130, 130),
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'band-lateral-walk': Demo(
    view: DemoView.front,
    anchor: Joint.hip,
    gear: [Link(fromJoint: Joint.knee, toJoint: Joint.kneeFar, band: true)],
    frames: [
      Pose(
        trunk: 15,
        feet: Offset(0.17, Body.ankleHeight),
        feetFar: Offset(-0.17, Body.ankleHeight),
        anchorAt: Offset(0, 0.84),
        cue: 0,
        seconds: 0.6,
        hold: 0.3,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.36, 0.16),
        feetFar: Offset(-0.17, Body.ankleHeight),
        anchorAt: Offset(0.06, 0.84),
        seconds: 0.4,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.47, Body.ankleHeight),
        feetFar: Offset(-0.17, Body.ankleHeight),
        anchorAt: Offset(0.12, 0.84),
        cue: 1,
        seconds: 0.4,
        hold: 0.1,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.47, Body.ankleHeight),
        feetFar: Offset(0.05, 0.16),
        anchorAt: Offset(0.22, 0.84),
        seconds: 0.4,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.47, Body.ankleHeight),
        feetFar: Offset(0.13, Body.ankleHeight),
        anchorAt: Offset(0.3, 0.84),
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.47, Body.ankleHeight),
        feetFar: Offset(-0.06, 0.16),
        anchorAt: Offset(0.24, 0.84),
        cue: 2,
        seconds: 0.4,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.47, Body.ankleHeight),
        feetFar: Offset(-0.17, Body.ankleHeight),
        anchorAt: Offset(0.18, 0.84),
        seconds: 0.4,
        hold: 0.1,
      ),
      Pose(
        trunk: 15,
        feet: Offset(0.28, 0.16),
        feetFar: Offset(-0.17, Body.ankleHeight),
        anchorAt: Offset(0.08, 0.84),
        seconds: 0.4,
      ),
    ],
  ),
  'cable-kickback': Demo(
    anchor: Joint.ankleFar,
    gear: [
      Line(Offset(0.72, 0), Offset(0.72, 1.6), width: 0.06),
      Link(from: Offset(0.68, 0.12), toJoint: Joint.ankle),
    ],
    frames: [
      Pose(
        trunk: 25,
        leg: Limb(178, 182),
        legFar: Limb(180, 180),
        hands: Offset(0.66, 1.15),
        cue: 0,
        seconds: 0.8,
        hold: 0.2,
      ),
      Pose(
        trunk: 25,
        leg: Limb(212, 200),
        legFar: Limb(180, 180),
        foot: 150,
        footFar: 105,
        hands: Offset(0.66, 1.15),
        cue: 1,
        seconds: 0.9,
        hold: 0.4,
      ),
      Pose(
        trunk: 25,
        leg: Limb(178, 182),
        legFar: Limb(180, 180),
        hands: Offset(0.66, 1.15),
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'sissy-squat': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0.17, 0.01),
    gear: [Line(Offset(0.52, 0), Offset(0.52, 1.35), width: 0.04)],
    frames: [
      Pose(
        trunk: 0,
        leg: Limb(178, 182),
        foot: 150,
        hands: Offset(0.5, 1.22),
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: -30,
        leg: Limb(150, -95),
        foot: 150,
        hands: Offset(0.5, 1.05),
        cue: 1,
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        trunk: 0,
        leg: Limb(178, 182),
        foot: 150,
        hands: Offset(0.5, 1.22),
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'glute-kickback-machine': Demo(
    // Beta 5.6 (owner: "show wire too and leg should be straight"): the
    // straight working leg pushes back against the cable from the low
    // pulley.
    anchor: Joint.ankleFar,
    gear: [
      Line(Offset(0.3, 0.95), Offset(0.62, 1.3), width: 0.07),
      Line(Offset(0.45, 1.1), Offset(0.45, 0), width: 0.05),
      Link(from: Offset(0.4, 0.12), toJoint: Joint.ankle),
      Line(Offset(0.4, 0.12), Offset(0.4, 0.12), width: 0.08),
    ],
    frames: [
      Pose(
        trunk: 48,
        leg: Limb(176, 176),
        legFar: Limb(180, 180),
        foot: 100,
        hands: Offset(0.72, 1.12),
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 48,
        leg: Limb(-125, -125),
        legFar: Limb(180, 180),
        foot: 160,
        footFar: 105,
        hands: Offset(0.72, 1.12),
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 48,
        leg: Limb(176, 176),
        legFar: Limb(180, 180),
        foot: 100,
        hands: Offset(0.72, 1.12),
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
};

/* -------------------------------------------------------------- calves -- */

const Map<String, Demo> _calves = {
  'seated-calf-raise': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    kneeToward: Offset(0, 1),
    gear: [
      Bench(from: -0.3, to: 0.2, height: 0.45),
      Block(from: 0.5, to: 0.75, height: 0.1),
      Pad(Joint.knee, from: Joint.hip, side: 0.1, along: -0.08),
    ],
    frames: [
      Pose(foot: 95, feet: Offset(0.44, 0.13), cue: 0, seconds: 0.6, hold: 0.2),
      Pose(foot: 135, feet: Offset(0.47, 0.25), cue: 1, seconds: 1, hold: 0.5),
      Pose(foot: 72, feet: Offset(0.43, 0.09), cue: 2, seconds: 1.5, hold: 0.3),
    ],
  ),
  'single-leg-calf-raise': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0.18, 0.14),
    gear: [
      Block(from: -0.02, to: 0.24, height: 0.12),
      Line(Offset(0.42, 0), Offset(0.42, 1.45), width: 0.04),
    ],
    frames: [
      // Beta 5.6 (owner: "rotated feet"): the raised foot hangs relaxed
      // behind, square to its shin.
      Pose(
        legFar: Limb(180, -70),
        footFar: -150,
        hands: Offset(0.38, 1.28),
        cue: 0,
        seconds: 0.6,
        hold: 0.3,
      ),
      Pose(
        foot: 140,
        legFar: Limb(180, -70),
        footFar: -150,
        hands: Offset(0.38, 1.28),
        cue: 1,
        seconds: 1.2,
        hold: 0.5,
      ),
      Pose(
        foot: 68,
        legFar: Limb(180, -70),
        footFar: -150,
        hands: Offset(0.38, 1.28),
        seconds: 2,
        hold: 0.3,
      ),
      Pose(
        legFar: Limb(180, -70),
        footFar: -150,
        hands: Offset(0.38, 1.28),
        cue: 2,
        seconds: 0.8,
      ),
    ],
  ),
  'smith-machine-calf-raise': Demo(
    anchor: Joint.toe,
    anchorAt: Offset(0.18, 0.14),
    elbowToward: Offset(-0.5, -1),
    gear: [
      Block(from: -0.02, to: 0.24, height: 0.12),
      Line(Offset(-0.07, 0), Offset(-0.07, 2.3), width: 0.035),
      Plate(at: Joint.upperBack),
    ],
    frames: [
      Pose(
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 0,
        seconds: 0.6,
        hold: 0.2,
      ),
      Pose(
        foot: 140,
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 1,
        seconds: 1,
        hold: 0.5,
      ),
      Pose(
        foot: 68,
        hands: Offset.zero,
        handsFrom: Joint.upperBack,
        cue: 2,
        seconds: 1.5,
        hold: 0.3,
      ),
    ],
  ),
  'leg-press-calf-raise': Demo(
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
      // Beta 5.6 (owner: "weird machine movement"): the platform keeps its
      // angle on the rail, under the balls of the feet.
      Platform(
        angle: 45,
        rail: (Offset(0.25, 0.45), Offset(1.25, 1.45)),
        atToe: true,
      ),
    ],
    frames: [
      Pose(
        trunk: -50,
        head: 25,
        foot: -30,
        feet: Offset(0.6, 1.0),
        hands: Offset(0.05, 0.47),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -50,
        head: 25,
        foot: 15,
        feet: Offset(0.6, 1.0),
        hands: Offset(0.05, 0.47),
        cue: 1,
        seconds: 1.2,
        hold: 0.5,
      ),
      Pose(
        trunk: -50,
        head: 25,
        foot: -50,
        feet: Offset(0.6, 1.0),
        hands: Offset(0.05, 0.47),
        cue: 2,
        seconds: 2,
        hold: 0.3,
      ),
    ],
  ),
};

/* ---------------------------------------------------------------- core -- */

// Lying on the back on the floor: the hips at (0, 0.12), the head to the
// left.
const _floorHip = Offset(0, 0.12);

const Map<String, Demo> _core = {
  // From the front, lying on one side: the figure turned onto its right
  // forearm, feet stacked.
  'side-plank': Demo(
    // Beta 5.6.1 (owner: "the person is in the air"): the elbow under the
    // shoulder and the feet stay on the floor; the hips start down on it
    // and lift until the body is one straight line.
    view: DemoView.front,
    tilt: 75.5,
    frames: [
      Pose(
        tilt: 57,
        leg: Limb(210, 210),
        legFar: Limb(150, 150),
        arm: Limb(123, 33),
        armFar: Limb(57, 57),
        foreScale: 0.3,
        cue: 0,
        seconds: 1,
        hold: 0.5,
      ),
      Pose(
        tilt: 75.5,
        arm: Limb(104.5, 14.5),
        armFar: Limb(75.5, 75.5),
        foreScale: 0.3,
        cue: 1,
        seconds: 1,
        hold: 0.4,
      ),
      Pose(
        tilt: 75.5,
        arm: Limb(104.5, 14.5),
        armFar: Limb(75.5, 75.5),
        foreScale: 0.3,
        cue: 2,
        seconds: 0.2,
        hold: 1.2,
      ),
    ],
  ),
  'dead-bug': Demo(
    anchor: Joint.hip,
    anchorAt: _floorHip,
    frames: [
      // Beta 5.6 (owner: "weird feet movement"): the feet stay flexed,
      // square to the shins.
      Pose(
        trunk: -90,
        leg: Limb(0, 90),
        foot: 15,
        arm: Limb(0, 0),
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        leg: Limb(0, 90),
        legFar: Limb(78, 84),
        foot: 15,
        footFar: 9,
        arm: Limb(-82, -85),
        armFar: Limb(0, 0),
        cue: 1,
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        leg: Limb(0, 90),
        foot: 15,
        arm: Limb(0, 0),
        cue: 2,
        seconds: 1.2,
      ),
      Pose(
        trunk: -90,
        leg: Limb(78, 84),
        legFar: Limb(0, 90),
        foot: 9,
        footFar: 15,
        arm: Limb(0, 0),
        armFar: Limb(-82, -85),
        seconds: 1.6,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        leg: Limb(0, 90),
        foot: 15,
        arm: Limb(0, 0),
        seconds: 1.2,
      ),
    ],
  ),
  'cable-crunch': Demo(
    // Beta 5.6 (owner: "leg should be 90 degree"): kneeling with the thighs
    // upright and the shins flat; the hips stay still.
    anchor: Joint.knee,
    anchorAt: Offset(0, 0.06),
    gear: [Cable(Offset(0.5, 2.1), handle: true)],
    frames: [
      Pose(
        trunk: 12,
        leg: Limb(180, -90),
        foot: -100,
        hands: Offset(0.07, -0.05),
        handsFrom: Joint.head,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 75,
        leg: Limb(180, -90),
        foot: -100,
        head: 20,
        hands: Offset(0.07, -0.05),
        handsFrom: Joint.head,
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: 12,
        leg: Limb(180, -90),
        foot: -100,
        hands: Offset(0.07, -0.05),
        handsFrom: Joint.head,
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
  'crunch': Demo(
    anchor: Joint.hip,
    anchorAt: _floorHip,
    kneeToward: Offset(0, 1),
    elbowToward: Offset(-0.3, 1),
    frames: [
      Pose(
        trunk: -90,
        foot: 100,
        feet: Offset(0.55, Body.ankleHeight),
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -58,
        head: 10,
        foot: 100,
        feet: Offset(0.55, Body.ankleHeight),
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        cue: 1,
        seconds: 0.8,
        hold: 0.4,
      ),
      Pose(
        trunk: -90,
        foot: 100,
        feet: Offset(0.55, Body.ankleHeight),
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        cue: 2,
        seconds: 1.2,
      ),
    ],
  ),
  'reverse-crunch': Demo(
    anchor: Joint.shoulder,
    anchorAt: Offset(-0.5, 0.12),
    frames: [
      Pose(
        trunk: -90,
        leg: Limb(0, 92),
        foot: 90,
        arm: Limb(92, 92),
        cue: 0,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -112,
        leg: Limb(-45, 50),
        foot: 60,
        arm: Limb(92, 92),
        cue: 1,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        leg: Limb(0, 92),
        foot: 90,
        arm: Limb(92, 92),
        cue: 2,
        seconds: 1.4,
      ),
    ],
  ),
  'bicycle-crunch': Demo(
    anchor: Joint.hip,
    anchorAt: _floorHip,
    elbowToward: Offset(-0.3, 1),
    frames: [
      // Beta 5.6 (owner: "weird feet movement"): the feet keep square to
      // the shins.
      Pose(
        trunk: -62,
        leg: Limb(45, 100),
        foot: 25,
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: -55,
        leg: Limb(15, 120),
        legFar: Limb(72, 78),
        foot: 45,
        footFar: 3,
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        cue: 1,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        trunk: -55,
        leg: Limb(72, 78),
        legFar: Limb(15, 120),
        foot: 3,
        footFar: 45,
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        cue: 2,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -62,
        leg: Limb(45, 100),
        foot: 25,
        hands: Offset(0.0, 0.04),
        handsFrom: Joint.head,
        seconds: 0.8,
      ),
    ],
  ),
  // From the front: the cable pulls from your side; the hands press
  // straight out toward you (the arms look short).
  'pallof-press': Demo(
    view: DemoView.front,
    gear: [Cable(Offset(0.95, 1.25), handle: true)],
    frames: [
      Pose(
        arm: Limb(174, -67),
        foreScale: 0.76,
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        arm: Limb(227, 227),
        upperScale: 0.41,
        foreScale: 0.41,
        cue: 1,
        seconds: 1,
        hold: 0.8,
      ),
      Pose(arm: Limb(174, -67), foreScale: 0.76, cue: 2, seconds: 1),
    ],
  ),
  'band-pallof-press': Demo(
    // Beta 5.6 (owner: "not clear enough"): the band runs in front of the
    // body from the side anchor to the hands, so the press out shows
    // against its pull.
    view: DemoView.front,
    gear: [
      Line(Offset(0.98, 0), Offset(0.98, 1.4), width: 0.05),
      Link(from: Offset(0.96, 1.25), band: true, over: true),
      Handles(),
    ],
    frames: [
      Pose(
        arm: Limb(174, -67),
        foreScale: 0.76,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        arm: Limb(227, 227),
        upperScale: 0.41,
        foreScale: 0.41,
        cue: 1,
        seconds: 1.2,
        hold: 1,
      ),
      Pose(arm: Limb(174, -67), foreScale: 0.76, cue: 2, seconds: 1.4),
    ],
  ),
  'mountain-climber': Demo(
    anchor: Joint.hand,
    anchorAt: Offset(1.27, 0.03),
    kneeToward: Offset(0.5, -1),
    frames: [
      Pose(
        trunk: 74,
        arm: Limb(178, 178),
        foot: 165,
        feet: Offset(-0.04, 0.23),
        cue: 0,
        seconds: 0.3,
        hold: 0.3,
      ),
      Pose(
        trunk: 74,
        arm: Limb(178, 178),
        foot: 120,
        footFar: 165,
        feet: Offset(0.5, 0.22),
        feetFar: Offset(-0.04, 0.23),
        cue: 1,
        seconds: 0.35,
      ),
      Pose(
        trunk: 74,
        arm: Limb(178, 178),
        foot: 165,
        footFar: 120,
        feet: Offset(-0.04, 0.23),
        feetFar: Offset(0.5, 0.22),
        cue: 2,
        seconds: 0.35,
      ),
      Pose(
        trunk: 74,
        arm: Limb(178, 178),
        foot: 120,
        footFar: 165,
        feet: Offset(0.5, 0.22),
        feetFar: Offset(-0.04, 0.23),
        seconds: 0.35,
      ),
      Pose(
        trunk: 74,
        arm: Limb(178, 178),
        foot: 165,
        footFar: 120,
        feet: Offset(-0.04, 0.23),
        feetFar: Offset(0.5, 0.22),
        seconds: 0.35,
      ),
    ],
  ),
  'bird-dog': Demo(
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.5),
    frames: [
      // Beta 5.6 (owner: "feet should not become straight when down"): the
      // kneeling feet rest on tucked toes; the raised leg's foot flexes.
      Pose(
        trunk: 80,
        leg: Limb(180, -75),
        foot: -152,
        arm: Limb(178, 178),
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 82,
        leg: Limb(180, -75),
        legFar: Limb(-92, -92),
        foot: -152,
        footFar: -167,
        arm: Limb(80, 80),
        armFar: Limb(178, 178),
        cue: 1,
        seconds: 1.4,
        hold: 0.6,
      ),
      Pose(
        trunk: 80,
        leg: Limb(180, -75),
        foot: -152,
        arm: Limb(178, 178),
        cue: 2,
        seconds: 1.2,
      ),
      Pose(
        trunk: 82,
        leg: Limb(-92, -92),
        legFar: Limb(180, -75),
        foot: -167,
        footFar: -152,
        arm: Limb(178, 178),
        armFar: Limb(80, 80),
        seconds: 1.4,
        hold: 0.6,
      ),
      Pose(
        trunk: 80,
        leg: Limb(180, -75),
        foot: -152,
        arm: Limb(178, 178),
        seconds: 1.2,
      ),
    ],
  ),
  'machine-crunch': Demo(
    // Beta 5.6.1 (owner: "the machine circle should be at the chest"): the
    // pad sits on the chest, the hands on its handles; the machine's arm
    // turns on an axle beside the hip and carries the pad down and forward
    // with the crunch. The weight stack behind the seat and back pad.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.53),
    gear: [
      WeightStack(-0.78, height: 1.6),
      Line(Offset(-0.95, 0.025), Offset(0.45, 0.025), width: 0.05),
      Line(Offset(0, 0.02), Offset(0, 0.53), width: 0.05),
      Line(Offset(-0.9, 1.6), Offset(-0.45, 1.6), width: 0.05),
      Line(Offset(-0.45, 0.02), Offset(-0.45, 1.6), width: 0.05),
      Line(Offset(-0.24, 0.475), Offset(0.22, 0.475), width: 0.08, pad: true),
      Line(Offset(-0.134, 0.6), Offset(-0.19, 1.2), width: 0.09, pad: true),
      Lever(Offset(0, 0.53), to: Joint.chest, over: true, handle: false),
      Pad(Joint.chest, from: Joint.hip, side: 0.01),
    ],
    frames: [
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0.1, -0.02),
        handsFrom: Joint.shoulder,
        cue: 0,
        seconds: 0.5,
        hold: 0.3,
      ),
      Pose(
        trunk: 38,
        leg: Limb(92, 180),
        hands: Offset(0.1, -0.02),
        handsFrom: Joint.shoulder,
        cue: 1,
        seconds: 1.2,
        hold: 0.4,
      ),
      Pose(
        trunk: -5,
        leg: Limb(92, 180),
        hands: Offset(0.1, -0.02),
        handsFrom: Joint.shoulder,
        cue: 2,
        seconds: 2,
      ),
    ],
  ),
  // From the front: sat back on the floor, the hands swing side to side.
  'russian-twist': Demo(
    // Beta 5.6.1 (owner: "the second hand is going weird"): the arms turn
    // with the shoulders as one piece, drawn as seen — the hands together
    // in front of the chest, the elbows bent below them; turning right,
    // the right elbow swings out and the left one comes to the middle.
    view: DemoView.front,
    seated: true,
    seatHeight: 0.14,
    gear: [Dumbbells(single: true)],
    frames: [
      Pose(
        trunk: 20,
        leg: Limb(35, 213),
        thighScale: 0.8,
        hands: Offset(0.03, 0.42),
        handsFar: Offset(-0.03, 0.42),
        elbows: Offset(0.19, 0.38),
        elbowsFar: Offset(-0.19, 0.38),
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 20,
        leg: Limb(35, 213),
        thighScale: 0.8,
        twist: 50,
        hands: Offset(0.25, 0.42),
        handsFar: Offset(0.21, 0.42),
        elbows: Offset(0.237, 0.38),
        elbowsFar: Offset(-0.007, 0.38),
        cue: 1,
        seconds: 1.1,
        hold: 0.2,
      ),
      Pose(
        trunk: 20,
        leg: Limb(35, 213),
        thighScale: 0.8,
        twist: -50,
        hands: Offset(-0.21, 0.42),
        handsFar: Offset(-0.25, 0.42),
        elbows: Offset(0.007, 0.38),
        elbowsFar: Offset(-0.237, 0.38),
        cue: 2,
        seconds: 1.6,
        hold: 0.2,
      ),
      Pose(
        trunk: 20,
        leg: Limb(35, 213),
        thighScale: 0.8,
        hands: Offset(0.03, 0.42),
        handsFar: Offset(-0.03, 0.42),
        elbows: Offset(0.19, 0.38),
        elbowsFar: Offset(-0.19, 0.38),
        seconds: 1,
      ),
    ],
  ),
  'lying-leg-raise': Demo(
    anchor: Joint.hip,
    anchorAt: _floorHip,
    frames: [
      Pose(
        trunk: -90,
        leg: Limb(90, 90),
        foot: 0,
        arm: Limb(92, 92),
        cue: 0,
        seconds: 1.4,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        leg: Limb(2, 2),
        foot: -90,
        arm: Limb(92, 92),
        cue: 1,
        seconds: 1.2,
        hold: 0.3,
      ),
      Pose(
        trunk: -90,
        leg: Limb(80, 80),
        foot: -10,
        arm: Limb(92, 92),
        cue: 2,
        seconds: 1.6,
      ),
    ],
  ),
  // From the front: hands together, from the high pulley down and across.
  'cable-woodchopper': Demo(
    // Beta 5.6.1 (owner: "going too much up"): the chop starts with the
    // hands by the head, not above it; the arms stay long and straight
    // (coming toward you halfway, so they look short) down across the body
    // to low by the other hip, the shoulders turning with them.
    view: DemoView.front,
    gear: [Cable(Offset(0.85, 2.1), handle: true)],
    frames: [
      Pose(
        twist: 70,
        straightArms: true,
        hands: Offset(0.4, 1.58),
        handsFar: Offset(0.36, 1.6),
        cue: 0,
        seconds: 1,
        hold: 0.3,
      ),
      Pose(
        straightArms: true,
        hands: Offset(0.03, 1.2),
        handsFar: Offset(-0.03, 1.2),
        seconds: 0.6,
      ),
      Pose(
        trunk: 12,
        twist: -70,
        straightArms: true,
        hands: Offset(-0.28, 1.03),
        handsFar: Offset(-0.32, 1.02),
        cue: 1,
        seconds: 0.6,
        hold: 0.3,
      ),
      Pose(
        straightArms: true,
        hands: Offset(0.03, 1.2),
        handsFar: Offset(-0.03, 1.2),
        cue: 2,
        seconds: 1,
      ),
    ],
  ),
};

/* ------------------------------------------------------------- carries -- */

// Walking on the spot, side on: a stride, the far foot passing, the other
// stride, the near foot passing.
const _strideA = Pose(
  trunk: 2,
  foot: 95,
  footFar: 135,
  feet: Offset(0.25, Body.ankleHeight),
  feetFar: Offset(-0.22, 0.12),
  anchorAt: Offset(0, 0.9),
  seconds: 0.4,
);
const _passA = Pose(
  trunk: 2,
  foot: 105,
  footFar: 110,
  feet: Offset(0, Body.ankleHeight),
  feetFar: Offset(0.03, 0.2),
  anchorAt: Offset(0, 0.93),
  seconds: 0.35,
);
const _strideB = Pose(
  trunk: 2,
  foot: 135,
  footFar: 95,
  feet: Offset(-0.22, 0.12),
  feetFar: Offset(0.25, Body.ankleHeight),
  anchorAt: Offset(0, 0.9),
  seconds: 0.35,
);
const _passB = Pose(
  trunk: 2,
  foot: 110,
  footFar: 105,
  feet: Offset(0.03, 0.2),
  feetFar: Offset(0, Body.ankleHeight),
  anchorAt: Offset(0, 0.93),
  seconds: 0.35,
);
const _standTall = Pose(
  trunk: 2,
  feet: _ankle,
  feetFar: _ankle,
  anchorAt: _hipsUp,
  seconds: 0.6,
  hold: 0.2,
);

// Hinged down beside the weights, picking them up (cue 0) or setting them
// down (cue 2); and the first stride (cue 1).
const _pickUp = Pose(
  trunk: 42,
  feet: _ankle,
  feetFar: _ankle,
  anchorAt: Offset(-0.18, 0.62),
  cue: 0,
  seconds: 0.8,
  hold: 0.3,
);
const _setDown = Pose(
  trunk: 42,
  feet: _ankle,
  feetFar: _ankle,
  anchorAt: Offset(-0.18, 0.62),
  cue: 2,
  seconds: 0.8,
  hold: 0.3,
);
const _firstStride = Pose(
  trunk: 2,
  foot: 95,
  footFar: 135,
  feet: Offset(0.25, Body.ankleHeight),
  feetFar: Offset(-0.22, 0.12),
  anchorAt: Offset(0, 0.9),
  cue: 1,
  seconds: 0.4,
);
const _walk = [
  _pickUp,
  _standTall,
  _firstStride,
  _passA,
  _strideB,
  _passB,
  _strideA,
  _passA,
  _strideB,
  _passB,
  _standTall,
  _setDown,
];

// Overhead: the near arm locked out, the far hand at your side.
const _overhead = Limb(2, 2);
const _side = Limb(180, 180);

const Map<String, Demo> _carries = {
  'farmers-carry': Demo(anchor: Joint.hip, gear: [Dumbbells()], frames: _walk),
  'kettlebell-farmers-carry':
      Demo(anchor: Joint.hip, gear: [Kettlebell()], frames: _walk),
  // From the front: one weight, the body upright, marching on the spot.
  'suitcase-carry': Demo(
    // Beta 5.6.1 (owner: "give side view"): from the side, walking on the
    // spot, tall; the weight hangs still in the near hand, the free arm
    // swings a little against the steps.
    anchor: Joint.hip,
    anchorAt: Offset(0, 0.94),
    gear: [Dumbbells(nearOnly: true, neutral: true)],
    frames: [
      Pose(anchorAt: Offset(0, 0.94), cue: 0, seconds: 0.5, hold: 0.4),
      Pose(
        leg: Limb(162, 162),
        legFar: Limb(195, 205),
        foot: 95,
        footFar: 118,
        armFar: Limb(168, 160),
        anchorAt: Offset(0, 0.9),
        cue: 1,
        seconds: 0.45,
      ),
      Pose(
        legFar: Limb(170, 205),
        footFar: 125,
        anchorAt: Offset(0, 0.94),
        seconds: 0.4,
      ),
      Pose(
        leg: Limb(195, 205),
        legFar: Limb(162, 162),
        foot: 118,
        footFar: 95,
        armFar: Limb(192, 192),
        anchorAt: Offset(0, 0.9),
        seconds: 0.4,
      ),
      Pose(
        leg: Limb(170, 205),
        foot: 125,
        anchorAt: Offset(0, 0.94),
        seconds: 0.4,
      ),
      Pose(
        leg: Limb(162, 162),
        legFar: Limb(195, 205),
        foot: 95,
        footFar: 118,
        armFar: Limb(168, 160),
        anchorAt: Offset(0, 0.9),
        seconds: 0.4,
      ),
      Pose(
        legFar: Limb(170, 205),
        footFar: 125,
        anchorAt: Offset(0, 0.94),
        seconds: 0.4,
      ),
      Pose(anchorAt: Offset(0, 0.94), cue: 2, seconds: 0.45, hold: 0.4),
    ],
  ),
  'overhead-carry': Demo(
    anchor: Joint.hip,
    gear: [Kettlebell(nearOnly: true)],
    frames: [
      Pose(
        trunk: 2,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        arm: Limb(165, 5),
        armFar: _side,
        seconds: 0.4,
        hold: 0.3,
      ),
      Pose(
        trunk: 2,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        arm: _overhead,
        armFar: _side,
        cue: 0,
        seconds: 0.8,
        hold: 0.3,
      ),
      Pose(
        trunk: 2,
        foot: 95,
        footFar: 135,
        feet: Offset(0.25, Body.ankleHeight),
        feetFar: Offset(-0.22, 0.12),
        anchorAt: Offset(0, 0.9),
        arm: _overhead,
        armFar: _side,
        cue: 1,
        seconds: 0.4,
      ),
      Pose(
        trunk: 2,
        foot: 105,
        footFar: 110,
        feet: Offset(0, Body.ankleHeight),
        feetFar: Offset(0.03, 0.2),
        anchorAt: Offset(0, 0.93),
        arm: _overhead,
        armFar: _side,
        seconds: 0.35,
      ),
      Pose(
        trunk: 2,
        foot: 135,
        footFar: 95,
        feet: Offset(-0.22, 0.12),
        feetFar: Offset(0.25, Body.ankleHeight),
        anchorAt: Offset(0, 0.9),
        arm: _overhead,
        armFar: _side,
        seconds: 0.35,
      ),
      Pose(
        trunk: 2,
        foot: 110,
        footFar: 105,
        feet: Offset(0.03, 0.2),
        feetFar: Offset(0, Body.ankleHeight),
        anchorAt: Offset(0, 0.93),
        arm: _overhead,
        armFar: _side,
        seconds: 0.35,
      ),
      Pose(
        trunk: 2,
        foot: 95,
        footFar: 135,
        feet: Offset(0.25, Body.ankleHeight),
        feetFar: Offset(-0.22, 0.12),
        anchorAt: Offset(0, 0.9),
        arm: _overhead,
        armFar: _side,
        seconds: 0.4,
      ),
      Pose(
        trunk: 2,
        foot: 105,
        footFar: 110,
        feet: Offset(0, Body.ankleHeight),
        feetFar: Offset(0.03, 0.2),
        anchorAt: Offset(0, 0.93),
        arm: _overhead,
        armFar: _side,
        seconds: 0.35,
      ),
      Pose(
        trunk: 2,
        feet: _ankle,
        feetFar: _ankle,
        anchorAt: _hipsUp,
        arm: _overhead,
        armFar: _side,
        cue: 2,
        seconds: 0.5,
        hold: 0.3,
      ),
    ],
  ),
};
