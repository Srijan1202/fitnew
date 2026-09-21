import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';
import '../widgets/deload_panel.dart';

/// Phase 6, owner 12.8: weekly hard sets per muscle against the §12.3
/// landmarks for the current ISO week and the three before it. Ten
/// muscles down, four weeks across; the current week's status in words.
/// Status as a thin left rule (plan §6): oxide below MV, amber below MEV,
/// ink in MEV–MAV, amber above MAV, oxide at MRV — no colour fills. Every
/// number is the server's; the phone only lays it out.
class VolumeScreen extends ConsumerWidget {
  const VolumeScreen({super.key});

  static String _sets(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static Color statusColor(LandmarkStatus s) => switch (s) {
        LandmarkStatus.belowMv || LandmarkStatus.atMrv => FitColors.oxide,
        LandmarkStatus.belowMev || LandmarkStatus.aboveMav => FitColors.amber,
        LandmarkStatus.mevToMav => FitColors.ink,
        LandmarkStatus.none => FitColors.ink35,
      };

  static String statusLine(MuscleWeek m) => switch (m.status) {
        LandmarkStatus.none => 'No working sets this week.',
        LandmarkStatus.belowMv =>
          'Below maintenance (${_sets(m.landmarks.mv)} sets).',
        LandmarkStatus.belowMev =>
          'Below the minimum effective ${_sets(m.landmarks.mev)} sets.',
        LandmarkStatus.mevToMav =>
          'In the productive range (${_sets(m.landmarks.mev)}–${_sets(m.landmarks.mavHigh)}).',
        LandmarkStatus.aboveMav =>
          'Above the adaptive range (${_sets(m.landmarks.mavHigh)}); near the ceiling.',
        LandmarkStatus.atMrv =>
          'At the recoverable maximum (${_sets(m.landmarks.mrv)} sets).',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(volumeProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('VOLUME', style: textTheme.labelSmall),
        centerTitle: false,
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Could not load your volume', style: textTheme.titleLarge),
                const SizedBox(height: FitSpacing.sm),
                AuthFeedback.error(
                  (e is Failure ? e : const Unknown()).message,
                ),
                const SizedBox(height: FitSpacing.lg),
                FilledButton(
                  key: const ValueKey('volume.retry'),
                  onPressed: () => ref.invalidate(volumeProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (v) => _Body(volume: v),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.volume});

  final VolumeResponse volume;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weeks = volume.weeks;
    final current = weeks.isEmpty ? null : weeks.last;
    // Rows: every muscle the response knows, owned first, in enum order.
    final muscles = <MuscleGroup>[
      for (final m in MuscleGroup.values)
        if (volume.owned.contains(m)) m,
      for (final m in MuscleGroup.values)
        if (!volume.owned.contains(m)) m,
    ];
    MuscleWeek? cell(VolumeWeek w, MuscleGroup m) {
      for (final x in w.muscles) {
        if (x.muscle == m) return x;
      }
      return null;
    }

    return ListView(
      key: const ValueKey('volume.list'),
      padding: const EdgeInsets.only(bottom: FitSpacing.xl),
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
              Text('Hard sets per week', style: textTheme.displayMedium),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Working sets that count toward each muscle: 1 for a primary mover, ½ for a secondary. Warm-ups and drop sets do not count.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.md),
              DeloadPanel(
                deload: volume.deload,
                mesocycleWeek: volume.mesocycleWeek,
              ),
              for (final n in volume.neglected)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.xs),
                  child: Text(
                    n.daysSince == null
                        ? '${n.muscle.label} has not been trained yet.'
                        : '${n.muscle.label}: ${n.daysSince} days since a working set.',
                    key: ValueKey('volume.neglect.${n.muscle.wire}'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.amber),
                  ),
                ),
            ],
          ),
        ),
        // Header: the four ISO weeks, oldest first.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
          child: Row(
            children: <Widget>[
              const Expanded(flex: 5, child: SizedBox.shrink()),
              for (final w in weeks)
                Expanded(
                  flex: 3,
                  child: Text(
                    w.isoWeek.substring(w.isoWeek.indexOf('W')),
                    key: ValueKey('volume.week.${w.isoWeek}'),
                    textAlign: TextAlign.end,
                    style: textTheme.labelSmall?.copyWith(
                      color: identical(w, current)
                          ? FitColors.ink
                          : FitColors.ink60,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FitSpacing.xs),
        for (final m in muscles) ...<Widget>[
          const Divider(color: FitColors.rule, height: 1),
          Container(
            key: ValueKey('volume.row.${m.wire}'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen - 3,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: current == null || cell(current, m) == null
                      ? Colors.transparent
                      : VolumeScreen.statusColor(cell(current, m)!.status),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: Text(
                        m.label,
                        style: textTheme.titleMedium?.copyWith(
                          color: volume.owned.contains(m)
                              ? FitColors.ink
                              : FitColors.ink60,
                        ),
                      ),
                    ),
                    for (final w in weeks)
                      Expanded(
                        flex: 3,
                        child: Builder(
                          builder: (_) {
                            final c = cell(w, m);
                            return Text(
                              c == null ? '–' : VolumeScreen._sets(c.hardSets),
                              key: ValueKey('volume.${m.wire}.${w.isoWeek}'),
                              textAlign: TextAlign.end,
                              style: textTheme.titleMedium?.copyWith(
                                color: c == null
                                    ? FitColors.ink35
                                    : identical(w, current)
                                        ? VolumeScreen.statusColor(c.status)
                                        : FitColors.ink60,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                if (current != null && cell(current, m) != null) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      VolumeScreen.statusLine(cell(current, m)!),
                      key: ValueKey('volume.${m.wire}.status'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: VolumeScreen.statusColor(
                          cell(current, m)!.status,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'MV ${VolumeScreen._sets(cell(current, m)!.landmarks.mv)} · MEV ${VolumeScreen._sets(cell(current, m)!.landmarks.mev)} · MAV ${VolumeScreen._sets(cell(current, m)!.landmarks.mavLow)}–${VolumeScreen._sets(cell(current, m)!.landmarks.mavHigh)} · MRV ${VolumeScreen._sets(cell(current, m)!.landmarks.mrv)}',
                    key: ValueKey('volume.${m.wire}.landmarks'),
                    style:
                        textTheme.labelSmall?.copyWith(color: FitColors.ink35),
                  ),
                ],
              ],
            ),
          ),
        ],
        const Divider(color: FitColors.rule, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.md,
            FitSpacing.screen,
            0,
          ),
          child: Text(
            'Landmarks: MV maintenance, MEV minimum effective, MAV most adaptive, MRV maximum recoverable. Ranges are the §12.3 defaults per muscle, not a diagnosis.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink35),
          ),
        ),
      ],
    );
  }
}
