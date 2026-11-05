import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/demo/demo_rig.dart';

/// Beta 5.0 (owner): an exercise's demo — the figure going through the lift
/// [loops] times, then resting on the start with Play (battery, and the
/// cues can be read in peace). Tap pauses; Slow plays at half speed; each key moment is a chip
/// numbered as its written cue, and tapping one shows that moment. With
/// "Remove animations" on (Android), it never loops: the key moments are
/// still pictures to step through.
class ExerciseDemoView extends StatefulWidget {
  const ExerciseDemoView({
    required this.demo,
    required this.name,
    this.note,
    super.key,
  });

  final Demo demo;
  final String name;

  /// A variant's difference ("Palms facing you.").
  final String? note;

  /// Loops played before it stops on the start.
  static const loops = 3;

  @override
  State<ExerciseDemoView> createState() => _ExerciseDemoViewState();
}

class _ExerciseDemoViewState extends State<ExerciseDemoView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final Rect _bounds = demoBounds(widget.demo);
  Duration _last = Duration.zero;
  double _t = 0;
  double _played = 0;
  bool _paused = false;
  bool _slow = false;

  /// The key moment shown when still (paused on a chip, or reduce motion).
  int? _moment;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _syncTicker() {
    final run = !_still && !_paused && _moment == null;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    setState(() {
      _t += dt * (_slow ? 0.5 : 1);
      _played += dt * (_slow ? 0.5 : 1);
      if (_played >= widget.demo.period * ExerciseDemoView.loops) {
        _t = 0;
        _played = 0;
        _paused = true;
      }
    });
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      if (_moment != null) {
        _t = widget.demo.times[_moment!];
        _moment = null;
        _paused = false;
      } else {
        _paused = !_paused;
      }
      if (!_paused) _played = 0;
    });
    _syncTicker();
  }

  void _show(int i) {
    setState(() => _moment = _moment == i && !_still ? null : i);
    if (_moment == null) _t = widget.demo.times[i];
    _syncTicker();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final demo = widget.demo;
    final still = _still;
    final moment = _moment ?? (still ? 0 : null);
    final figure =
        moment != null ? demo.solve(demo.frames[moment]) : demo.at(_t);
    final p = FitPalette.current;
    final aspect =
        (_bounds.width / (_bounds.top - _bounds.bottom)).clamp(0.75, 1.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Demo of ${widget.name}',
          image: true,
          child: GestureDetector(
            key: const ValueKey('demo.canvas'),
            onTap: still ? null : _togglePause,
            child: AspectRatio(
              aspectRatio: aspect,
              child: CustomPaint(
                painter: DemoPainter(
                  demo: demo,
                  figure: figure,
                  bounds: _bounds,
                  ink: p.ink,
                  dim: p.ink35,
                  accent: p.accent,
                  rule: p.rule,
                  paper: p.paper,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: FitSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: FitSpacing.xs,
                runSpacing: FitSpacing.xs,
                children: [
                  for (var i = 0; i < demo.frames.length; i++)
                    if (demo.frames[i].cue case final cue?)
                      ChoiceChip(
                        key: ValueKey('demo.moment.$i'),
                        label: Text('${cue + 1}'),
                        selected: moment == i,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _show(i),
                      ),
                ],
              ),
            ),
            if (demo.holdOnly)
              Text('HOLD', style: t.labelSmall)
            else if (!still) ...[
              FilterChip(
                key: const ValueKey('demo.slow'),
                label: const Text('Slow'),
                selected: _slow,
                visualDensity: VisualDensity.compact,
                onSelected: (v) => setState(() => _slow = v),
              ),
              IconButton(
                key: const ValueKey('demo.pause'),
                tooltip: _paused || _moment != null ? 'Play' : 'Pause',
                onPressed: _togglePause,
                icon: Icon(
                  _paused || _moment != null ? Icons.play_arrow : Icons.pause,
                ),
              ),
            ],
          ],
        ),
        if (widget.note != null)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              widget.note!,
              key: const ValueKey('demo.note'),
              style: t.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Everything the demo ever covers (world units), with a margin: the box
/// stays still while the figure moves. World y is up, so [Rect.top] is the
/// highest point and [Rect.bottom] the lowest (top > bottom).
Rect demoBounds(Demo demo) {
  var minX = double.infinity, maxX = -double.infinity;
  var minY = 0.0, maxY = -double.infinity;
  void add(Offset o, [double r = 0]) {
    minX = math.min(minX, o.dx - r);
    maxX = math.max(maxX, o.dx + r);
    minY = math.min(minY, o.dy - r);
    maxY = math.max(maxY, o.dy + r);
  }

  final step = demo.period / 40;
  for (var t = 0.0; t <= demo.period; t += step) {
    final f = demo.at(t);
    for (final e in f.joints.entries) {
      add(e.value, e.key == Joint.head ? Body.head : 0.06);
      // Beta 5.6 (owner: the side plank sat in a corner): a turned figure
      // is framed as it is, not mirrored.
      if (demo.view == DemoView.front && demo.tilt == 0) {
        add(Offset(-e.value.dx, e.value.dy));
      }
    }
    for (final g in demo.gear) {
      switch (g) {
        case Plate(:final at, :final radius):
          add(f[at], radius);
        case Dumbbells():
          add(f[Joint.hand], 0.12);
          add(f[Joint.handFar], 0.12);
        case Kettlebell():
          add(f[Joint.hand] - const Offset(0, 0.085), 0.09);
          add(f[Joint.handFar] - const Offset(0, 0.085), 0.09);
        case Pad():
          add(g.centre(f), g.radius);
        case Hang():
          add(g.centre(f), g.radius);
        case Bar(:final length?, :final plates):
          final mid = (f[Joint.hand] + f[Joint.handFar]) / 2;
          add(mid + Offset(length / 2, 0), plates ? 0.225 : 0.02);
          add(mid - Offset(length / 2, 0), plates ? 0.225 : 0.02);
        default:
          break;
      }
    }
  }
  for (final g in demo.gear) {
    switch (g) {
      case Bench(:final from, :final to, :final height):
        add(Offset(from, height));
        add(Offset(to, height));
        if (g.backAngle != null) {
          add(Offset(g.backAt!, height) + dirOf(g.backAngle!) * g.backLength);
        }
      case PullBar(:final at):
        add(at + const Offset(0, 0.15));
      case Line(:final a, :final b):
        add(a);
        add(b);
      case Link(:final from, :final to, :final mirrored):
        for (final o in [if (from != null) from, if (to != null) to]) {
          add(o);
          if (mirrored) add(Offset(-o.dx, o.dy));
        }
      case Cable(:final pulley, :final mirrored):
        add(pulley, 0.12);
        if (mirrored) add(Offset(-pulley.dx, pulley.dy), 0.12);
      case Lever(:final pivot, :final mirrored):
        add(pivot, 0.06);
        if (mirrored) add(Offset(-pivot.dx, pivot.dy), 0.06);
      case WeightStack(:final x, :final width, :final height):
        add(Offset(x - width / 2, height + 0.04));
        add(Offset(x + width / 2, 0));
      case Block(:final from, :final to, :final height):
        add(Offset(from, height));
        add(Offset(to, 0));
      case Platform(:final rail):
        if (rail != null) {
          add(rail.$1);
          add(rail.$2);
        }
      default:
        break;
    }
  }
  const m = 0.05;
  return Rect.fromLTRB(minX - m, maxY + m, maxX + m, minY - m);
}

/// Draws one moment of a demo. World y is up; [bounds] maps it to the box
/// (top = the highest point).
class DemoPainter extends CustomPainter {
  DemoPainter({
    required this.demo,
    required this.figure,
    required this.bounds,
    required this.ink,
    required this.dim,
    required this.accent,
    required this.rule,
    required this.paper,
    this.labels = true,
  });

  final Demo demo;
  final Figure figure;
  final Rect bounds;
  final Color ink;
  final Color dim;
  final Color accent;
  final Color rule;

  /// The background: each body part is outlined in it, so an arm in front
  /// of the body (a curl, a pulldown) stays visible (beta 5.0.1).
  final Color paper;

  /// Draw the text labels (a floor press's 45°). Beta 5.6.1: the goldens
  /// leave them out — test text is drawn differently on Linux (CI) than on
  /// Windows, where the goldens are made.
  final bool labels;

  @override
  void paint(Canvas canvas, Size size) {
    final bw = bounds.width;
    final bh = bounds.top - bounds.bottom;
    final s = math.min(size.width / bw, size.height / bh);
    final ox = (size.width - bw * s) / 2;
    final oy = (size.height - bh * s) / 2;
    Offset c(Offset w) =>
        Offset(ox + (w.dx - bounds.left) * s, oy + (bounds.top - w.dy) * s);
    final f = figure;
    Paint stroke(Color col, double w) => Paint()
      ..color = col
      ..strokeWidth = w * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Paint fill(Color col) => Paint()..color = col;
    void bone(Offset a, Offset b, Color col, double w) =>
        canvas.drawLine(c(a), c(b), stroke(col, w));
    // A body part: outlined in the background first.
    void part(Offset a, Offset b, Color col, double w) {
      canvas.drawLine(c(a), c(b), stroke(paper, w + 0.035));
      canvas.drawLine(c(a), c(b), stroke(col, w));
    }

    void head(Offset at) {
      canvas.drawCircle(c(at), (Body.head + 0.0175) * s, fill(paper));
      canvas.drawCircle(c(at), Body.head * s, fill(ink));
    }

    Offset mirror(Offset o) => Offset(-o.dx, o.dy);

    // Beta 5.6.1: a machine's upholstery and moving parts, lighter than its
    // frame.
    final padTone = Color.lerp(rule, dim, 0.5)!;

    // Dumbbells: end-on (palms forward), or showing their length (palms in,
    // or one held upright in both hands).
    void dumbbells(Dumbbells g) {
      final hands = f.view == DemoView.front
          ? g.single
              ? [(f[Joint.hand] + f[Joint.handFar]) / 2]
              : g.nearOnly
                  ? [f[Joint.hand]]
                  : [f[Joint.hand], f[Joint.handFar]]
          : g.single || g.nearOnly
              ? [f[Joint.hand]]
              : [f[Joint.handFar], f[Joint.hand]];
      for (final h in hands) {
        final across = g.across && f.view == DemoView.front;
        if (g.single || g.neutral || across) {
          final Offset n;
          // Beta 5.6: palms toward you or away, seen from the front.
          if (across) {
            n = const Offset(1, 0);
            // Upright: one held in both hands, or palms in seen from the front.
          } else if (g.single || f.view == DemoView.front) {
            n = const Offset(0, 1);
          } else {
            final d = f[Joint.hand] - f[Joint.elbow];
            final u = d / d.distance;
            n = Offset(-u.dy, u.dx);
          }
          if (across && f.turn != 0) {
            // Beta 5.6.1: turning about the forearm, the dumbbell shortens
            // to end-on and back; the nearer end is drawn larger, on top.
            final r = f.turn * math.pi / 180;
            final side =
                h.dx >= (f[Joint.hip].dx + f[Joint.hipFar].dx) / 2 ? 1.0 : -1.0;
            final a = h + Offset(math.cos(r) * 0.1 * side, 0);
            final b = h - Offset(math.cos(r) * 0.1 * side, 0);
            final za = math.sin(r);
            bone(a, b, dim, 0.035);
            for (final (e, z)
                in za >= 0 ? [(b, -za), (a, za)] : [(a, za), (b, -za)]) {
              final rr = 0.055 * (1 + 0.25 * z) * s;
              canvas.drawCircle(c(e), rr, fill(dim));
              canvas.drawCircle(c(e), rr, stroke(ink, 0.008));
            }
            continue;
          }
          bone(h - n * 0.1, h + n * 0.1, dim, 0.035);
          for (final e in [h - n * 0.1, h + n * 0.1]) {
            canvas.drawCircle(c(e), 0.055 * s, fill(dim));
            canvas.drawCircle(c(e), 0.055 * s, stroke(ink, 0.008));
          }
        } else {
          final r = 0.075 * s;
          canvas.drawCircle(c(h), r, fill(dim));
          canvas.drawCircle(c(h), r, stroke(ink, 0.008));
        }
      }
    }

    // Beta 5.2: a band, chain or cable between a joint or a place and another.
    void link(Link g) {
      Offset? end(Joint? j, Offset? at) => j != null ? f[j] : at;
      final a = end(g.fromJoint, g.from);
      final b = end(g.toJoint, g.to);
      if (a == null || b == null) return;
      final w = g.band ? 0.022 : 0.01;
      canvas.drawLine(c(a), c(b), stroke(dim, w));
      if (g.plate case final at?) {
        final u = (a - b) / (a - b).distance;
        final p = b + u * at;
        final n = Offset(-u.dy, u.dx);
        bone(p - n * 0.2, p + n * 0.2, dim, 0.05);
      }
      if (g.mirrored) {
        final cx = (f[Joint.hip].dx + f[Joint.hipFar].dx) / 2;
        Offset mx(Offset o) => Offset(2 * cx - o.dx, o.dy);
        Joint? far(Joint? j) => switch (j) {
              Joint.hand => Joint.handFar,
              Joint.ankle => Joint.ankleFar,
              Joint.knee => Joint.kneeFar,
              Joint.toe => Joint.toeFar,
              Joint.shoulder => Joint.shoulderFar,
              _ => j,
            };
        final a2 = g.fromJoint != null ? f[far(g.fromJoint)!] : mx(a);
        final b2 = g.toJoint != null ? f[far(g.toJoint)!] : mx(b);
        canvas.drawLine(c(a2), c(b2), stroke(dim, w));
      }
    }

    // Beta 5.6: a machine's lever, from its pivot to the joint moving it.
    void lever(Lever g) {
      void one(Offset pivot, Offset joint, double sign) {
        final end = g.end(pivot, joint, sign);
        bone(pivot, end, dim, 0.04);
        // Beta 5.6.1: beside the limb, the rod's end joins the handle.
        if (end != joint && !g.roller) bone(end, joint, dim, 0.03);
        canvas.drawCircle(c(pivot), 0.045 * s, fill(dim));
        canvas.drawCircle(c(pivot), 0.018 * s, fill(rule));
        if (g.roller) {
          canvas.drawCircle(c(end), 0.06 * s, fill(padTone));
          canvas.drawCircle(c(end), 0.06 * s, stroke(dim, 0.012));
        } else if (g.handle) {
          canvas.drawCircle(c(joint), 0.04 * s, fill(dim));
        }
      }

      one(g.pivot, f[g.to], 1);
      if (g.mirrored) {
        final cx = (f[Joint.hip].dx + f[Joint.hipFar].dx) / 2;
        final far = switch (g.to) {
          Joint.hand => Joint.handFar,
          Joint.elbow => Joint.elbowFar,
          Joint.knee => Joint.kneeFar,
          Joint.ankle => Joint.ankleFar,
          _ => g.to,
        };
        one(Offset(2 * cx - g.pivot.dx, g.pivot.dy), f[far], -1);
      }
    }

    // Beta 5.6.1: a weight stack — guide rods, a top, the plates.
    void stack(WeightStack g) {
      final l = g.x - g.width / 2;
      final r = g.x + g.width / 2;
      bone(Offset(l, 0), Offset(l, g.height), rule, 0.035);
      bone(Offset(r, 0), Offset(r, g.height), rule, 0.035);
      bone(Offset(l, g.height), Offset(r, g.height), rule, 0.05);
      canvas.drawCircle(c(Offset(g.x, g.height)), 0.045 * s, fill(dim));
      bone(Offset(g.x, 0.68), Offset(g.x, g.height), dim, 0.008);
      for (var i = 0; i < 10; i++) {
        final y = 0.03 + i * 0.065;
        canvas.drawRect(
          Rect.fromPoints(
            c(Offset(l + 0.03, y + 0.05)),
            c(Offset(r - 0.03, y)),
          ),
          fill(padTone),
        );
      }
    }

    // Beta 5.6: an angle at a joint, labelled.
    void angleMark(AngleMark g) {
      final at = c(f[g.at]);
      final along = dirOf(g.from);
      final u = Offset(along.dx, -along.dy);
      final v = c(f[g.to]) - at;
      final start = math.atan2(u.dy, u.dx);
      var sweep = math.atan2(v.dy, v.dx) - start;
      while (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }
      while (sweep <= -math.pi) {
        sweep += 2 * math.pi;
      }
      final r = g.radius * s;
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: r),
        start,
        sweep,
        false,
        stroke(accent, 0.02),
      );
      if (!labels) return;
      final mid = start + sweep / 2;
      final text = TextPainter(
        text: TextSpan(
          text: g.label,
          style: TextStyle(
            color: accent,
            fontFamily: 'Barlow',
            fontWeight: FontWeight.w700,
            fontSize: 0.11 * s,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centre = at + Offset(math.cos(mid), math.sin(mid)) * (r + 0.1 * s);
      text
        ..paint(canvas, centre - Offset(text.width / 2, text.height / 2))
        ..dispose();
    }

    // The floor.
    if (demo.floor) {
      bone(
        Offset(bounds.left + 0.02, 0),
        Offset(bounds.right - 0.02, 0),
        rule,
        0.012,
      );
    }

    // Gear behind the figure.
    for (final g in demo.gear.where((g) => !g.front)) {
      switch (g) {
        case Bench(:final from, :final to, :final height):
          final r = Rect.fromPoints(
            c(Offset(from, height)),
            c(Offset(to, height - 0.07)),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(0.02 * s)),
            fill(rule),
          );
          bone(
            Offset(from + 0.05, height - 0.07),
            Offset(from + 0.05, 0),
            rule,
            0.03,
          );
          bone(
            Offset(to - 0.05, height - 0.07),
            Offset(to - 0.05, 0),
            rule,
            0.03,
          );
          if (g.backAngle != null) {
            final a = Offset(g.backAt!, height);
            bone(a, a + dirOf(g.backAngle!) * g.backLength, rule, 0.07);
          }
        case Block(:final from, :final to, :final height):
          canvas.drawRect(
            Rect.fromPoints(c(Offset(from, height)), c(Offset(to, 0))),
            fill(rule),
          );
        case Dumbbells():
          dumbbells(g);
        case Line(:final a, :final b, :final width, :final pad):
          bone(a, b, pad ? padTone : rule, width);
        case WeightStack():
          stack(g);
        case Link():
          link(g);
        case Lever():
          lever(g);
        case Sled(:final width):
          final (a, b) = g.ends(f);
          bone(a, b, dim, width);
        case Hang(:final radius):
          final hips = f.view == DemoView.front
              ? (f[Joint.hip] + f[Joint.hipFar]) / 2
              : f[Joint.hip];
          final at = g.centre(f);
          bone(hips, at, dim, 0.012);
          canvas.drawCircle(
            c(at),
            radius * s,
            fill(dim.withValues(alpha: 0.6)),
          );
          canvas.drawCircle(c(at), radius * s, stroke(dim, 0.02));
          canvas.drawCircle(c(at), 0.035 * s, fill(rule));
        case PullBar(:final at):
          bone(
            at + const Offset(-0.12, 0.15),
            at + const Offset(0.12, 0.15),
            rule,
            0.03,
          );
          bone(at, at + const Offset(0, 0.15), rule, 0.025);
          canvas.drawCircle(c(at), 0.04 * s, fill(dim));
        case Cable(:final pulley, :final mirrored, :final handle):
          void cable(Offset pul, Offset hand) {
            bone(
              Offset(pul.dx + 0.08 * pul.dx.sign, 0),
              Offset(pul.dx + 0.08 * pul.dx.sign, math.max(pul.dy, 1.9)),
              rule,
              0.06,
            );
            canvas.drawCircle(c(pul), 0.04 * s, fill(dim));
            canvas.drawLine(c(pul), c(hand), stroke(dim, 0.008));
            if (handle) canvas.drawCircle(c(hand), 0.03 * s, fill(dim));
          }
          final bar = demo.gear.any((g) => g is Bar);
          cable(
            pulley,
            bar ? Offset(0, f[Joint.hand].dy) : f[Joint.hand],
          );
          if (mirrored) cable(mirror(pulley), f[Joint.handFar]);
        case Platform(:final angle, :final rail, :final length):
          if (rail != null) bone(rail.$1, rail.$2, rule, 0.025);
          final mid =
              (g.atToe ? f[Joint.toe] : (f[Joint.ankle] + f[Joint.toe]) / 2) +
                  dirOf(angle) * (g.atToe ? 0.025 : 0.04);
          final along = dirOf(angle - 90);
          bone(
            mid - along * (length / 2),
            mid + along * (length / 2),
            dim,
            0.04,
          );
        default:
          break;
      }
    }

    if (f.view == DemoView.side) {
      // Far limbs, dimmer and behind.
      part(f[Joint.hip], f[Joint.kneeFar], dim, 0.11);
      part(f[Joint.kneeFar], f[Joint.ankleFar], dim, 0.09);
      part(f[Joint.ankleFar], f[Joint.toeFar], dim, 0.06);
      part(f[Joint.shoulder], f[Joint.elbowFar], dim, 0.085);
      part(f[Joint.elbowFar], f[Joint.handFar], dim, 0.075);
      // The body, then the near leg and arm over it, each outlined.
      part(f[Joint.hip], f[Joint.shoulder], ink, 0.17);
      head(f[Joint.head]);
      part(f[Joint.hip], f[Joint.knee], ink, 0.11);
      part(f[Joint.knee], f[Joint.ankle], ink, 0.09);
      part(f[Joint.ankle], f[Joint.toe], ink, 0.06);
      part(f[Joint.shoulder], f[Joint.elbow], ink, 0.085);
      part(f[Joint.elbow], f[Joint.hand], ink, 0.075);
    } else {
      // Beta 5.2: each side from its own joints (the two can differ).
      final shR = f[Joint.shoulder];
      final shL = f[Joint.shoulderFar];
      final hipR = f[Joint.hip];
      final hipL = f[Joint.hipFar];
      final torso = Path()
        ..moveTo(c(shR).dx, c(shR).dy)
        ..lineTo(c(shL).dx, c(shL).dy)
        ..lineTo(c(hipL - const Offset(0.05, 0)).dx, c(hipL).dy)
        ..lineTo(c(hipR + const Offset(0.05, 0)).dx, c(hipR).dy)
        ..close();
      canvas.drawPath(
        torso,
        Paint()
          ..color = ink
          ..style = PaintingStyle.fill
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(torso, stroke(ink, 0.06));
      head(f[Joint.head]);
      for (final (hip, knee, ankle, toe, shoulder, elbow, hand) in [
        (
          Joint.hip,
          Joint.knee,
          Joint.ankle,
          Joint.toe,
          Joint.shoulder,
          Joint.elbow,
          Joint.hand,
        ),
        (
          Joint.hipFar,
          Joint.kneeFar,
          Joint.ankleFar,
          Joint.toeFar,
          Joint.shoulderFar,
          Joint.elbowFar,
          Joint.handFar,
        ),
      ]) {
        part(f[hip], f[knee], ink, 0.11);
        part(f[knee], f[ankle], ink, 0.09);
        part(f[ankle], f[toe], ink, 0.06);
        part(f[shoulder], f[elbow], ink, 0.085);
        part(f[elbow], f[hand], ink, 0.075);
      }
    }

    // What the figure holds.
    for (final g in demo.gear.where((g) => g.front)) {
      switch (g) {
        case Plate(:final at, :final radius):
          // See-through, so the arms behind it still show.
          canvas.drawCircle(
            c(f[at]),
            radius * s,
            fill(dim.withValues(alpha: 0.35)),
          );
          canvas.drawCircle(c(f[at]), radius * s, stroke(dim, 0.02));
          canvas.drawCircle(c(f[at]), 0.035 * s, fill(dim));
        case Dumbbells():
          dumbbells(g);
        case Pad(:final radius):
          canvas.drawCircle(c(g.centre(f)), radius * s, fill(dim));
        case Kettlebell(:final nearOnly, :final single):
          final hands = f.view == DemoView.front && !single
              ? [f[Joint.hand], f[Joint.handFar]]
              : nearOnly || single
                  ? [f[Joint.hand]]
                  : [f[Joint.handFar], f[Joint.hand]];
          for (final h in hands) {
            // The handle in the hand, the bell hanging below it.
            final bell = h - const Offset(0, 0.085);
            canvas.drawCircle(c(h), 0.035 * s, stroke(dim, 0.02));
            canvas.drawCircle(c(bell), 0.075 * s, fill(dim));
            canvas.drawCircle(c(bell), 0.075 * s, stroke(ink, 0.008));
          }
        case Handles():
          for (final h in f.view == DemoView.front
              ? [f[Joint.hand], f[Joint.handFar]]
              : [f[Joint.hand]]) {
            canvas.drawCircle(c(h), 0.035 * s, fill(dim));
          }
        case Lever():
          lever(g);
        case Link():
          link(g);
        case AngleMark():
          angleMark(g);
        case Line(:final a, :final b, :final width):
          // Beta 5.6.1: a pad in front of the body, see-through.
          bone(a, b, padTone.withValues(alpha: 0.7), width);
        case Bar(:final length?, :final plates):
          // Beta 5.6.1: a long bar, a plate near each end.
          final mid = (f[Joint.hand] + f[Joint.handFar]) / 2;
          final half = Offset(length / 2, 0);
          bone(mid - half, mid + half, dim, 0.035);
          if (plates) {
            for (final e in [mid - half, mid + half]) {
              final at = e + Offset(e.dx > mid.dx ? -0.1 : 0.1, 0);
              for (final dx in [-0.035, 0.035]) {
                bone(
                  at + Offset(dx, 0.2),
                  at + Offset(dx, -0.2),
                  dim,
                  0.05,
                );
              }
            }
          }
        case Bar():
          final l = f[Joint.handFar];
          final r = f[Joint.hand];
          bone(
            l - const Offset(0.12, 0),
            r + const Offset(0.12, 0),
            dim,
            0.035,
          );
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(DemoPainter old) =>
      old.figure != figure ||
      old.ink != ink ||
      old.paper != paper ||
      old.accent != accent ||
      old.bounds != bounds ||
      old.labels != labels;
}
