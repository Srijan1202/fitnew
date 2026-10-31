import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Beta 5.0 (owner): exercise demos drawn by FITOS — a plain figure posed by
/// joint angles, no licensed art. Pure: a [Demo] is data, [Demo.at] gives
/// the figure at a moment, and the painter only draws what this returns.
///
/// World units are metres, y up, the ground at y = 0. A direction is an
/// angle in degrees: 0 up, 90 forward (+x, the way the figure faces), 180
/// down, -90 (or 270) back.

/// An average adult's segments, metres.
abstract final class Body {
  static const torso = 0.50;
  static const neck = 0.07;
  static const head = 0.105;
  static const upperArm = 0.30;
  static const forearm = 0.27;
  static const thigh = 0.44;
  static const shin = 0.43;
  static const foot = 0.17;

  /// The ankle above the floor when standing.
  static const ankleHeight = 0.07;

  /// Half the shoulder width and half the hip width, front view.
  static const shoulderHalf = 0.19;
  static const hipHalf = 0.10;
}

/// The unit vector of a direction (see the library comment).
Offset dirOf(double deg) {
  final r = deg * math.pi / 180;
  return Offset(math.sin(r), math.cos(r));
}

/// The direction of a vector, degrees.
double angleOf(Offset v) => math.atan2(v.dx, v.dy) * 180 / math.pi;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// An angle from [a] toward [b] the short way round (beta 5.0.1: a row's arm
/// going from 180 to -70 swung up over the back the long way).
double _lerpAngle(double a, double b, double t) {
  final d = ((b - a) % 360 + 540) % 360 - 180;
  return a + d * t;
}

Offset _lerpO(Offset a, Offset b, double t) =>
    Offset(_lerp(a.dx, b.dx, t), _lerp(a.dy, b.dy, t));

/// A two-segment limb: the upper segment's and the lower segment's
/// directions, degrees.
class Limb {
  const Limb(this.upper, this.lower);

  final double upper;
  final double lower;

  Limb lerp(Limb o, double t) =>
      Limb(_lerpAngle(upper, o.upper, t), _lerpAngle(lower, o.lower, t));

  @override
  bool operator ==(Object other) =>
      other is Limb && other.upper == upper && other.lower == lower;

  @override
  int get hashCode => Object.hash(upper, lower);
}

/// The points of the figure, and of what it holds.
enum Joint {
  hip,
  shoulder,
  head,
  knee,
  ankle,
  toe,
  kneeFar,
  ankleFar,
  toeFar,
  elbow,
  hand,
  elbowFar,
  handFar,

  /// Where a bar sits on the upper back (back squat).
  upperBack,

  /// In front of the chest (goblet squat, a bar at the collarbones).
  chest,

  /// The front of the hips (hip thrust's bar).
  lap,
}

const _armJoints = {Joint.elbow, Joint.hand, Joint.elbowFar, Joint.handFar};
const _legJoints = {
  Joint.knee,
  Joint.ankle,
  Joint.toe,
  Joint.kneeFar,
  Joint.ankleFar,
  Joint.toeFar,
};

/// One key moment of a lift.
///
/// Limbs are posed by angle ([leg], [arm]); or, when [feet] or [hands] is
/// set, reach that point (world, or from [handsFrom]) and bend toward the
/// demo's [Demo.kneeToward] / [Demo.elbowToward]. The far limbs follow the
/// near ones unless given.
class Pose {
  const Pose({
    this.trunk = 0,
    this.head = 0,
    this.leg = const Limb(180, 180),
    this.legFar,
    this.foot = 105,
    this.footFar,
    this.arm = const Limb(180, 180),
    this.armFar,
    this.feet,
    this.feetFar,
    this.hands,
    this.handsFrom,
    this.anchorAt,
    this.seconds = 1,
    this.hold = 0,
    this.cue,
    this.foreScale = 1,
  });

  final double trunk;
  final double head;
  final Limb leg;
  final Limb? legFar;
  final double foot;
  final double? footFar;
  final Limb arm;
  final Limb? armFar;

  /// The near ankle's target (world).
  final Offset? feet;
  final Offset? feetFar;

  /// The hands' target: world, or an offset from [handsFrom].
  final Offset? hands;
  final Joint? handsFrom;

  /// Where the demo's anchor joint is at this moment (else [Demo.anchorAt]).
  final Offset? anchorAt;

  /// Seconds from the previous key moment to this one.
  final double seconds;

  /// Seconds held here.
  final double hold;

  /// The instruction this moment shows (its index), if any.
  final int? cue;

  /// Front view: the forearm's length as seen, signed — 1 hanging as drawn,
  /// 0 pointing at you, negative pointing the other way (a curl seen from
  /// the front: the hand comes up in front of the arm). Beta 5.1.
  final double foreScale;

  Pose lerp(Pose b, double t) => Pose(
        trunk: _lerpAngle(trunk, b.trunk, t),
        head: _lerpAngle(head, b.head, t),
        leg: leg.lerp(b.leg, t),
        legFar: legFar == null && b.legFar == null
            ? null
            : (legFar ?? leg).lerp(b.legFar ?? b.leg, t),
        foot: _lerpAngle(foot, b.foot, t),
        footFar: footFar == null && b.footFar == null
            ? null
            : _lerpAngle(footFar ?? foot, b.footFar ?? b.foot, t),
        arm: arm.lerp(b.arm, t),
        armFar: armFar == null && b.armFar == null
            ? null
            : (armFar ?? arm).lerp(b.armFar ?? b.arm, t),
        feet: feet == null || b.feet == null ? null : _lerpO(feet!, b.feet!, t),
        feetFar: feetFar == null || b.feetFar == null
            ? null
            : _lerpO(feetFar!, b.feetFar!, t),
        hands: hands == null || b.hands == null
            ? null
            : _lerpO(hands!, b.hands!, t),
        handsFrom: handsFrom,
        foreScale: _lerp(foreScale, b.foreScale, t),
        anchorAt: anchorAt == null || b.anchorAt == null
            ? null
            : _lerpO(anchorAt!, b.anchorAt!, t),
      );
}

enum DemoView { side, front }

/// What the figure uses. Drawn behind the figure unless [front].
sealed class Gear {
  const Gear();

  /// Drawn over the figure (what it holds).
  bool get front => false;
}

/// A barbell seen end-on: the plate at [at].
class Plate extends Gear {
  const Plate({this.at = Joint.hand, this.radius = 0.225});
  final Joint at;
  final double radius;
  @override
  bool get front => true;
}

/// A straight bar held in both hands, seen from the front (lat pulldown).
class Bar extends Gear {
  const Bar();
  @override
  bool get front => true;
}

/// A dumbbell in each hand (or one held in both, [single]; or the near
/// hand only, [nearOnly]). Palms forward it is seen end-on; [neutral]
/// (palms in) shows its length, square to the forearm.
class Dumbbells extends Gear {
  const Dumbbells({
    this.single = false,
    this.nearOnly = false,
    this.neutral = false,
    this.behind = false,
  });

  /// One dumbbell held upright in both hands (goblet squat, overhead
  /// extension).
  final bool single;
  final bool nearOnly;
  final bool neutral;

  /// Drawn behind the body (an overhead extension's dumbbell behind the
  /// head).
  final bool behind;
  @override
  bool get front => !behind;
}

/// A flat bench: its top from [from] to [to] at [height]; a back pad from
/// [backFrom] when [backAngle] is set (seats).
class Bench extends Gear {
  const Bench({
    required this.from,
    required this.to,
    this.height = 0.44,
    this.backAngle,
    this.backAt,
    this.backLength = 0.6,
  });
  final double from;
  final double to;
  final double height;
  final double? backAngle;
  final double? backAt;
  final double backLength;
}

/// A pull-up bar end-on at [at], hung from above.
class PullBar extends Gear {
  const PullBar(this.at);
  final Offset at;
}

/// A cable from the pulley at [pulley] to the hands, with its stack.
class Cable extends Gear {
  const Cable(this.pulley, {this.handle = false, this.mirrored = false});
  final Offset pulley;

  /// A handle or bar drawn at the hands.
  final bool handle;

  /// Front view: a second pulley mirrored on the far side.
  final bool mirrored;
  @override
  bool get front => false;
}

/// A machine's roller pad at joint [at] on the limb from [from]: [along]
/// the limb past the joint, and [side] off it (positive: to the left of the
/// limb's direction, e.g. on top of a shin that points forward).
class Pad extends Gear {
  const Pad(
    this.at, {
    required this.from,
    this.side = 0,
    this.along = 0,
    this.radius = 0.06,
  });
  final Joint at;
  final Joint from;
  final double side;
  final double along;
  final double radius;
  @override
  bool get front => true;

  /// Where the pad's centre is on [f].
  Offset centre(Figure f) {
    final d = f[at] - f[from];
    final u = d / d.distance;
    return f[at] + u * along + Offset(-u.dy, u.dx) * side;
  }
}

/// A platform the feet push (leg press) or stand on: a plate through the
/// sole, square to [angle]; with [rail], its track.
class Platform extends Gear {
  const Platform({required this.angle, this.rail, this.length = 0.5});
  final double angle;
  final (Offset, Offset)? rail;
  final double length;
}

/// A block on the floor from [from] to [to], [height] tall (calf raise).
class Block extends Gear {
  const Block({required this.from, required this.to, required this.height});
  final double from;
  final double to;
  final double height;
}

/// A lift's demo.
class Demo {
  const Demo({
    required this.frames,
    this.view = DemoView.side,
    this.anchor = Joint.ankle,
    this.anchorAt = const Offset(0, Body.ankleHeight),
    this.gear = const [],
    this.kneeToward = const Offset(1, 0),
    this.elbowToward = const Offset(0, -1),
    this.holdOnly = false,
    this.seated = false,
    this.bentKnees = false,
  });

  final List<Pose> frames;
  final DemoView view;

  /// The joint kept at [anchorAt] (or the frame's own [Pose.anchorAt]).
  final Joint anchor;
  final Offset anchorAt;
  final List<Gear> gear;
  final Offset kneeToward;
  final Offset elbowToward;

  /// A hold (plank): one position, no reps.
  final bool holdOnly;

  /// Front view, seated (lat pulldown): the thighs come toward you, so they
  /// look short; the shins hang to the floor.
  final bool seated;

  /// Front view: knees bent and apart, for a hinge seen from the front
  /// (rear delt fly).
  final bool bentKnees;

  /// One loop, seconds: each move and hold, and back to the start.
  double get period =>
      frames.fold<double>(0, (s, f) => s + f.hold) +
      frames.skip(1).fold<double>(0, (s, f) => s + f.seconds) +
      frames.first.seconds;

  /// When each key moment is reached (seconds into the loop).
  List<double> get times {
    final out = <double>[];
    var t = 0.0;
    for (var i = 0; i < frames.length; i++) {
      if (i > 0) t += frames[i].seconds;
      out.add(t);
      t += frames[i].hold;
    }
    return out;
  }

  /// The pose [t] seconds into the loop.
  Pose poseAt(double t) {
    final p = period;
    var x = t % p;
    if (x < 0) x += p;
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      if (i > 0) {
        if (x < f.seconds) {
          return frames[i - 1].lerp(f, _ease(x / f.seconds));
        }
        x -= f.seconds;
      }
      if (x < f.hold) return f;
      x -= f.hold;
    }
    // Back to the start.
    final back = frames.first.seconds;
    return frames.last.lerp(frames.first, _ease((x / back).clamp(0.0, 1.0)));
  }

  /// The figure [t] seconds into the loop.
  Figure at(double t) => solve(poseAt(t));

  /// The figure in [pose].
  Figure solve(Pose pose) => view == DemoView.side ? _side(pose) : _front(pose);

  /* ------------------------------------------------------------ side -- */

  Figure _side(Pose p) {
    final j = <Joint, Offset>{};
    final trunk = dirOf(p.trunk);
    j[Joint.hip] = Offset.zero;
    j[Joint.shoulder] = trunk * Body.torso;
    j[Joint.head] =
        j[Joint.shoulder]! + dirOf(p.trunk + p.head) * (Body.neck + Body.head);
    _derived(j, p.trunk);

    void legsFk() {
      _limb(
        j,
        Joint.hip,
        Joint.knee,
        Joint.ankle,
        p.leg,
        Body.thigh,
        Body.shin,
      );
      _limb(
        j,
        Joint.hip,
        Joint.kneeFar,
        Joint.ankleFar,
        p.legFar ?? p.leg,
        Body.thigh,
        Body.shin,
      );
    }

    void armsFk() {
      _limb(
        j,
        Joint.shoulder,
        Joint.elbow,
        Joint.hand,
        p.arm,
        Body.upperArm,
        Body.forearm,
      );
      _limb(
        j,
        Joint.shoulder,
        Joint.elbowFar,
        Joint.handFar,
        p.armFar ?? p.arm,
        Body.upperArm,
        Body.forearm,
      );
    }

    final at = p.anchorAt ?? anchorAt;
    if (_legJoints.contains(anchor)) {
      legsFk();
      _feet(j, p);
      _shift(j, at - j[anchor]!);
    } else if (_armJoints.contains(anchor)) {
      armsFk();
      _shift(j, at - j[anchor]!);
    } else {
      _shift(j, at - j[anchor]!);
    }

    if (!j.containsKey(Joint.knee)) {
      if (p.feet != null) {
        _reach(
          j,
          Joint.hip,
          Joint.knee,
          Joint.ankle,
          p.feet!,
          Body.thigh,
          Body.shin,
          kneeToward,
        );
        _reach(
          j,
          Joint.hip,
          Joint.kneeFar,
          Joint.ankleFar,
          p.feetFar ?? p.feet!,
          Body.thigh,
          Body.shin,
          kneeToward,
        );
      } else {
        legsFk();
      }
      _feet(j, p);
    }
    if (!j.containsKey(Joint.hand)) {
      if (p.hands != null) {
        final target =
            p.handsFrom == null ? p.hands! : j[p.handsFrom!]! + p.hands!;
        _reach(
          j,
          Joint.shoulder,
          Joint.elbow,
          Joint.hand,
          target,
          Body.upperArm,
          Body.forearm,
          elbowToward,
        );
        j[Joint.elbowFar] = j[Joint.elbow]!;
        j[Joint.handFar] = j[Joint.hand]!;
      } else {
        armsFk();
      }
    }
    return Figure(DemoView.side, j);
  }

  static void _derived(Map<Joint, Offset> j, double trunk) {
    final s = j[Joint.shoulder]!;
    final h = j[Joint.hip]!;
    final back = dirOf(trunk - 90);
    final along = dirOf(trunk);
    j[Joint.upperBack] = s + back * 0.08 - along * 0.04;
    j[Joint.chest] = s - back * 0.15 - along * 0.10;
    j[Joint.lap] = h - back * 0.13 + along * 0.02;
  }

  static void _feet(Map<Joint, Offset> j, Pose p) {
    j[Joint.toe] = j[Joint.ankle]! + dirOf(p.foot) * Body.foot;
    j[Joint.toeFar] =
        j[Joint.ankleFar]! + dirOf(p.footFar ?? p.foot) * Body.foot;
  }

  static void _shift(Map<Joint, Offset> j, Offset by) {
    for (final k in j.keys.toList()) {
      j[k] = j[k]! + by;
    }
  }

  static void _limb(
    Map<Joint, Offset> j,
    Joint root,
    Joint mid,
    Joint end,
    Limb l,
    double a,
    double b,
  ) {
    j[mid] = j[root]! + dirOf(l.upper) * a;
    j[end] = j[mid]! + dirOf(l.lower) * b;
  }

  /// Two-bone reach from [root] toward [target]; the middle joint bends to
  /// the side of [toward]. Out of reach, the limb points straight at it.
  static void _reach(
    Map<Joint, Offset> j,
    Joint root,
    Joint mid,
    Joint end,
    Offset target,
    double a,
    double b,
    Offset toward,
  ) {
    final r = j[root]!;
    final v = target - r;
    final d = v.distance.clamp((a - b).abs() + 1e-6, a + b - 1e-6);
    final u = v / v.distance;
    // Distance along u to the foot of the middle joint, and its height off it.
    final x = (a * a - b * b + d * d) / (2 * d);
    final y = math.sqrt(math.max(0, a * a - x * x));
    final n = Offset(-u.dy, u.dx);
    final m1 = r + u * x + n * y;
    final m2 = r + u * x - n * y;
    final mid0 = r + u * x;
    final m = ((m1 - mid0).dx * toward.dx + (m1 - mid0).dy * toward.dy) >=
            ((m2 - mid0).dx * toward.dx + (m2 - mid0).dy * toward.dy)
        ? m1
        : m2;
    j[mid] = m;
    j[end] = r + u * d;
  }

  /* ----------------------------------------------------------- front -- */

  /// Front view: the figure faces you; [Pose.arm] is the right arm (drawn
  /// on the right, +x), the left mirrors it; [Pose.trunk] leans toward you
  /// (the torso looks shorter); legs straight. [Pose.hands] is the right
  /// hand's target (the left mirrors).
  Figure _front(Pose p) {
    final j = <Joint, Offset>{};
    final torso = Body.torso * math.cos(p.trunk * math.pi / 180).abs();
    final hipY = seated ? 0.53 : Body.ankleHeight + Body.thigh + Body.shin;
    j[Joint.hip] = Offset(0, hipY);
    j[Joint.shoulder] = Offset(Body.shoulderHalf, hipY + torso);
    // Leaning toward you, the head drops in front of the shoulders (bent
    // well over, below their line: beta 5.0.1).
    final lean = math.cos(p.trunk * math.pi / 180).abs();
    j[Joint.head] = Offset(
      0,
      hipY + torso + (Body.neck + Body.head) * (lean * 1.4 - 0.4),
    );
    final kneeX = seated
        ? Body.hipHalf + 0.04
        : bentKnees
            ? Body.hipHalf + 0.05
            : Body.hipHalf;
    j[Joint.knee] = Offset(
      kneeX,
      seated ? Body.ankleHeight + Body.shin : hipY - Body.thigh,
    );
    j[Joint.ankle] = Offset(kneeX, Body.ankleHeight);
    j[Joint.toe] = Offset(kneeX + 0.03, 0.01);
    if (p.hands != null) {
      _reach(
        j,
        Joint.shoulder,
        Joint.elbow,
        Joint.hand,
        p.hands!,
        Body.upperArm,
        Body.forearm,
        elbowToward,
      );
    } else {
      // Mirror the side convention: 90 is out to the right.
      _limb(
        j,
        Joint.shoulder,
        Joint.elbow,
        Joint.hand,
        p.arm,
        Body.upperArm,
        Body.forearm * p.foreScale,
      );
    }
    Offset m(Offset o) => Offset(-o.dx, o.dy);
    j[Joint.kneeFar] = m(j[Joint.knee]!);
    j[Joint.ankleFar] = m(j[Joint.ankle]!);
    j[Joint.toeFar] = m(j[Joint.toe]!);
    j[Joint.elbowFar] = m(j[Joint.elbow]!);
    j[Joint.handFar] = m(j[Joint.hand]!);
    return Figure(DemoView.front, j);
  }
}

/// Smooth start and stop.
double _ease(double t) => t * t * (3 - 2 * t);

/// The figure at one moment: every joint, world units.
class Figure {
  const Figure(this.view, this.joints);

  final DemoView view;
  final Map<Joint, Offset> joints;

  Offset operator [](Joint j) => joints[j]!;

  /// The lowest point of the body (its joints), for "nothing below the floor".
  double get lowest => joints.values.map((o) => o.dy).reduce(math.min);
}
