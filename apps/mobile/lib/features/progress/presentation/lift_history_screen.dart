import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/lift_history_api.dart';
import 'progress_screen.dart';

final liftHistoryApiProvider = Provider<LiftHistoryApi>(
  (ref) => DioLiftHistoryApi(ref.watch(dioProvider)),
);

final liftHistoryProvider = FutureProvider.family<LiftHistory, String>(
  (ref, exerciseId) async {
    requireSession(ref);
    final r = await ref.watch(liftHistoryApiProvider).history(exerciseId);
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Beta 6.1 (E3): every session you have done a lift in — the estimated
/// 1RM over all of them, then each session's sets, newest first. Reached
/// from Progress → Strength and from the exercise's own page.
class LiftHistoryScreen extends ConsumerWidget {
  const LiftHistoryScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(liftHistoryProvider(exerciseId));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('LIFT HISTORY', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(FitSpacing.screen),
              children: <Widget>[
                Text(
                  (e is Failure ? e : const Unknown()).message,
                  key: const ValueKey('lift.error'),
                ),
                const SizedBox(height: FitSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () =>
                        ref.invalidate(liftHistoryProvider(exerciseId)),
                    child: const Text('Try again'),
                  ),
                ),
              ],
            ),
            data: (h) => _Body(history: h),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.history});

  final LiftHistory history;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final h = history;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final points = h.sessions.reversed
        .where((s) => s.estimated1RmKg != null)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      children: <Widget>[
        Text(
          h.name,
          key: const ValueKey('lift.name'),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          h.sessions.isEmpty
              ? 'No sessions with this lift yet.'
              : '${h.sessions.length} ${h.sessions.length == 1 ? 'session' : 'sessions'}'
                  '${h.bestKg == null ? '' : ' · best est. 1RM ${ProgressScreen.kg(h.bestKg!)} kg on ${ProgressScreen.date(h.bestDate!)}'}',
          key: const ValueKey('lift.summary'),
          style: muted,
        ),
        if (points.length >= 2) ...<Widget>[
          const SizedBox(height: FitSpacing.md),
          FitBlock(
            padding: const EdgeInsets.all(FitSpacing.md),
            child: Semantics(
              label: 'Estimated 1RM over ${points.length} sessions, '
                  'from ${ProgressScreen.kg(points.first.estimated1RmKg!)} '
                  'to ${ProgressScreen.kg(points.last.estimated1RmKg!)} kg',
              child: SizedBox(
                key: const ValueKey('lift.chart'),
                height: 160,
                child: CustomPaint(
                  painter: _E1rmPainter(
                    values: [for (final p in points) p.estimated1RmKg!],
                    records: [for (final p in points) p.record],
                    line: FitColors.ink,
                    record: FitColors.accent,
                    grid: FitColors.rule,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated 1RM (Epley), for display only. Filled dots are records.',
            style: muted,
          ),
        ],
        const SizedBox(height: FitSpacing.md),
        for (final s in h.sessions) _SessionRow(session: s),
        if (h.truncated)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: Text('Older sessions are not shown.', style: muted),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final LiftSession session;

  static String _w(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = session;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final sets = s.sets
        .map(
          (x) => x.weightKg == null || x.weightKg == 0
              ? '${x.reps}'
              : '${_w(x.weightKg!)}×${x.reps}',
        )
        .join(', ');
    return Container(
      key: ValueKey('lift.session.${s.sessionId}'),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm + 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      ProgressScreen.date(s.date),
                      style: textTheme.titleSmall,
                    ),
                    if (s.record) ...<Widget>[
                      const SizedBox(width: FitSpacing.sm),
                      Container(
                        key: ValueKey('lift.record.${s.sessionId}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: FitColors.accent,
                          borderRadius: BorderRadius.all(FitRadius.small),
                        ),
                        child: Text(
                          'Record',
                          style: textTheme.labelSmall
                              ?.copyWith(color: FitColors.onAccent),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(sets, style: muted),
              ],
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (s.estimated1RmKg != null)
                Text(
                  '${ProgressScreen.kg(s.estimated1RmKg!)} kg',
                  style: textTheme.titleMedium,
                )
              else
                Text('${s.reps} reps', style: textTheme.titleMedium),
              Text(
                s.estimated1RmKg != null
                    ? 'est. 1RM · ${s.volumeKg.round()} kg moved'
                    : 'bodyweight',
                style: muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The estimate over time: a line with a dot per session, filled on a
/// record. Ink only, as the weight chart (§17 rule 4), the record dots in
/// the accent.
class _E1rmPainter extends CustomPainter {
  _E1rmPainter({
    required this.values,
    required this.records,
    required this.line,
    required this.record,
    required this.grid,
  });

  final List<double> values;
  final List<bool> records;
  final Color line;
  final Color record;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = hi - lo < 1 ? 1.0 : hi - lo;
    const pad = 8.0;
    Offset at(int i) => Offset(
          pad +
              (size.width - 2 * pad) *
                  (values.length == 1 ? 0.5 : i / (values.length - 1)),
          pad + (size.height - 2 * pad) * (1 - (values[i] - lo) / span),
        );
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final y in [pad, size.height / 2, size.height - pad]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(
        at(i),
        records[i] ? 4.5 : 3,
        Paint()..color = records[i] ? record : line,
      );
    }
  }

  @override
  bool shouldRepaint(_E1rmPainter old) =>
      old.values != values || old.line != line || old.record != record;
}
