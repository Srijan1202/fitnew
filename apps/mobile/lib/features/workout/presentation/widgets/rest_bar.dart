import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../controllers/rest_timer.dart';

String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The sticky footer of the active session: elapsed time, sets done /
/// planned, the rest countdown when one is running (−15 / +15 / skip), and
/// Finish. Numbers in the metric face; a hairline above; paper, not a
/// coloured bar.
class SessionFooter extends ConsumerWidget {
  const SessionFooter({
    required this.elapsed,
    required this.done,
    required this.planned,
    required this.finishing,
    required this.onFinish,
    super.key,
  });

  final Duration elapsed;
  final int done;
  final int planned;
  final bool finishing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final rest = ref.watch(restTimerProvider);
    final timer = ref.read(restTimerProvider.notifier);
    return Material(
      color: FitColors.paper,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FitColors.rule)),
          ),
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.screen,
            FitSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (rest != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                  child: Row(
                    key: const ValueKey('rest.bar'),
                    children: <Widget>[
                      Text(
                        rest.done ? 'REST OVER' : 'REST',
                        style: textTheme.labelSmall?.copyWith(
                          color: rest.done ? FitColors.pine : FitColors.ink60,
                        ),
                      ),
                      const SizedBox(width: FitSpacing.md),
                      Text(
                        formatClock(rest.remaining),
                        key: const ValueKey('rest.remaining'),
                        style: textTheme.displaySmall?.copyWith(
                          color: rest.done ? FitColors.pine : FitColors.ink,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      _Tap(
                        key: const ValueKey('rest.minus'),
                        label: '−15',
                        onTap: rest.done
                            ? null
                            : () => timer.adjust(const Duration(seconds: -15)),
                      ),
                      _Tap(
                        key: const ValueKey('rest.plus'),
                        label: '+15',
                        onTap: rest.done
                            ? null
                            : () => timer.adjust(const Duration(seconds: 15)),
                      ),
                      _Tap(
                        key: const ValueKey('rest.skip'),
                        label: rest.done ? 'OK' : 'Skip',
                        onTap: timer.skip,
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('ELAPSED', style: textTheme.labelSmall),
                      Text(
                        formatClock(elapsed),
                        key: const ValueKey('session.elapsed'),
                        style: textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(width: FitSpacing.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('SETS', style: textTheme.labelSmall),
                      Text(
                        planned > 0 ? '$done / $planned' : '$done',
                        key: const ValueKey('session.sets'),
                        style: textTheme.titleLarge?.copyWith(
                          color: planned > 0 && done >= planned
                              ? FitColors.pine
                              : FitColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('session.finish'),
                    onPressed: finishing ? null : onFinish,
                    child: const Text('Finish'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(FitRadius.medium),
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: FitSpacing.sm),
        alignment: Alignment.center,
        child: Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            color: onTap == null ? FitColors.ink35 : FitColors.ink,
          ),
        ),
      ),
    );
  }
}
