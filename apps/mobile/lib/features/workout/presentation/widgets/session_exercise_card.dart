import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../training/domain/entities/program.dart';
import '../../../training/presentation/widgets/set_row.dart';
import '../../domain/entities/workout.dart';

/// One exercise in the session in progress. Collapsed: number, name,
/// "done / planned sets". Expanded: every set as a row — logged sets in
/// pine with a check, the next one pre-filled with a **done** tap — then
/// "+ Add set", "Drop set", "Superset with next", Replace, Remove.
///
/// Nothing here decides a number: pending values come from the server's
/// prefill (the engine's recommendation, what you did, or the plan) or
/// copy the row above. Phase 6 shows the recommendation with its reason,
/// a one-tap "Use last time's weight" revert, and — in a deload week —
/// the plan's original targets beside the lighter ones.
class SessionExerciseCard extends StatelessWidget {
  const SessionExerciseCard({
    required this.index,
    required this.exercise,
    required this.rows,
    required this.expanded,
    required this.supersetWithNext,
    required this.canSuperset,
    required this.onToggle,
    required this.onPendingChanged,
    required this.onLog,
    required this.onLoggedChanged,
    required this.onDeleteLogged,
    required this.onAddSet,
    required this.onDropSet,
    required this.onSupersetToggle,
    required this.onReplace,
    required this.onRemove,
    this.onUseLastWeight,
    this.onRecommendationTap,
    this.prSetIds = const <String>{},
    super.key,
  });

  final int index;
  final SessionExercise exercise;

  /// The rows to show, in order (pending and logged).
  final List<SessionSetRow> rows;
  final bool expanded;
  final bool supersetWithNext;
  final bool canSuperset;
  final VoidCallback onToggle;
  final void Function(SessionSetRow row, PlannedSet values) onPendingChanged;
  final void Function(SessionSetRow row) onLog;
  final void Function(SetLog set, PlannedSet values) onLoggedChanged;
  final void Function(SetLog set) onDeleteLogged;
  final VoidCallback onAddSet;
  final VoidCallback? onDropSet;
  final VoidCallback onSupersetToggle;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  /// Owner 12.1: revert the pending rows to last time's weight. Null when
  /// there is nothing to revert to (no last time, or the same load).
  final VoidCallback? onUseLastWeight;

  /// Tap on the reason line: the sheet with the full reason, the last
  /// three sessions and the revert.
  final VoidCallback? onRecommendationTap;

  /// Client set ids that beat the prior best when logged (PR moment).
  final Set<String> prSetIds;

  /// Plan §6: pine for increase-load, ink for add-reps / hold, amber for
  /// reduce-load / deload, ink60 for establish-baseline.
  static Color actionColor(ProgressionAction a) => switch (a) {
        ProgressionAction.increaseLoad => FitColors.pine,
        ProgressionAction.addReps || ProgressionAction.hold => FitColors.ink,
        ProgressionAction.reduceLoad ||
        ProgressionAction.deload =>
          FitColors.amber,
        ProgressionAction.establishBaseline => FitColors.ink60,
      };

  static String actionGlyph(ProgressionAction a) => switch (a) {
        ProgressionAction.increaseLoad => '↑',
        ProgressionAction.addReps => '+',
        ProgressionAction.hold => '=',
        ProgressionAction.reduceLoad || ProgressionAction.deload => '↓',
        ProgressionAction.establishBaseline => '·',
      };

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// "65 kg × 6" / "× 12 (bodyweight)" — the recommendation in one line.
  static String recommendationLabel(ProgressionRecommendation r) {
    final load = r.weightKg == null ? 'bodyweight' : '${_kg(r.weightKg!)} kg';
    return '$load × ${r.repTarget} · ${r.targetRir} RIR';
  }

  /// Plan targets summarised: "4 × 6–12 @ 80 kg".
  static String targetsLabel(List<PlannedSet> targets) {
    if (targets.isEmpty) return 'no sets';
    final t = targets.first;
    final reps =
        t.repsMin == t.repsMax ? '${t.repsMax}' : '${t.repsMin}–${t.repsMax}';
    final load = t.weightKg == null ? '' : ' @ ${_kg(t.weightKg!)} kg';
    return '${targets.length} × $reps$load';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final x = exercise;
    final key = 'session.${x.clientExerciseId}';
    final logged = x.sets.where((s) => s.setType == SetType.working).length;
    final planned = x.targets.length;
    final last = x.lastPerformance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(color: FitColors.rule, height: 1),
        InkWell(
          key: ValueKey('$key.header'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FitSpacing.screen,
              vertical: FitSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 34,
                  child: Text(
                    '$index',
                    style: textTheme.displaySmall?.copyWith(
                      height: 1,
                      color: logged >= planned && planned > 0
                          ? FitColors.pine
                          : FitColors.ink,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(x.name, style: textTheme.titleLarge),
                      const SizedBox(height: FitSpacing.xs),
                      Text(
                        [
                          if (x.primaryMuscles.isNotEmpty)
                            x.primaryMuscles.first.label,
                          x.equipment.map((e) => e.label).join(' + '),
                        ].join(' · '),
                        style: textTheme.bodyMedium,
                      ),
                      if (last != null) ...<Widget>[
                        const SizedBox(height: FitSpacing.xs),
                        Text(
                          'Last time: ${last.sets.map((s) => '${s.weightKg == null ? '—' : _kg(s.weightKg!)}×${s.reps}').join('  ')}',
                          key: ValueKey('$key.last'),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.ink60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (x.recommendation != null) ...<Widget>[
                        const SizedBox(height: FitSpacing.xs),
                        InkWell(
                          key: ValueKey('$key.recommendation'),
                          onTap: onRecommendationTap,
                          child: Text(
                            '${actionGlyph(x.recommendation!.action)} ${recommendationLabel(x.recommendation!)} — ${x.recommendation!.reason}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: actionColor(x.recommendation!.action),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FitSpacing.md),
                if (prSetIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: FitSpacing.sm),
                    child: Text(
                      'PR',
                      key: ValueKey('$key.pr'),
                      style:
                          textTheme.labelSmall?.copyWith(color: FitColors.pine),
                    ),
                  ),
                Text(
                  planned > 0 ? '$logged / $planned' : '$logged sets',
                  key: ValueKey('$key.count'),
                  style: textTheme.titleMedium?.copyWith(
                    color: logged >= planned && planned > 0
                        ? FitColors.pine
                        : FitColors.ink,
                  ),
                ),
                const SizedBox(width: FitSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.expand_more,
                      size: 22,
                      color: FitColors.ink60,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (supersetWithNext)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen + 34,
              0,
              FitSpacing.screen,
              FitSpacing.sm,
            ),
            child: Text(
              'SUPERSET · alternate sets with the next exercise',
              key: ValueKey('$key.superset'),
              style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
            ),
          ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              0,
              FitSpacing.screen,
              FitSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (x.originalTargets != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                    child: Text(
                      'DELOAD · plan was ${targetsLabel(x.originalTargets!)}',
                      key: ValueKey('$key.originals'),
                      style: textTheme.labelSmall
                          ?.copyWith(color: FitColors.amber),
                    ),
                  ),
                for (final row in rows) _row(context, key, row),
                const SizedBox(height: FitSpacing.sm),
                Wrap(
                  spacing: FitSpacing.sm,
                  children: <Widget>[
                    TextButton(
                      key: ValueKey('$key.addSet'),
                      onPressed: onAddSet,
                      child: const Text('+ Add set'),
                    ),
                    TextButton(
                      key: ValueKey('$key.dropSet'),
                      onPressed: onDropSet,
                      child: const Text('Drop set'),
                    ),
                    if (canSuperset)
                      TextButton(
                        key: ValueKey('$key.supersetToggle'),
                        onPressed: onSupersetToggle,
                        child: Text(
                          supersetWithNext
                              ? 'Un-superset'
                              : 'Superset with next',
                        ),
                      ),
                    TextButton(
                      key: ValueKey('$key.replace'),
                      onPressed: onReplace,
                      child: const Text('Replace'),
                    ),
                    TextButton(
                      key: ValueKey('$key.remove'),
                      onPressed: onRemove,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Last time's heaviest working load, if any.
  static double? _lastWeight(SessionExercise x) {
    final weights = x.lastPerformance?.sets
        .map((s) => s.weightKg)
        .whereType<double>()
        .toList();
    if (weights == null || weights.isEmpty) return null;
    return weights.reduce((a, b) => a > b ? a : b);
  }

  static double? lastWeightOf(SessionExercise x) => _lastWeight(x);

  Widget _row(BuildContext context, String key, SessionSetRow row) {
    final textTheme = Theme.of(context).textTheme;
    final logged = row.logged;
    final rowKey =
        '$key.set.${row.setIndex}${row.setType == SetType.drop ? '.drop' : ''}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (row.setType != SetType.working)
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: FitSpacing.xs),
                  child: Text(
                    row.setType.label.toUpperCase(),
                    style: textTheme.labelSmall,
                  ),
                ),
              SetRow(
                key: ValueKey(rowKey),
                rowKey: rowKey,
                set: row.values,
                incrementKg: exercise.incrementKg,
                enabled: true,
                onChanged: (next) => logged == null
                    ? onPendingChanged(row, next)
                    : onLoggedChanged(logged, next),
                trailing: _original(context, rowKey, row),
              ),
            ],
          ),
        ),
        const SizedBox(width: FitSpacing.xs),
        // Done: ink circle to tap; pine check once logged (tap again to
        // un-log a mis-tap); a star when the set beat the prior best.
        InkWell(
          key: ValueKey('$rowKey.done'),
          onTap:
              logged == null ? () => onLog(row) : () => onDeleteLogged(logged),
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Semantics(
            button: true,
            label: logged == null
                ? 'Log set ${row.setIndex}'
                : 'Set ${row.setIndex} logged',
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: logged == null ? FitColors.ink : FitColors.pine,
              ),
              child: Icon(
                logged == null
                    ? Icons.check
                    : prSetIds.contains(logged.clientSetId)
                        ? Icons.star
                        : Icons.done_all,
                key: ValueKey(
                  '$rowKey.${logged != null && prSetIds.contains(logged.clientSetId) ? 'star' : 'icon'}',
                ),
                size: 20,
                color: FitColors.paper,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Deload week: the plan's original target for this set, in ink35,
  /// beside the lighter number (plan §6).
  Widget? _original(BuildContext context, String rowKey, SessionSetRow row) {
    final originals = exercise.originalTargets;
    if (originals == null || row.setType != SetType.working) return null;
    if (row.setIndex > originals.length) return null;
    final o = originals[row.setIndex - 1];
    final reps =
        o.repsMin == o.repsMax ? '${o.repsMax}' : '${o.repsMin}–${o.repsMax}';
    return Padding(
      padding: const EdgeInsets.only(left: FitSpacing.xs),
      child: Text(
        o.weightKg == null ? 'plan $reps' : 'plan ${_kg(o.weightKg!)}×$reps',
        key: ValueKey('$rowKey.original'),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: FitColors.ink35),
      ),
    );
  }
}

/// A row on the card: either a logged set (with its [SetLog]) or a pending
/// one the user has not tapped done on yet.
class SessionSetRow {
  const SessionSetRow({
    required this.setIndex,
    required this.setType,
    required this.values,
    this.logged,
    this.plannedSetId,
  });

  final int setIndex;
  final SetType setType;

  /// reps (min == max), weight, rir — in the plan's set shape so the
  /// existing stepper row renders it.
  final PlannedSet values;
  final SetLog? logged;
  final String? plannedSetId;

  String get key => '$setIndex.${setType.wire}';
}
