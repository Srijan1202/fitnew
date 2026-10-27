import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';
import '../controllers/run_recorder.dart';
import '../controllers/running_providers.dart';
import '../widgets/route_painter.dart';
import 'run_start.dart';

/// Beta 4.0 (ADR-038): the Running half of Training — start a run, the run
/// in progress, this week and this month, and the history.
class RunningHomeScreen extends ConsumerWidget {
  const RunningHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(runRecorderProvider);
    final history = ref.watch(runHistoryProvider);
    final unit = ref.watch(runSettingsProvider).unit;
    final parked = ref.watch(_parkedProvider).value ?? 0;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: FitSpacing.screen,
        title: Text('Running', style: t.titleMedium),
        actions: [
          IconButton(
            key: const ValueKey('running.settings'),
            tooltip: 'Running settings',
            icon: Icon(Icons.tune, color: FitColors.ink),
            onPressed: () => _settings(context),
          ),
        ],
      ),
      body: FitBackdrop(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(runningRepositoryProvider).sync();
            ref.invalidate(runListProvider);
            await ref.read(runListProvider.future);
          },
          child: ListView(
            key: const ValueKey('running.list'),
            // The tab bar floats over the content (AppShell's extendBody):
            // its height arrives as bottom padding, kept clear here.
            padding: EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (live != null)
                _CurrentRun(run: live, unit: unit)
              else
                FilledButton.icon(
                  key: const ValueKey('running.start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => startRunFlow(context, ref),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start run'),
                ),
              if (parked > 0)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.md),
                  child: Row(
                    key: const ValueKey('running.parked'),
                    children: [
                      Icon(Icons.cloud_off, size: 18, color: FitColors.amber),
                      const SizedBox(width: FitSpacing.sm),
                      Expanded(
                        child: Text(
                          parked == 1
                              ? '1 run change not synced'
                              : '$parked run changes not synced',
                          style: t.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(runningRepositoryProvider)
                            .engine
                            .retryParked(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ...switch (history) {
                AsyncData(:final value) => _history(context, value, unit),
                _ => const [
                    Padding(
                      padding: EdgeInsets.all(FitSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _history(BuildContext context, RunHistory h, DistanceUnit unit) {
    final t = Theme.of(context).textTheme;
    final runs = h.all;
    return [
      const SizedBox(height: FitSpacing.lg),
      Row(
        children: [
          Expanded(
            child: _Totals(
              key: const ValueKey('running.week'),
              label: 'This week',
              totals: h.list?.week ?? RunTotals.zero,
              unit: unit,
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: _Totals(
              key: const ValueKey('running.month'),
              label: 'This month',
              totals: h.list?.month ?? RunTotals.zero,
              unit: unit,
            ),
          ),
        ],
      ),
      if (h.offline)
        Padding(
          padding: const EdgeInsets.only(top: FitSpacing.sm),
          child: Text(
            'Offline: showing what this phone last saw.',
            key: const ValueKey('running.offline'),
            style: t.bodyMedium,
          ),
        ),
      const SizedBox(height: FitSpacing.lg),
      Padding(
        padding: EdgeInsets.only(left: fitGlass ? FitSpacing.sm : 0),
        child: Text('HISTORY', style: t.labelSmall),
      ),
      const SizedBox(height: FitSpacing.sm),
      if (runs.isEmpty)
        FitBlock(
          padding: const EdgeInsets.all(FitSpacing.md),
          child: Text(
            'No runs yet. Your runs show here with their maps, splits and '
            'pace.',
            key: const ValueKey('running.empty'),
            style: t.bodyLarge,
          ),
        )
      else
        for (var i = 0; i < runs.length; i++)
          FitSegment(
            index: i,
            count: runs.length,
            margin: EdgeInsets.zero,
            child: _RunRow(
              run: runs[i],
              unit: unit,
              pending: h.unsynced.any((u) => u.id == runs[i].id),
            ),
          ),
    ];
  }

  void _settings(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        // Above the bottom bar, like the setup sheet.
        useRootNavigator: true,
        showDragHandle: true,
        builder: (_) => const _RunSettingsSheet(),
      );
}

final _parkedProvider = StreamProvider<int>(
  (ref) => ref.watch(runningRepositoryProvider).watchParkedCount(),
);

class _CurrentRun extends StatelessWidget {
  const _CurrentRun({required this.run, required this.unit});

  final LiveRun run;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final finished = run.status == RunStatus.finished;
    final title = switch (run.status) {
      RunStatus.recording => 'Run in progress',
      RunStatus.finished => 'Run finished — not saved yet',
      _ => 'Run paused',
    };
    return FitBlock(
      key: const ValueKey('running.current'),
      glow: true,
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: t.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text(
            '${formatDuration(run.activeSeconds)} · '
            '${run.kind == RunKind.treadmill ? 'treadmill' : '${formatDistance(run.track.distanceM, unit)} ${unit.label}'}',
            style: t.displaySmall,
          ),
          const SizedBox(height: FitSpacing.md),
          FilledButton(
            key: const ValueKey('running.current.open'),
            onPressed: () =>
                context.push(finished ? Routes.runFinish : Routes.runLive),
            child: Text(finished ? 'Save or discard' : 'Back to the run'),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.label,
    required this.totals,
    required this.unit,
    super.key,
  });

  final String label;
  final RunTotals totals;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FitBlock(
      padding: const EdgeInsets.all(FitSpacing.md),
      flatPadding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: t.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatDistance(totals.distanceM, unit)} ${unit.label}',
              style: t.displaySmall,
            ),
          ),
          Text(
            '${totals.runs} ${totals.runs == 1 ? 'run' : 'runs'} · '
            '${formatDuration(totals.durationSeconds)}',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run, required this.unit, required this.pending});

  final RunSummary run;
  final DistanceUnit unit;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final local = run.startedAt.toLocal();
    final day = MaterialLocalizations.of(context).formatMediumDate(local);
    return InkWell(
      key: ValueKey('running.run.${run.id}'),
      onTap: () => context.push(Routes.runDetail(run.id)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FitColors.paper2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: run.outline.length >= 2
                  ? RouteView(
                      segments: [run.outline],
                      strokeWidth: 2,
                      padding: 6,
                    )
                  : Icon(
                      run.kind == RunKind.treadmill
                          ? Icons.directions_run
                          : Icons.route,
                      color: FitColors.ink60,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    run.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium,
                  ),
                  Text(
                    '${formatDistance(run.distanceM, unit)} ${unit.label} · '
                    '${formatDuration(run.durationSeconds)} · '
                    '${formatPace(run.avgPaceSecPerKm, unit)} ${unit.paceLabel}',
                    style: t.bodyMedium?.copyWith(color: FitColors.ink),
                  ),
                  Text(
                    pending ? '$day · not synced yet' : day,
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: FitColors.ink35),
          ],
        ),
      ),
    );
  }
}

class _RunSettingsSheet extends ConsumerWidget {
  const _RunSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(runSettingsProvider);
    final c = ref.read(runSettingsProvider.notifier);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Running settings', style: t.titleLarge),
          const SizedBox(height: FitSpacing.md),
          Text('DISTANCES IN', style: t.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          SegmentedButton<DistanceUnit>(
            key: const ValueKey('running.settings.unit'),
            segments: const [
              ButtonSegment(value: DistanceUnit.km, label: Text('Kilometres')),
              ButtonSegment(value: DistanceUnit.mi, label: Text('Miles')),
            ],
            selected: {s.unit},
            onSelectionChanged: (v) => c.setUnit(v.first),
          ),
          const SizedBox(height: FitSpacing.md),
          SwitchListTile(
            key: const ValueKey('running.settings.autoPause'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-pause'),
            subtitle: const Text(
              'Pauses the timer when you stop, for example at a crossing, '
              'and starts again when you run.',
            ),
            value: s.autoPause,
            onChanged: c.setAutoPause,
          ),
        ],
      ),
    );
  }
}
