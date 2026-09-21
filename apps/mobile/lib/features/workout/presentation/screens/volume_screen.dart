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

/// Phase 6, owner 12.8 — presentation only. The server answers the
/// current ISO week and the three before it with hard sets, a status and
/// the §12.3 landmarks per muscle; this screen shows that in plain words
/// with progressive disclosure: a row per muscle ("Chest — 19 sets —
/// High"), tap for this week vs last, the explanation and the four-week
/// history in human labels, and a "View technical details" disclosure
/// that keeps MV / MEV / MAV / MRV and the weighting available. No
/// number here is computed on the phone.
class VolumeScreen extends ConsumerWidget {
  const VolumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(volumeProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('TRAINING VOLUME', style: textTheme.labelSmall),
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
                Text(
                  'Could not load your training volume',
                  style: textTheme.titleLarge,
                ),
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
          data: (v) => _VolumeBody(volume: v),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------- wording -- */

/// Plain words for the engine's status (the status itself is the server's).
class VolumeWording {
  const VolumeWording._();

  static String sets(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// The short label on a row: "On track", "High", …
  static String label(LandmarkStatus s) => switch (s) {
        LandmarkStatus.none => 'Not trained',
        LandmarkStatus.belowMv => 'Very low',
        LandmarkStatus.belowMev => 'Low',
        LandmarkStatus.mevToMav => 'On track',
        LandmarkStatus.aboveMav => 'High',
        LandmarkStatus.atMrv => 'Very high',
      };

  /// The longer form used in the detail: "High volume".
  static String title(LandmarkStatus s) => switch (s) {
        LandmarkStatus.none => 'Not trained this week',
        LandmarkStatus.belowMv => 'Very low volume',
        LandmarkStatus.belowMev => 'Low volume',
        LandmarkStatus.mevToMav => 'On track',
        LandmarkStatus.aboveMav => 'High volume',
        LandmarkStatus.atMrv => 'Very high volume',
      };

  static String explanation(LandmarkStatus s) => switch (s) {
        LandmarkStatus.none => 'No working sets for this muscle yet this week.',
        LandmarkStatus.belowMv =>
          'Fewer sets than it takes to hold on to what you have. A few more sets this week would help.',
        LandmarkStatus.belowMev =>
          'Some work, but not yet enough to make progress. Adding a couple of sets would bring it into range.',
        LandmarkStatus.mevToMav =>
          'Enough work to make progress, with room to recover. Keep going.',
        LandmarkStatus.aboveMav =>
          'A lot of work — more than most people need. Fine for a while; watch for fatigue.',
        LandmarkStatus.atMrv =>
          'About as much as you can recover from. More will not help; a lighter week might.',
      };

  /// Plan §6 colours: oxide below MV / at MRV, amber below MEV / above
  /// MAV, ink in range, ink35 when nothing.
  static Color color(LandmarkStatus s) => switch (s) {
        LandmarkStatus.belowMv || LandmarkStatus.atMrv => FitColors.oxide,
        LandmarkStatus.belowMev || LandmarkStatus.aboveMav => FitColors.amber,
        LandmarkStatus.mevToMav => FitColors.ink,
        LandmarkStatus.none => FitColors.ink35,
      };

  /// "This week", "Last week", "2 weeks ago" — by distance from the last
  /// (current) week the server sent.
  static String weekLabel(int weeksAgo) => switch (weeksAgo) {
        0 => 'This week',
        1 => 'Last week',
        _ => '$weeksAgo weeks ago',
      };

  static const _months = [
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

  /// The Monday of an ISO week key ("2026-W39" → 2026-09-21).
  static DateTime? mondayOf(String isoWeek) {
    final m = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(isoWeek);
    if (m == null) return null;
    final year = int.parse(m.group(1)!);
    final week = int.parse(m.group(2)!);
    // 4 January is always in ISO week 1.
    final jan4 = DateTime.utc(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    return week1Monday.add(Duration(days: (week - 1) * 7));
  }

  /// "22–28 Sep" or "28 Sep – 4 Oct".
  static String dateRange(String isoWeek) {
    final monday = mondayOf(isoWeek);
    if (monday == null) return isoWeek;
    final sunday = monday.add(const Duration(days: 6));
    final m1 = _months[monday.month - 1];
    final m2 = _months[sunday.month - 1];
    return monday.month == sunday.month
        ? '${monday.day}–${sunday.day} $m1'
        : '${monday.day} $m1 – ${sunday.day} $m2';
  }
}

/* ---------------------------------------------------------------- body -- */

class _VolumeBody extends StatefulWidget {
  const _VolumeBody({required this.volume});

  final VolumeResponse volume;

  @override
  State<_VolumeBody> createState() => _VolumeBodyState();
}

class _VolumeBodyState extends State<_VolumeBody> {
  final Set<MuscleGroup> _open = <MuscleGroup>{};
  final Set<MuscleGroup> _technical = <MuscleGroup>{};

  MuscleWeek? _cell(VolumeWeek w, MuscleGroup m) {
    for (final x in w.muscles) {
      if (x.muscle == m) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final v = widget.volume;
    final weeks = v.weeks;
    final current = weeks.isEmpty ? null : weeks.last;
    final last = weeks.length < 2 ? null : weeks[weeks.length - 2];
    // Muscles the programme owns first, then the rest, in enum order.
    final muscles = <MuscleGroup>[
      for (final m in MuscleGroup.values)
        if (v.owned.contains(m)) m,
      for (final m in MuscleGroup.values)
        if (!v.owned.contains(m)) m,
    ];

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
              Text('Training volume', style: textTheme.displayMedium),
              const SizedBox(height: FitSpacing.xs),
              Text(
                "How much you've trained each muscle this week.",
                style: textTheme.bodyLarge,
              ),
              if (current != null) ...<Widget>[
                const SizedBox(height: FitSpacing.xs),
                Text(
                  '${VolumeWording.weekLabel(0)} · ${VolumeWording.dateRange(current.isoWeek)}',
                  key: const ValueKey('volume.currentWeek'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ],
              const SizedBox(height: FitSpacing.md),
              DeloadPanel(deload: v.deload, mesocycleWeek: v.mesocycleWeek),
              for (final n in v.neglected)
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
        for (final m in muscles) ...<Widget>[
          const Divider(color: FitColors.rule, height: 1),
          _row(context, m, current, last),
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
            'Sets are working sets from completed sessions. Tap a muscle for the last four weeks and the details.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink35),
          ),
        ),
      ],
    );
  }

  /// "Chest — 19 sets — High", a thin rule in the status colour; tap to
  /// open the detail.
  Widget _row(
    BuildContext context,
    MuscleGroup m,
    VolumeWeek? current,
    VolumeWeek? last,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final owned = widget.volume.owned.contains(m);
    final cell = current == null ? null : _cell(current, m);
    final status = cell?.status ?? LandmarkStatus.none;
    final sets = cell?.hardSets ?? 0;
    final open = _open.contains(m);
    final color = VolumeWording.color(status);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            width: 3,
            color: cell == null ? Colors.transparent : color,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: ValueKey('volume.row.${m.wire}'),
            onTap: () => setState(() {
              if (!_open.remove(m)) _open.add(m);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen - 3,
                FitSpacing.md,
                FitSpacing.screen,
                FitSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      m.label,
                      style: textTheme.titleMedium?.copyWith(
                        color: owned ? FitColors.ink : FitColors.ink60,
                      ),
                    ),
                  ),
                  Text(
                    '${VolumeWording.sets(sets)} sets',
                    key: ValueKey('volume.${m.wire}.sets'),
                    style: textTheme.titleMedium?.copyWith(
                      color: owned ? FitColors.ink : FitColors.ink60,
                    ),
                  ),
                  const SizedBox(width: FitSpacing.md),
                  SizedBox(
                    width: 84,
                    child: Text(
                      VolumeWording.label(status),
                      key: ValueKey('volume.${m.wire}.status'),
                      textAlign: TextAlign.end,
                      style: textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: FitColors.ink60,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) _detail(context, m, cell, last),
        ],
      ),
    );
  }

  /// This week vs last, the status in words, the four-week history, and
  /// the technical disclosure.
  Widget _detail(
    BuildContext context,
    MuscleGroup m,
    MuscleWeek? cell,
    VolumeWeek? last,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final status = cell?.status ?? LandmarkStatus.none;
    final lastCell = last == null ? null : _cell(last, m);
    final weeks = widget.volume.weeks;
    final technical = _technical.contains(m);
    return Padding(
      key: ValueKey('volume.${m.wire}.detail'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen - 3,
        0,
        FitSpacing.screen,
        FitSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'This week ${VolumeWording.sets(cell?.hardSets ?? 0)} sets · last week ${VolumeWording.sets(lastCell?.hardSets ?? 0)} sets',
            key: ValueKey('volume.${m.wire}.compare'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.sm),
          Text(
            VolumeWording.title(status),
            key: ValueKey('volume.${m.wire}.title'),
            style: textTheme.titleMedium?.copyWith(
              color: VolumeWording.color(status),
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            VolumeWording.explanation(status),
            key: ValueKey('volume.${m.wire}.explanation'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.md),
          Text('LAST FOUR WEEKS', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          for (var i = weeks.length - 1; i >= 0; i--)
            Padding(
              padding: const EdgeInsets.only(bottom: FitSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${VolumeWording.weekLabel(weeks.length - 1 - i)} · ${VolumeWording.dateRange(weeks[i].isoWeek)}',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ),
                  Text(
                    '${VolumeWording.sets(_cell(weeks[i], m)?.hardSets ?? 0)} sets',
                    key: ValueKey(
                      'volume.${m.wire}.history.${weeks[i].isoWeek}',
                    ),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          const SizedBox(height: FitSpacing.xs),
          TextButton(
            key: ValueKey('volume.${m.wire}.technical'),
            onPressed: () => setState(() {
              if (!_technical.remove(m)) _technical.add(m);
            }),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              technical ? 'Hide technical details' : 'View technical details',
            ),
          ),
          if (technical && cell != null)
            _technicalDetails(context, m, cell)
          else if (technical)
            Text(
              'No sets for this muscle this week, so no landmarks to compare against.',
              key: ValueKey('volume.${m.wire}.landmarks'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
        ],
      ),
    );
  }

  /// MV / MEV / MAV / MRV, the engine's status, the weighting and the
  /// hard-set rule — the same numbers the server sent, kept here.
  Widget _technicalDetails(BuildContext context, MuscleGroup m, MuscleWeek c) {
    final textTheme = Theme.of(context).textTheme;
    final l = c.landmarks;
    const s = VolumeWording.sets;
    Widget line(String k, String v, {Key? key}) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 150,
                child: Text(
                  k,
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ),
              Expanded(child: Text(v, key: key, style: textTheme.bodyMedium)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          line(
            'Landmarks',
            'MV ${s(l.mv)} · MEV ${s(l.mev)} · MAV ${s(l.mavLow)}–${s(l.mavHigh)} · MRV ${s(l.mrv)}',
            key: ValueKey('volume.${m.wire}.landmarks'),
          ),
          line('Engine status', c.status.wire),
          line('Hard sets this week', s(c.hardSets)),
          line('Tonnage this week', '${s(c.tonnageKg)} kg'),
          line('Weighting', '1 per primary muscle, 0.5 per secondary'),
          line(
            'Counted',
            'working sets of completed sessions; warm-ups and drop sets excluded',
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'MV maintenance · MEV minimum effective · MAV most adaptive · MRV maximum recoverable — the §12.3 defaults per muscle, not a diagnosis.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink35),
          ),
        ],
      ),
    );
  }
}
