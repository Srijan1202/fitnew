import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/domain/home_suggestion_engine.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../home/presentation/widgets/home_sections.dart';
import '../../workout/domain/entities/workout.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../../workout/presentation/screens/volume_screen.dart';
import '../domain/progress.dart';
import 'progress_providers.dart';
import 'progress_sheets.dart';
import 'trend_chart.dart';

/// Phase 12 — Progress & Recovery (the tab that replaced Market). What the
/// server computed from the user's own records, over 30 or 90 days: the
/// trend weight (the headline), measurements, records and estimated 1RM,
/// the training-volume heatmap, protein and calorie adherence, training
/// consistency — and, from this phone only, sleep and resting heart rate.
/// No number is computed here; no score; no day-over-day figure (§17).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  /// §17 rule 3: the copy that explains fluctuation.
  static const fluctuation =
      'Day-to-day changes are water and food weight. The trend is the signal.';

  static String kg(double v) => v.toStringAsFixed(1);

  static String signed(double v, String unit) =>
      '${v > 0 ? '+' : v < 0 ? '−' : '±'}${v.abs().toStringAsFixed(1)} $unit';

  static String date(String iso) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day} ${months[d.month - 1]}';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(progressSummaryProvider)
      ..invalidate(volumeProvider);
    await ref.read(healthSnapshotProvider.notifier).refreshAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final window = ref.watch(progressWindowProvider);
    final async = ref.watch(progressSummaryProvider(window));
    final view = async.value;
    final s = view?.summary;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: FitColors.ink,
          onRefresh: () => _refresh(ref),
          child: ListView(
            key: const ValueKey('progress.list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 112),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.lg,
                  FitSpacing.screen,
                  FitSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('PROGRESS', style: textTheme.labelSmall),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      'Progress & Recovery',
                      key: const ValueKey('progress.title'),
                      style: textTheme.displayMedium,
                    ),
                    const SizedBox(height: FitSpacing.md),
                    SegmentedButton<ProgressWindow>(
                      key: const ValueKey('progress.window'),
                      segments: [
                        for (final w in ProgressWindow.values)
                          ButtonSegment(
                            value: w,
                            label: Text(
                              w.label,
                              key: ValueKey('progress.window.${w.wire}'),
                            ),
                          ),
                      ],
                      selected: {window},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => ref
                          .read(progressWindowProvider.notifier)
                          .set(v.first),
                    ),
                  ],
                ),
              ),
              if (_status(ref, view) case final line?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FitSpacing.screen,
                    0,
                    FitSpacing.screen,
                    FitSpacing.md,
                  ),
                  child: Text(
                    line.$2,
                    key: ValueKey(line.$1),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ),
              if (async.isLoading && s == null)
                const Padding(
                  padding: EdgeInsets.all(FitSpacing.screen),
                  child: LinearProgressIndicator(
                    key: ValueKey('progress.loading'),
                    color: FitColors.ink,
                  ),
                ),
              if (s != null) ...<Widget>[
                const SectionLabel('Weight'),
                _WeightSection(summary: s),
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('Measurements'),
                _MeasurementSection(summary: s),
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('Strength'),
                _StrengthSection(summary: s),
              ],
              const SizedBox(height: FitSpacing.lg),
              const SectionLabel('Training volume'),
              const _VolumeHeatmap(),
              if (s != null) ...<Widget>[
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('Nutrition'),
                _AdherenceSection(summary: s),
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('Training consistency'),
                _ConsistencySection(summary: s),
              ],
              const SizedBox(height: FitSpacing.lg),
              const SectionLabel('Recovery'),
              const _RecoverySection(),
            ],
          ),
        ),
      ),
    );
  }

  /// The honest line when the summary is not live: cached (with its time) or unavailable.
  static (String, String)? _status(WidgetRef ref, ProgressView? view) {
    if (view == null) return null;
    switch (view.source) {
      case ProgressSource.live:
        return null;
      case ProgressSource.cached:
        final at = DateTime.tryParse(view.storedAt ?? '');
        final zone = ref.watch(userTimezoneProvider);
        final local =
            at == null ? null : tz.TZDateTime.from(at, userLocation(zone));
        final when = local == null
            ? ''
            : ' from ${date(local.toIso8601String().substring(0, 10))}, '
                '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        return (
          'progress.cached',
          '${view.offline ? 'Offline' : 'Not updated'} — showing your progress$when. Logging needs a connection.',
        );
      case ProgressSource.unavailable:
        return (
          'progress.unavailable',
          view.offline
              ? 'Progress needs a connection.'
              : 'Progress is unavailable right now.',
        );
    }
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
        child: child,
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          Flexible(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- weight -- */

class _WeightSection extends ConsumerWidget {
  const _WeightSection({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final w = summary.weight;
    final device = ref.watch(healthSnapshotProvider).value?.weight;
    final latest = w.points.isEmpty ? null : w.points.last;
    return _Pad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (w.currentTrendKg == null)
            Text(
              'No weight logged yet',
              key: const ValueKey('progress.weight.empty'),
              style: textTheme.displaySmall,
            )
          else ...<Widget>[
            // §13.2: the trend is the headline; the raw reading is small below it.
            Text(
              '${ProgressScreen.kg(w.currentTrendKg!)} kg',
              key: const ValueKey('progress.weight.trend'),
              style: textTheme.displayLarge,
            ),
            Text(
              'Trend weight',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            if (latest != null)
              Text(
                'Latest reading ${ProgressScreen.kg(latest.rawKg)} kg on ${ProgressScreen.date(latest.date)}',
                key: const ValueKey('progress.weight.raw'),
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
              ),
          ],
          const SizedBox(height: FitSpacing.sm),
          _Line(
            'Weekly rate',
            w.weeklyChangeKg == null
                ? 'After 10 days of readings (${w.daysOfData} so far)'
                : '${ProgressScreen.signed(w.weeklyChangeKg!, 'kg')} / week',
            valueKey: const ValueKey('progress.weight.rate'),
          ),
          if (w.windowChangeKg != null)
            _Line(
              'Over ${w.windowChangeDays} days',
              ProgressScreen.signed(w.windowChangeKg!, 'kg'),
              valueKey: const ValueKey('progress.weight.change'),
            ),
          const SizedBox(height: FitSpacing.sm),
          TrendChart(points: w.points, from: summary.from, to: summary.today),
          const SizedBox(height: FitSpacing.sm),
          Text(
            ProgressScreen.fluctuation,
            key: const ValueKey('progress.weight.fluctuation'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          if (device != null && device.isAvailable)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.xs),
              child: Text(
                // Owner D10: device data, never part of the trend.
                'Health Connect: ${ProgressScreen.kg(device.value!)} kg · on this phone, not in the trend',
                key: const ValueKey('progress.weight.healthConnect'),
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
              ),
            ),
          const SizedBox(height: FitSpacing.sm),
          OutlinedButton(
            key: const ValueKey('progress.weight.log'),
            onPressed: () => showWeightSheet(context),
            child: const Text('Log weight'),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------- measurements -- */

class _MeasurementSection extends StatelessWidget {
  const _MeasurementSection({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Pad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (summary.measurements.isEmpty)
            Text(
              'No measurements yet.',
              key: const ValueKey('progress.measurements.empty'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          for (final m in summary.measurements)
            _Line(
              m.site.label,
              '${ProgressScreen.kg(m.latestCm)} cm'
              '${m.changeCm == null ? '' : ' · ${ProgressScreen.signed(m.changeCm!, 'cm')} over ${m.changeDays} days'}',
              valueKey: ValueKey('progress.measurement.${m.site.wire}'),
            ),
          const SizedBox(height: FitSpacing.sm),
          OutlinedButton(
            key: const ValueKey('progress.measurement.log'),
            onPressed: () => showMeasurementSheet(context),
            child: const Text('Log measurement'),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------------- strength -- */

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    return _Pad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (summary.bestLifts.isEmpty && summary.prs.isEmpty)
            Text(
              'No loaded sets in this window yet.',
              key: const ValueKey('progress.strength.empty'),
              style: muted,
            ),
          for (final b in summary.bestLifts)
            _Line(
              b.exerciseName,
              'Est. 1RM ${ProgressScreen.kg(b.estimated1RmKg)} kg (${ProgressScreen.kg(b.weightKg)} × ${b.reps})',
              valueKey: ValueKey('progress.best.${b.exerciseId}'),
            ),
          if (summary.prs.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.sm),
            Text('Records', style: textTheme.titleMedium),
            for (final p in summary.prs)
              Padding(
                key: ValueKey('progress.pr.${p.id}'),
                padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${p.exerciseName} · ${ProgressScreen.date(p.achievedOn)}',
                      style: textTheme.bodyMedium,
                    ),
                    Text(p.reason, style: muted),
                  ],
                ),
              ),
          ],
          Text(
            'Estimated 1RM (Epley) is a guide, not a target.',
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- volume -- */

/// The same weeks, statuses and words as the Volume screen (reused, not recomputed).
class _VolumeHeatmap extends ConsumerWidget {
  const _VolumeHeatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final v = ref.watch(volumeProvider).value;
    final muted = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    Widget body;
    if (v == null || v.weeks.isEmpty || v.owned.isEmpty) {
      body = Text(
        'No training volume yet.',
        key: const ValueKey('progress.volume.empty'),
        style: muted,
      );
    } else {
      final weeks = v.weeks;
      body = Column(
        key: const ValueKey('progress.volume'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final muscle in v.owned)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Text(
                      muscle.label,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final (i, w) in weeks.indexed)
                    Expanded(
                      flex: 2,
                      child: _Cell(
                        key: ValueKey('progress.volume.${muscle.wire}.$i'),
                        status: w.muscles
                                .where((m) => m.muscle == muscle)
                                .firstOrNull
                                ?.status ??
                            LandmarkStatus.none,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'Oldest week on the left; this week on the right.',
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
          ),
        ],
      );
    }
    return _Pad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          body,
          const SizedBox(height: FitSpacing.sm),
          OutlinedButton(
            key: const ValueKey('progress.volume.open'),
            onPressed: () => context.push(Routes.volume),
            child: const Text('Training volume →'),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.status, super.key});

  final LandmarkStatus status;

  @override
  Widget build(BuildContext context) => Semantics(
        label: VolumeWording.label(status),
        child: Container(
          height: 18,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: status == LandmarkStatus.none
                ? null
                : VolumeWording.color(status).withValues(alpha: 0.8),
            border: Border.all(color: FitColors.rule),
            borderRadius: const BorderRadius.all(FitRadius.small),
          ),
        ),
      );
}

/* ------------------------------------------------------------- adherence -- */

class _AdherenceSection extends StatelessWidget {
  const _AdherenceSection({required this.summary});

  final ProgressSummary summary;

  static String _count(AdherenceCount c) => c.of == 0
      ? 'No logged days with a target yet'
      : '${c.met} of ${c.of} logged days${c.percent == null ? '' : ' · ${c.percent}%'}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final a = summary.adherence;
    return _Pad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Line(
            'Protein target met',
            _count(a.protein),
            valueKey: const ValueKey('progress.adherence.protein'),
          ),
          _Line(
            'Calories on target (±10%)',
            _count(a.calories),
            valueKey: const ValueKey('progress.adherence.calories'),
          ),
          Text(
            'Only days with food logged count; a day without a log is not a miss.',
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------- consistency -- */

class _ConsistencySection extends StatelessWidget {
  const _ConsistencySection({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = summary.consistency;
    return _Pad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Line(
            'Sessions',
            c.planned == null
                ? '${c.completed} completed · no programme to compare'
                : '${c.completed} of ${c.planned} planned${c.percent == null ? '' : ' · ${c.percent}%'}',
            valueKey: const ValueKey('progress.consistency'),
          ),
          if (c.planned != null)
            Wrap(
              spacing: FitSpacing.sm,
              runSpacing: FitSpacing.xs,
              children: <Widget>[
                for (final w in c.weeks)
                  Text(
                    '${w.isoWeek.substring(5)} ${w.completed}/${w.planned}',
                    key: ValueKey('progress.consistency.${w.isoWeek}'),
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------- recovery -- */

/// Phase 12 recovery is information only (owner D1): the phone's Health
/// Connect sleep and resting heart rate — never sent to the server, no
/// score, no readiness (Phase 13).
class _RecoverySection extends ConsumerWidget {
  const _RecoverySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final c = ref.watch(homeContextProvider);
    final sleep = c.health?.sleep;
    final short = sleep != null &&
        sleep.isAvailable &&
        sleep.value! < HomeSuggestionEngine.lowSleepMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RecoverySection(context: c),
        if (short)
          _Pad(
            child: Padding(
              padding: const EdgeInsets.only(top: FitSpacing.sm),
              child: Text(
                'Last night was under six hours. An easy day is a good day.',
                key: const ValueKey('progress.recovery.advisory'),
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        _Pad(
          child: Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: Text(
              c.health?.fromCache ?? false
                  ? 'Health Connect did not answer just now; the last reading kept on this phone is shown. No score.'
                  : 'From Health Connect on this phone; it stays here. Information only — no score.',
              key: const ValueKey('progress.recovery.note'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
            ),
          ),
        ),
      ],
    );
  }
}
