import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/config/app_features.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../../shared/widgets/fit_mode_switch.dart';
import '../../health/domain/entities/health.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/domain/home_context.dart';
import '../../home/domain/home_suggestion_engine.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../home/presentation/widgets/home_sections.dart';
import '../../nutrition/presentation/screens/eat_screen.dart';
import '../../recovery/domain/recovery.dart';
import '../../recovery/presentation/recovery_panel.dart';
import '../../recovery/presentation/recovery_providers.dart';
import '../../workout/domain/entities/workout.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../../workout/presentation/screens/volume_screen.dart';
import '../domain/progress.dart';
import 'length_unit.dart';
import 'photos/progress_photos_providers.dart';
import 'photos/progress_photos_screen.dart';
import 'progress_mode.dart';
import 'progress_providers.dart';
import 'progress_sheets.dart';
import 'trend_chart.dart';
import 'weekly_report_entry.dart';

part 'progress_parts.dart';
part 'progress_sections.dart';
part 'progress_start.dart';

/// Progress & Recovery (Phase 12; redesigned during the Phase 13 S24 run and
/// again in beta 3.9, owner-approved). What the server computed from the
/// user's own records, over a week, a month or three:
///
///   Progress — Weight · Strength (with the newest record) · Training ·
///   Nutrition · Body (measurements and photos)
///   Recovery — Today (readiness, or the way into the check-in); what went
///   into readiness; the phone's sleep and heart rate
///
/// A section with nothing to show is not drawn; it is a line in "Get
/// started" instead. No number is computed here; no day-over-day figure; no
/// red for a single day (§17). Athletic Editorial (§6): sections divided by
/// hairlines, metric tiles with big numbers, colour only where it means
/// something.
/// Beta 5.9 (owner): the Nutrition tab — Food · Progress · Recovery, chosen
/// at the top with Training's switch, opening on Food. Food is EAT
/// ([EatScreen]); Progress and Recovery are the parts that were their own tab
/// in beta 5.7. Each part is built the first time it is chosen, then kept.
class NutritionTabScreen extends ConsumerStatefulWidget {
  const NutritionTabScreen({super.key});

  @override
  ConsumerState<NutritionTabScreen> createState() => _NutritionTabScreenState();
}

class _NutritionTabScreenState extends ConsumerState<NutritionTabScreen> {
  final Set<NutritionMode> _built = <NutritionMode>{};

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(nutritionModeProvider);
    _built.add(mode);
    Widget part(NutritionMode m, Widget child) =>
        _built.contains(m) ? child : const SizedBox.shrink();
    return Scaffold(
      body: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                0,
              ),
              child: FitModeSwitch<NutritionMode>(
                key: const ValueKey('nutrition.mode'),
                thumbKey: const ValueKey('nutrition.mode.thumb'),
                value: mode,
                halves: const [
                  FitModeHalf(
                    NutritionMode.food,
                    'Food',
                    Icons.restaurant,
                    key: ValueKey('nutrition.mode.food'),
                  ),
                  FitModeHalf(
                    NutritionMode.progress,
                    'Progress',
                    Icons.insights,
                    key: ValueKey('nutrition.mode.progress'),
                  ),
                  FitModeHalf(
                    NutritionMode.recovery,
                    'Recovery',
                    Icons.self_improvement,
                    key: ValueKey('nutrition.mode.recovery'),
                  ),
                ],
                onChanged: ref.read(nutritionModeProvider.notifier).set,
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: mode.index,
                children: <Widget>[
                  part(NutritionMode.food, const EatScreen()),
                  part(NutritionMode.progress, const _ProgressHalf()),
                  part(NutritionMode.recovery, const _RecoveryHalf()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Progress and Recovery parts' shared copy and helpers.
abstract final class ProgressScreen {
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

  static Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(progressSummaryProvider)
      ..invalidate(recoveryTodayProvider)
      ..invalidate(volumeProvider);
    await ref.read(healthSnapshotProvider.notifier).refreshAll();
  }

  /// The half's small label and title, like Running's "RUNNING / Your runs".
  static Widget _heading(
    BuildContext context,
    String label,
    String title,
    String titleKey,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.xs),
        Text(title, key: ValueKey(titleKey), style: textTheme.displaySmall),
      ],
    );
  }

  /// Every section with something to show, in order; the rest are lines in
  /// "Get started" — first when the page has nothing else, else last.
  static List<Widget> _sections(
    BuildContext context,
    WidgetRef ref,
    ProgressSummary s,
  ) {
    final photosOn = ref.watch(featureOnProvider(AppFeature.progressPhotos));
    final hasPhotos = photosOn &&
        (ref.watch(progressPhotosProvider).value?.isNotEmpty ?? false);
    final volume = ref.watch(volumeProvider).value;
    final hasVolume =
        volume != null && volume.weeks.isNotEmpty && volume.owned.isNotEmpty;

    final c = s.consistency;
    final a = s.adherence;
    final hasWeight = s.weight.currentTrendKg != null;
    final hasStrength = s.bestLifts.isNotEmpty || s.prs.isNotEmpty;
    final hasTraining = c.completed > 0 || (c.planned ?? 0) > 0 || hasVolume;
    final hasNutrition = a.protein.of > 0 || a.calories.of > 0;
    final hasMeasurements = s.measurements.isNotEmpty;
    final hasBody = hasMeasurements || hasPhotos;
    final empty =
        !hasWeight && !hasStrength && !hasTraining && !hasNutrition && !hasBody;
    final start = <_Start>[
      if (!hasWeight) _Start.weight,
      if (!hasTraining) _Start.training,
      if (!hasNutrition) _Start.food,
      if (!hasMeasurements) _Start.measurement,
      if (photosOn && !hasBody) _Start.photo,
    ];
    final getStarted = start.isEmpty
        ? const <Widget>[]
        : <Widget>[
            _SectionHeader(
              empty ? 'Get started' : 'Still to start',
              sub: empty
                  ? 'Each part of this page appears once it has something in it.'
                  : 'Each appears above once it has something in it; training and food count in the period chosen.',
            ),
            _Card(child: _GetStarted(items: start)),
          ];
    return <Widget>[
      if (empty) ...getStarted,
      if (hasWeight) ...<Widget>[
        const _SectionHeader('Weight', sub: 'Trend weight from your readings.'),
        _Card(child: _WeightSection(summary: s)),
      ],
      if (hasStrength) ...<Widget>[
        const _SectionHeader(
          'Strength',
          sub: 'Best estimated one-rep max per lift, this period.',
        ),
        _Card(child: _StrengthSection(summary: s)),
      ],
      if (hasTraining) ...<Widget>[
        const _SectionHeader(
          'Training',
          sub: 'Sessions done against your plan, week by week.',
        ),
        _Card(child: _TrainingSection(summary: s, volume: hasVolume)),
      ],
      if (hasNutrition) ...<Widget>[
        const _SectionHeader(
          'Nutrition',
          sub:
              'Only days with food logged count — a day without a log is not a miss.',
        ),
        _Card(child: _AdherenceSection(summary: s)),
      ],
      if (hasBody) ...<Widget>[
        _SectionHeader(
          'Body',
          sub: photosOn
              ? 'Tape measurements, and photos kept on this phone.'
              : 'Tape measurements.',
        ),
        _Card(child: _BodySection(summary: s, photos: photosOn)),
      ],
      if (!empty) ...getStarted,
    ];
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

/// Progress: the period, the weekly report, then every section with
/// something to show.
class _ProgressHalf extends ConsumerWidget {
  const _ProgressHalf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(progressWindowProvider);
    final async = ref.watch(progressSummaryProvider(window));
    final view = async.value;
    final s = view?.summary;
    return RefreshIndicator(
      color: FitColors.ink,
      onRefresh: () => ProgressScreen._refresh(ref),
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
                ProgressScreen._heading(
                  context,
                  'PROGRESS',
                  'Your progress',
                  'progress.title',
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
                  onSelectionChanged: (v) =>
                      ref.read(progressWindowProvider.notifier).set(v.first),
                ),
                const SizedBox(height: FitSpacing.sm),
                // Phase 19 (ADR-027): the weekly report, premium.
                const WeeklyReportEntry(),
                // Beta 6.1: and the monthly one, as a PDF.
                const SizedBox(height: FitSpacing.xs),
                const WeeklyReportEntry.monthly(),
              ],
            ),
          ),
          if (ProgressScreen._status(ref, view) case final line?)
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
          if (s != null) ...ProgressScreen._sections(context, ref, s),
        ],
      ),
    );
  }
}

/// Recovery: today's check-in and readiness, what went into it, and the
/// phone's sleep and heart rate, or the way to connect Health data.
class _RecoveryHalf extends ConsumerWidget {
  const _RecoveryHalf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = _RecoveryFacts.of(ref);
    return RefreshIndicator(
      color: FitColors.ink,
      onRefresh: () => ProgressScreen._refresh(ref),
      child: ListView(
        key: const ValueKey('recovery.list'),
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
            child: ProgressScreen._heading(
              context,
              'RECOVERY',
              'Your recovery',
              'recovery.title',
            ),
          ),
          // Beta 3.9: the one daily action leads the page.
          const _SectionHeader(
            'Today',
            sub: 'Check in daily — readiness is worked out from it.',
          ),
          const _Card(child: RecoveryPanel()),
          if (recovery.shown) ...<Widget>[
            const _SectionHeader(
              'Recovery',
              sub:
                  "What went into today's readiness, and this phone's sleep and heart rate.",
            ),
            _Card(child: _RecoveryDetails(facts: recovery)),
          ] else if (recovery.canConnect) ...<Widget>[
            const _SectionHeader(
              'Still to start',
              sub: 'Sleep and heart rate appear here once connected.',
            ),
            const _Card(child: _GetStarted(items: [_Start.health])),
          ],
        ],
      ),
    );
  }
}
