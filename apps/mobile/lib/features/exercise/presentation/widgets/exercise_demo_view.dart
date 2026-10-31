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
      if (demo.view == DemoView.front) add(Offset(-e.value.dx, e.value.dy));
    }
    for (final g in demo.gear) {
      switch (g) {
        case Plate(:final at, :final radius):
          add(f[at], radius);
        case Dumbbells():
          add(f[Joint.hand], 0.12);
        case Pad():
          add(g.centre(f), g.radius);
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
      case Cable(:final pulley, :final mirrored):
        add(pulley, 0.12);
        if (mirrored) add(Offset(-pulley.dx, pulley.dy), 0.12);
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
  const m = 0.08;
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
  });

  final Demo demo;
  final Figure figure;
  final Rect bounds;
  final Color ink;
  final Color dim;
  final Color accent;
  final Color rule;

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
    Offset mirror(Offset o) => Offset(-o.dx, o.dy);

    // The floor.
    bone(
      Offset(bounds.left + 0.02, 0),
      Offset(bounds.right - 0.02, 0),
      rule,
      0.012,
    );

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
            if (handle) canvas.drawCircle(c(hand), 0.03 * s, fill(accent));
          }
          cable(pulley, f[Joint.hand]);
          if (mirrored) cable(mirror(pulley), f[Joint.handFar]);
        case Platform(:final angle, :final rail, :final length):
          if (rail != null) bone(rail.$1, rail.$2, rule, 0.025);
          final mid = (f[Joint.ankle] + f[Joint.toe]) / 2 + dirOf(angle) * 0.04;
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
      bone(f[Joint.hip], f[Joint.kneeFar], dim, 0.11);
      bone(f[Joint.kneeFar], f[Joint.ankleFar], dim, 0.09);
      bone(f[Joint.ankleFar], f[Joint.toeFar], dim, 0.06);
      bone(f[Joint.shoulder], f[Joint.elbowFar], dim, 0.085);
      bone(f[Joint.elbowFar], f[Joint.handFar], dim, 0.075);
      // The body.
      bone(f[Joint.hip], f[Joint.shoulder], ink, 0.17);
      canvas.drawCircle(c(f[Joint.head]), Body.head * s, fill(ink));
      bone(f[Joint.hip], f[Joint.knee], ink, 0.11);
      bone(f[Joint.knee], f[Joint.ankle], ink, 0.09);
      bone(f[Joint.ankle], f[Joint.toe], ink, 0.06);
      bone(f[Joint.shoulder], f[Joint.elbow], ink, 0.085);
      bone(f[Joint.elbow], f[Joint.hand], ink, 0.075);
    } else {
      final sh = f[Joint.shoulder];
      final hip = f[Joint.hip];
      final torso = Path()
        ..moveTo(c(sh).dx, c(sh).dy)
        ..lineTo(c(mirror(sh)).dx, c(mirror(sh)).dy)
        ..lineTo(c(Offset(-Body.hipHalf - 0.05, hip.dy)).dx, c(hip).dy)
        ..lineTo(c(Offset(Body.hipHalf + 0.05, hip.dy)).dx, c(hip).dy)
        ..close();
      canvas.drawPath(
        torso,
        Paint()
          ..color = ink
          ..style = PaintingStyle.fill
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(torso, stroke(ink, 0.06));
      canvas.drawCircle(c(f[Joint.head]), Body.head * s, fill(ink));
      for (final side in [false, true]) {
        Offset at(Joint j) => side ? mirror(f[j]) : f[j];
        final hipJ = Offset((side ? -1 : 1) * Body.hipHalf, hip.dy);
        bone(hipJ, at(Joint.knee), ink, 0.11);
        bone(at(Joint.knee), at(Joint.ankle), ink, 0.09);
        bone(at(Joint.ankle), at(Joint.toe), ink, 0.06);
        bone(at(Joint.shoulder), at(Joint.elbow), ink, 0.085);
        bone(at(Joint.elbow), at(Joint.hand), ink, 0.075);
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
            fill(dim.withValues(alpha: 0.55)),
          );
          canvas.drawCircle(c(f[at]), radius * s, stroke(dim, 0.02));
          canvas.drawCircle(c(f[at]), 0.035 * s, fill(dim));
        case Dumbbells(:final single, :final nearOnly, :final neutral):
          final hands = f.view == DemoView.front
              ? [f[Joint.hand], mirror(f[Joint.hand])]
              : single || nearOnly
                  ? [f[Joint.hand]]
                  : [f[Joint.handFar], f[Joint.hand]];
          for (final h in hands) {
            if (neutral && f.view == DemoView.side) {
              final d = f[Joint.hand] - f[Joint.elbow];
              final u = d / d.distance;
              final n = Offset(-u.dy, u.dx);
              bone(h - n * 0.11, h + n * 0.11, dim, 0.07);
            } else {
              final r = (single ? 0.09 : 0.075) * s;
              canvas.drawCircle(c(h), r, fill(dim));
              canvas.drawCircle(c(h), r, stroke(ink, 0.008));
            }
          }
        case Pad(:final radius):
          canvas.drawCircle(c(g.centre(f)), radius * s, fill(dim));
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(DemoPainter old) =>
      old.figure != figure ||
      old.ink != ink ||
      old.accent != accent ||
      old.bounds != bounds;
}
