import 'weekly_report_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/routing/router.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../../core/theme/tokens.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/domain/home_suggestion_engine.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../home/presentation/widgets/home_sections.dart';
import '../../recovery/presentation/recovery_panel.dart';
import '../../recovery/presentation/recovery_providers.dart';
import '../../workout/domain/entities/workout.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../../workout/presentation/screens/volume_screen.dart';
import '../domain/progress.dart';
import 'progress_providers.dart';
import 'progress_sheets.dart';
import 'trend_chart.dart';
import '../../../core/config/app_features.dart';
import 'photos/progress_photos_screen.dart';

/// Progress & Recovery (Phase 12; redesigned at the owner's request during the
/// Phase 13 S24 run). What the server computed from the user's own records,
/// over 30 or 90 days, in sections that read top to bottom:
///
///   Weight — the trend weight is the headline, raw readings small and faint
///   Recovery — today's check-in and readiness, then the phone's own context
///   Body measurements · Strength · Training · Nutrition
///   Records — collapsed at the bottom
///
/// No number is computed here; no day-over-day figure; no red for a single
/// day (§17). Athletic Editorial (§6): sections divided by hairlines, metric
/// tiles with big numbers, colour only where it means something.
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
      ..invalidate(recoveryTodayProvider)
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
      body: FitBackdrop(
        child: SafeArea(
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
                        style: textTheme.displaySmall,
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
                      const SizedBox(height: FitSpacing.md),
                      // Phase 19 (ADR-027): the weekly report, premium.
                      const WeeklyReportEntry(),
                    ],
                  ),
                ),
                if (_status(ref, view) case final line?)
                  _Pad(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: FitSpacing.md),
                      child: _Note(
                        line.$2,
                        textKey: ValueKey(line.$1),
                        icon: Icons.cloud_off_outlined,
                      ),
                    ),
                  ),
                if (async.isLoading && s == null)
                  Padding(
                    padding: const EdgeInsets.all(FitSpacing.screen),
                    child: LinearProgressIndicator(
                      key: const ValueKey('progress.loading'),
                      color: FitColors.ink,
                      backgroundColor: FitColors.paper2,
                    ),
                  ),
                if (s != null) ...<Widget>[
                  const _SectionHeader('Weight'),
                  _Card(child: _WeightSection(summary: s)),
                ],
                // Beta 3.4 (ADR-035): photos, kept on this phone only.
                if (ref.watch(
                  featureOnProvider(AppFeature.progressPhotos),
                )) ...<Widget>[
                  const _SectionHeader('Photos'),
                  const _Card(child: ProgressPhotosCard()),
                ],
                const _SectionHeader(
                  'Recovery',
                  sub: 'Check in daily — readiness is worked out from it.',
                ),
                const _Card(child: _RecoverySection()),
                if (s != null) ...<Widget>[
                  const _SectionHeader('Body measurements'),
                  _Card(child: _MeasurementSection(summary: s)),
                  const _SectionHeader(
                    'Strength',
                    sub: 'Best estimated one-rep max per lift, this period.',
                  ),
                  _Card(child: _StrengthSection(summary: s)),
                  const _SectionHeader('Training'),
                  _Card(child: _ConsistencySection(summary: s)),
                  const SizedBox(height: FitSpacing.md),
                ] else
                  const _SectionHeader('Training'),
                const _Card(child: _VolumeHeatmap()),
                if (s != null) ...<Widget>[
                  const _SectionHeader(
                    'Nutrition',
                    sub:
                        'Only days with food logged count — a day without a log is not a miss.',
                  ),
                  _Card(child: _AdherenceSection(summary: s)),
                  _RecordsSection(summary: s),
                ],
              ],
            ),
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

/* -------------------------------------------------------------- building -- */

/// §6.2: corners of 2 px and an ink outline for this page's secondary buttons.
// A getter: built on each read, so it follows the palette.
ButtonStyle get _squareOutline => OutlinedButton.styleFrom(
      foregroundColor: FitColors.ink,
      side: BorderSide(color: FitColors.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(FitRadius.small),
      ),
      minimumSize: const Size.fromHeight(44),
    );

class _Pad extends StatelessWidget {
  const _Pad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: fitGlass ? FitSpacing.md : FitSpacing.screen,
        ),
        child: child,
      );
}

/// ADR-029: a section's body in a rounded block; nothing extra on Paper.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FitBlock(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
        child: child,
      );
}

/// §6.4: a section starts with a hairline, 14 px, then its label.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.sub});

  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const FitRule(),
          SizedBox(height: fitGlass ? FitSpacing.sm : FitSpacing.afterRule),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fitGlass ? 20 : FitSpacing.screen,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: FitColors.ink,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: fitGlass ? FitSpacing.sm : FitSpacing.md),
        ],
      ),
    );
  }
}

/// A metric tile: label, the number as the hero, one line of context.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    this.valueKey,
    this.captionKey,
    this.muted = false,
    this.bar,
  });

  final String label;
  final String value;
  final String caption;
  final Key? valueKey;
  final Key? captionKey;

  /// A quieter value (a message rather than a number).
  final bool muted;

  /// A 0–1 share drawn as a thin bar under the value (adherence).
  final double? bar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: fitGlass ? 14 : FitSpacing.screen,
        vertical: fitGlass ? 12 : FitSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          if (muted)
            Text(
              value,
              key: valueKey,
              style: textTheme.titleMedium?.copyWith(color: FitColors.ink60),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          else
            // A number shrinks to fit its tile ("−0.4 kg / week") rather
            // than ending in an ellipsis.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                style: textTheme.displaySmall,
                maxLines: 1,
              ),
            ),
          if (bar != null) ...<Widget>[
            const SizedBox(height: FitSpacing.sm),
            _Bar(bar!),
          ],
          const SizedBox(height: FitSpacing.xs),
          Text(
            caption,
            key: captionKey,
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

/// Two tiles a row, divided by hairlines (the Home grid).
class _StatGrid extends StatelessWidget {
  const _StatGrid(this.tiles);

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => FitTileGrid(
        tiles: tiles,
        margin: const EdgeInsets.symmetric(horizontal: FitSpacing.md),
      );
}

/// A thin share bar: pine fill (on track, §6.2) on the recessed paper.
class _Bar extends StatelessWidget {
  const _Bar(this.share);

  final double share;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.all(FitRadius.small),
        child: LinearProgressIndicator(
          value: share.clamp(0, 1),
          minHeight: 6,
          color: FitColors.pine,
          backgroundColor: FitColors.paper2,
        ),
      );
}

/// A quiet explanatory line with an icon.
class _Note extends StatelessWidget {
  const _Note(this.text, {this.textKey, this.icon = Icons.info_outline});

  final String text;

  /// On the text itself, so it can be found and read.
  final Key? textKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: FitColors.ink60),
        ),
        const SizedBox(width: FitSpacing.sm),
        Expanded(
          child: Text(
            text,
            key: textKey,
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ),
      ],
    );
  }
}

/// A recessed panel for instructions (empty and sparse states, §6.6).
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.body, this.panelKey});

  final String title;
  final String body;
  final Key? panelKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: panelKey,
      width: double.infinity,
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: BoxDecoration(
        color: fitGlass
            ? FitColors.ink.withValues(alpha: 0.045)
            : FitColors.paper2,
        borderRadius: BorderRadius.all(FitRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: FitSpacing.xs),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
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
    final enough = w.points.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Pad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (w.currentTrendKg == null)
                const _Panel(
                  panelKey: ValueKey('progress.weight.empty'),
                  title: 'No weight logged yet',
                  body:
                      'Log your weight and the trend starts here. A few readings a week, on different days, is plenty.',
                )
              else ...<Widget>[
                // §13.2: the trend is the headline; the raw reading is small below it.
                Text(
                  '${ProgressScreen.kg(w.currentTrendKg!)} kg',
                  key: const ValueKey('progress.weight.trend'),
                  style: textTheme.displayMedium,
                ),
                Text(
                  'Trend weight',
                  style:
                      textTheme.titleMedium?.copyWith(color: FitColors.ink60),
                ),
                if (latest != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Latest reading ${ProgressScreen.kg(latest.rawKg)} kg on ${ProgressScreen.date(latest.date)}',
                      key: const ValueKey('progress.weight.raw'),
                      style:
                          textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                    ),
                  ),
              ],
            ],
          ),
        ),
        // With one reading the panel below says it all; the tiles wait for two.
        if (w.currentTrendKg != null && enough) ...<Widget>[
          const SizedBox(height: FitSpacing.md),
          _StatGrid([
            w.weeklyChangeKg == null
                ? _Stat(
                    label: 'Weekly rate',
                    value: 'After 10 days of readings',
                    caption: '${w.daysOfData} so far',
                    valueKey: const ValueKey('progress.weight.rate'),
                    muted: true,
                  )
                : _Stat(
                    label: 'Weekly rate',
                    value:
                        '${ProgressScreen.signed(w.weeklyChangeKg!, 'kg')} / week',
                    caption: 'From the trend',
                    valueKey: const ValueKey('progress.weight.rate'),
                  ),
            w.windowChangeKg == null
                ? const _Stat(
                    label: 'Change',
                    value: 'Once readings span 7 days',
                    caption: 'Never day to day',
                    muted: true,
                  )
                : _Stat(
                    label: 'Change',
                    value: ProgressScreen.signed(w.windowChangeKg!, 'kg'),
                    caption: 'Over ${w.windowChangeDays} days',
                    valueKey: const ValueKey('progress.weight.change'),
                  ),
          ]),
          const SizedBox(height: FitSpacing.md),
          _Pad(
            child: TrendChart(
              points: w.points,
              from: summary.from,
              to: summary.today,
              height: 200,
            ),
          ),
        ],
        if (w.currentTrendKg != null && !enough) ...<Widget>[
          const SizedBox(height: FitSpacing.md),
          const _Pad(
            child: _Panel(
              panelKey: ValueKey('progress.weight.sparse'),
              title: 'Your trend line starts with the next reading',
              body:
                  'One reading so far. Weigh in on a few different days and the line appears here, smoothing out the daily ups and downs.',
            ),
          ),
        ],
        const SizedBox(height: FitSpacing.md),
        _Pad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Note(
                ProgressScreen.fluctuation,
                textKey: ValueKey('progress.weight.fluctuation'),
              ),
              if (device != null && device.isAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.xs),
                  child: Text(
                    // Owner D10: device data, never part of the trend.
                    'Health Connect: ${ProgressScreen.kg(device.value!)} kg · on this phone, not in the trend',
                    key: const ValueKey('progress.weight.healthConnect'),
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                  ),
                ),
              const SizedBox(height: FitSpacing.md),
              FilledButton.icon(
                key: const ValueKey('progress.weight.log'),
                onPressed: () => showWeightSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log weight'),
              ),
            ],
          ),
        ),
      ],
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
    final present = {for (final m in summary.measurements) m.site};
    final missing =
        MeasurementSite.values.where((s) => !present.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (summary.measurements.isEmpty)
          const _Pad(
            child: _Panel(
              panelKey: ValueKey('progress.measurements.empty'),
              title: 'No measurements yet',
              body:
                  'Waist, chest, arm, thigh and hip. Once a week, at the same time of day, is enough to see a change.',
            ),
          )
        else ...<Widget>[
          _StatGrid([
            for (final m in summary.measurements)
              _Stat(
                label: m.site.label,
                value: '${ProgressScreen.kg(m.latestCm)} cm',
                caption: m.changeCm == null
                    ? 'Change shows after 7 days'
                    : '${ProgressScreen.signed(m.changeCm!, 'cm')} over ${m.changeDays} days',
                valueKey: ValueKey('progress.measurement.${m.site.wire}'),
                captionKey:
                    ValueKey('progress.measurement.${m.site.wire}.change'),
              ),
          ]),
          if (missing.isNotEmpty)
            _Pad(
              child: Padding(
                padding: const EdgeInsets.only(top: FitSpacing.sm),
                child: Text(
                  'Not measured yet: ${missing.map((s) => s.label.toLowerCase()).join(', ')}',
                  key: const ValueKey('progress.measurement.missing'),
                  style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                ),
              ),
            ),
        ],
        const SizedBox(height: FitSpacing.md),
        _Pad(
          child: OutlinedButton.icon(
            key: const ValueKey('progress.measurement.log'),
            style: _squareOutline,
            onPressed: () => showMeasurementSheet(context),
            icon: const Icon(Icons.straighten, size: 18),
            label: const Text('Add measurement'),
          ),
        ),
      ],
    );
  }
}

/* --------------------------------------------------------------- strength -- */

class _StrengthSection extends StatefulWidget {
  const _StrengthSection({required this.summary});

  final ProgressSummary summary;

  /// Lifts shown before "Show all".
  static const shown = 5;

  @override
  State<_StrengthSection> createState() => _StrengthSectionState();
}

class _StrengthSectionState extends State<_StrengthSection> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lifts = widget.summary.bestLifts;
    if (lifts.isEmpty) {
      return const _Pad(
        child: _Panel(
          panelKey: ValueKey('progress.strength.empty'),
          title: 'No loaded sets this period',
          body: 'Log a session with weights and your best lifts show here.',
        ),
      );
    }
    final visible = _all ? lifts : lifts.take(_StrengthSection.shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final b in visible) ...<Widget>[
          if (!fitGlass || b != visible.first)
            Divider(
              color: FitColors.rule,
              height: 1,
              indent: fitGlass ? FitSpacing.md : 0,
              endIndent: fitGlass ? FitSpacing.md : 0,
            ),
          _Pad(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm + 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(b.exerciseName, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'From ${ProgressScreen.kg(b.weightKg)} kg × ${b.reps} · ${ProgressScreen.date(b.date)}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: FitColors.ink60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${ProgressScreen.kg(b.estimated1RmKg)} kg',
                        key: ValueKey('progress.best.${b.exerciseId}'),
                        style: textTheme.displaySmall,
                      ),
                      Text(
                        'est. 1RM',
                        style: textTheme.bodySmall
                            ?.copyWith(color: FitColors.ink60),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const FitRule(),
        if (lifts.length > _StrengthSection.shown)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: FitSpacing.sm),
              child: TextButton(
                key: const ValueKey('progress.strength.more'),
                onPressed: () => setState(() => _all = !_all),
                child: Text(
                  _all ? 'Show fewer' : 'Show all ${lifts.length} lifts',
                ),
              ),
            ),
          ),
        _Pad(
          child: Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: Text(
              'Estimated 1RM (Epley) is a guide, not a target.',
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
            ),
          ),
        ),
      ],
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
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final Widget body;
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
              padding: const EdgeInsets.symmetric(vertical: 1),
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
          const SizedBox(height: FitSpacing.sm),
          Wrap(
            spacing: FitSpacing.md,
            runSpacing: FitSpacing.xs,
            children: <Widget>[
              for (final s in LandmarkStatus.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(width: 14, child: _Cell(status: s, height: 10)),
                    const SizedBox(width: FitSpacing.xs),
                    Text(VolumeWording.label(s), style: muted),
                  ],
                ),
            ],
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'Oldest week on the left; this week on the right.',
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.lg),
      child: _Pad(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'WEEKLY VOLUME PER MUSCLE',
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: FitSpacing.sm),
            body,
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('progress.volume.open'),
                onPressed: () => context.push(Routes.volume),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text('Training volume')),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.status, this.height = 18, super.key});

  final LandmarkStatus status;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
        label: VolumeWording.label(status),
        child: Container(
          height: height,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: status == LandmarkStatus.none
                ? null
                : VolumeWording.color(status).withValues(alpha: 0.8),
            border: Border.all(color: FitColors.rule),
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
        ),
      );
}

/* ------------------------------------------------------------- adherence -- */

class _AdherenceSection extends StatelessWidget {
  const _AdherenceSection({required this.summary});

  final ProgressSummary summary;

  static _Stat _tile(String label, AdherenceCount c, String key) => c.of == 0
      ? _Stat(
          label: label,
          value: '—',
          caption: 'No logged days with a target yet',
          valueKey: ValueKey(key),
          captionKey: ValueKey('$key.days'),
          muted: true,
        )
      : _Stat(
          label: label,
          value: c.percent == null ? '${c.met}/${c.of}' : '${c.percent}%',
          caption: '${c.met} of ${c.of} logged days',
          valueKey: ValueKey(key),
          captionKey: ValueKey('$key.days'),
          bar: c.met / c.of,
        );

  @override
  Widget build(BuildContext context) {
    final a = summary.adherence;
    return _StatGrid([
      _tile('Protein target met', a.protein, 'progress.adherence.protein'),
      _tile('Calories on target', a.calories, 'progress.adherence.calories'),
    ]);
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
          Text('SESSIONS', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text(
            c.planned == null
                ? '${c.completed}'
                : '${c.completed} / ${c.planned}',
            key: const ValueKey('progress.consistency'),
            style: textTheme.displaySmall,
          ),
          Text(
            c.planned == null
                ? 'Completed · no programme to compare'
                : 'Planned sessions done${c.percent == null ? '' : ' · ${c.percent}%'}',
            key: const ValueKey('progress.consistency.caption'),
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
          if (c.planned != null && c.weeks.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            Wrap(
              spacing: FitSpacing.md,
              runSpacing: FitSpacing.sm,
              children: <Widget>[
                for (final w in c.weeks) _WeekDots(week: w),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One ISO week: a square per planned session — filled when done (no red
/// for a missed one, §17 rule 4). At most [maxSquares] squares; sessions
/// beyond them are a "+N" (found on the S24: 24 sessions in a 4-session week
/// drew 24 squares and overflowed the row).
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.week});

  final WeekConsistency week;

  static const maxSquares = 7;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final squares =
        (week.planned > 0 ? week.planned : week.completed).clamp(0, maxSquares);
    final filled = week.completed.clamp(0, squares);
    final extra = week.completed - filled;
    return Semantics(
      label:
          'Week ${week.isoWeek.substring(6)}: ${week.completed} of ${week.planned} sessions',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < squares; i++)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: i < filled ? FitColors.ink : null,
                      border: Border.all(
                        color: i < filled ? FitColors.ink : FitColors.rule,
                      ),
                      borderRadius: BorderRadius.all(FitRadius.small),
                    ),
                  ),
                if (extra > 0)
                  Text(
                    '+$extra',
                    key: ValueKey('progress.consistency.${week.isoWeek}.extra'),
                    style: textTheme.bodySmall?.copyWith(
                      color: FitColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (squares == 0 && extra == 0)
                  Text('—', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${week.isoWeek.substring(5)} ${week.completed}/${week.planned}',
              key: ValueKey('progress.consistency.${week.isoWeek}'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------------------------------------- records -- */

/// Records this period, collapsed by default at the bottom (owner, S24 run):
/// they are worth keeping, not worth the top of the page.
class _RecordsSection extends StatefulWidget {
  const _RecordsSection({required this.summary});

  final ProgressSummary summary;

  @override
  State<_RecordsSection> createState() => _RecordsSectionState();
}

class _RecordsSectionState extends State<_RecordsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final prs = widget.summary.prs;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.lg),
      child: FitBlock(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const FitRule(),
            InkWell(
              key: const ValueKey('progress.records.toggle'),
              onTap: prs.isEmpty ? null : () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitSpacing.screen,
                  vertical: FitSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'RECORDS',
                            style: textTheme.labelSmall?.copyWith(
                              color: FitColors.ink,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prs.isEmpty
                                ? 'No records this period'
                                : '${prs.length} ${prs.length == 1 ? 'record' : 'records'} this period',
                            key: const ValueKey('progress.records.count'),
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    if (prs.isNotEmpty)
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        color: FitColors.ink60,
                        semanticLabel: _open ? 'Hide records' : 'Show records',
                      ),
                  ],
                ),
              ),
            ),
            if (_open)
              for (final p in prs) ...<Widget>[
                Divider(
                  color: FitColors.rule,
                  height: 1,
                  indent: FitSpacing.screen,
                ),
                Padding(
                  key: ValueKey('progress.pr.${p.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FitSpacing.screen,
                    vertical: FitSpacing.sm + 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.emoji_events_outlined,
                          size: 18,
                          color: FitColors.pine,
                        ),
                      ),
                      const SizedBox(width: FitSpacing.sm),
                      Expanded(
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
                  ),
                ),
              ],
            const FitRule(),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------- recovery -- */

/// Recovery: Phase 13's check-in and the server's readiness (ADR-019), then
/// the phone's own context — Health Connect's sleep and resting heart rate,
/// or the check-in's sleep when Health Connect has none. Health Connect data
/// is never sent to the server and never part of readiness (owner D1).
class _RecoverySection extends ConsumerWidget {
  const _RecoverySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final c = ref.watch(homeContextProvider);
    final checkIn = ref.watch(recoveryTodayProvider).value?.today;
    final sleep = c.health?.sleep;
    final short = sleep != null &&
        sleep.isAvailable &&
        sleep.value! < HomeSuggestionEngine.lowSleepMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const RecoveryPanel(),
        const SizedBox(height: FitSpacing.lg),
        _Pad(
          child: Text(
            'SLEEP & RESTING HEART RATE',
            style: textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: FitSpacing.sm),
        // Readiness is just above: here only sleep and heart rate.
        RecoverySection(context: c, checkIn: checkIn, showReadiness: false),
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
                  ? 'Health Connect did not answer just now; the last reading kept on this phone is shown. Not part of readiness.'
                  : 'Health Connect stays on this phone. Information only — not part of readiness.',
              key: const ValueKey('progress.recovery.note'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
            ),
          ),
        ),
      ],
    );
  }
}
