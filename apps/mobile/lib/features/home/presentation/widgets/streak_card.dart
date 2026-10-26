import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../data/streak_api.dart';

/// Beta 3.3 (ADR-018 amendment): the streak and the weekly goal ring, one
/// compact card at the top of Home. Encouraging, never shaming: a run of 0
/// just says how to start one.
class StreakCard extends StatelessWidget {
  const StreakCard({required this.streak, super.key});

  final Streak streak;

  String get _headline {
    final s = streak;
    if (s.current == 0) return 'Start a streak';
    return '${s.current}-day streak';
  }

  String get _detail {
    final s = streak;
    if (s.current == 0) return 'Log a workout or a meal today.';
    // Beta 3.8 (tester feedback): a rest day counts by itself.
    if (s.todayRest && s.todayCounted) {
      return 'Rest day. It counts toward your streak, nothing to log.';
    }
    if (!s.todayCounted) {
      return 'Log a workout or a meal today to keep it going.';
    }
    if (s.best > s.current) return 'Best so far: ${s.best} days.';
    return 'Your best yet. Keep going.';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = streak.weekDone;
    final planned = streak.weekPlanned;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.md,
      ),
      child: FitBlock(
        key: const ValueKey('home.streak'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.local_fire_department,
              size: 32,
              color: streak.current == 0 ? FitColors.ink35 : FitColors.amber,
            ),
            const SizedBox(width: FitSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _headline,
                    key: const ValueKey('home.streak.headline'),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _detail,
                    key: const ValueKey('home.streak.detail'),
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
            if (done != null && planned != null) ...<Widget>[
              const SizedBox(width: FitSpacing.sm),
              _GoalRing(done: done, planned: planned),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.done, required this.planned});

  final int done;
  final int planned;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$done of $planned workouts this week',
      child: InkWell(
        key: const ValueKey('home.ring'),
        customBorder: const CircleBorder(),
        onTap: () => context.go(Routes.plan),
        child: SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _RingPainter(
              fraction: math.min(1, done / planned),
              track: FitColors.rule,
              fill: done >= planned ? FitColors.pine : FitColors.accent,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$done/$planned',
                    key: const ValueKey('home.ring.count'),
                    style: textTheme.titleSmall,
                  ),
                  Text(
                    'this week',
                    style: textTheme.labelSmall
                        ?.copyWith(color: FitColors.ink60, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arc, 0, 2 * math.pi, false, base);
    if (fraction <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      base
        ..color = fill
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}
