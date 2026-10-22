import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/errors/failure.dart';
import '../../../core/theme/tokens.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../workout/domain/entities/workout.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../domain/recovery.dart';
import 'recovery_providers.dart';

/// What a failed check-in says. Offline is said plainly: nothing was queued.
String checkInFailureText(Failure f) => f is Offline
    ? "You're offline. Check-ins are saved online only — nothing was stored. Try again when you're connected."
    : f.message;

/// Phase 13 (§18; ADR-019): the daily check-in (≤ 10 s, every question
/// optional) and today's readiness, as the server computed it. Nothing here
/// computes a score or changes the plan; Health Connect's sleep is shown as
/// a hint from this phone and never sent.
class RecoveryPanel extends ConsumerStatefulWidget {
  const RecoveryPanel({super.key});

  @override
  ConsumerState<RecoveryPanel> createState() => _RecoveryPanelState();
}

class _RecoveryPanelState extends ConsumerState<RecoveryPanel> {
  bool _editing = false;
  bool _saving = false;
  String? _error;
  double? _sleep;
  final Map<RecoveryScale, int?> _scales = {
    for (final s in RecoveryScale.values) s: null,
  };

  static const _sleepBase = 7.5;
  static const _sleepStep = 0.5;
  static const _sleepMax = 14.0;

  bool get _empty => _sleep == null && _scales.values.every((v) => v == null);

  void _startEditing(RecoveryLog? log) {
    setState(() {
      _editing = true;
      _error = null;
      _sleep = log?.sleepHours;
      for (final s in RecoveryScale.values) {
        _scales[s] = log?.scale(s);
      }
    });
  }

  void _nudgeSleep(double by) => setState(() {
        final next = (_sleep ?? _sleepBase) + (_sleep == null ? 0 : by);
        _sleep = next.clamp(0, _sleepMax).toDouble();
      });

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await ref.read(recoveryActionsProvider).checkIn(
          LogRecoveryRequest(
            sleepHours: _sleep,
            sleepQuality: _scales[RecoveryScale.sleepQuality],
            soreness: _scales[RecoveryScale.soreness],
            energy: _scales[RecoveryScale.energy],
            stress: _scales[RecoveryScale.stress],
          ),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (failure == null) {
        _editing = false;
      } else {
        _error = checkInFailureText(failure);
      }
    });
  }

  static String _hours(double h) =>
      '${h == h.roundToDouble() ? h.toInt() : h.toStringAsFixed(1)} h';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(recoveryTodayProvider);
    final view = async.value;
    final today = view?.today;
    final log = today?.log;
    final status = _status(view);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: FitSpacing.sm),
              child: Text(
                status.$2,
                key: ValueKey(status.$1),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ),
          if (async.isLoading && view == null)
            LinearProgressIndicator(
              key: const ValueKey('recovery.loading'),
              color: FitColors.ink,
            ),
          if (today != null && log != null && !_editing) ...<Widget>[
            if (today.readiness case final r?) _ReadinessDisplay(readiness: r),
            const SizedBox(height: FitSpacing.sm),
            Text(
              _summary(log),
              key: const ValueKey('recovery.log.summary'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('recovery.edit'),
                onPressed: view?.source == RecoverySource.live
                    ? () => _startEditing(log)
                    : null,
                child: const Text("Change today's check-in"),
              ),
            ),
          ],
          if (today != null && (log == null || _editing))
            _form(context, textTheme, editing: log != null),
        ],
      ),
    );
  }

  Widget _form(
    BuildContext context,
    TextTheme textTheme, {
    required bool editing,
  }) {
    final hc = ref.watch(homeContextProvider).health?.sleep;
    final hcMinutes = hc != null && hc.isAvailable ? hc.value!.round() : null;
    return Container(
      key: const ValueKey('recovery.checkIn'),
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: BoxDecoration(
        color: FitColors.paper2,
        borderRadius: const BorderRadius.all(FitRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('How are you today?', style: textTheme.titleMedium),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'About ten seconds. Every question is optional.',
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.md),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: FitSpacing.sm,
            children: <Widget>[
              SizedBox(
                width: 112,
                child: Text('Sleep last night', style: textTheme.bodyMedium),
              ),
              IconButton(
                key: const ValueKey('recovery.sleep.less'),
                tooltip: 'Less sleep',
                onPressed: _sleep == null || _sleep! > 0
                    ? () => _nudgeSleep(-_sleepStep)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                _sleep == null ? 'Not set' : _hours(_sleep!),
                key: const ValueKey('recovery.sleep.value'),
                style: _sleep == null
                    ? textTheme.bodyMedium?.copyWith(color: FitColors.ink35)
                    : textTheme.titleLarge,
              ),
              IconButton(
                key: const ValueKey('recovery.sleep.more'),
                tooltip: 'More sleep',
                onPressed: _sleep == null || _sleep! < _sleepMax
                    ? () => _nudgeSleep(_sleepStep)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (hcMinutes != null)
            Text(
              'Health Connect: ${hcMinutes ~/ 60} h ${hcMinutes % 60} min last night — on this phone, not sent.',
              key: const ValueKey('recovery.sleep.healthConnect'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
            ),
          for (final s in RecoveryScale.values) ...<Widget>[
            const SizedBox(height: FitSpacing.sm),
            Text(s.label, style: textTheme.bodyMedium),
            Wrap(
              spacing: FitSpacing.xs,
              children: <Widget>[
                for (var v = 1; v <= 5; v++)
                  Semantics(
                    label: '${s.label} $v of 5',
                    child: ChoiceChip(
                      key: ValueKey('recovery.${s.wire}.$v'),
                      label: Text('$v'),
                      selected: _scales[s] == v,
                      showCheckmark: false,
                      // §6.2: square corners; the chosen value is a solid ink block.
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(FitRadius.small),
                      ),
                      side: BorderSide(
                        color: _scales[s] == v ? FitColors.ink : FitColors.rule,
                      ),
                      backgroundColor: FitColors.paper,
                      selectedColor: FitColors.ink,
                      labelStyle: TextStyle(
                        color:
                            _scales[s] == v ? FitColors.paper : FitColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (on) =>
                          setState(() => _scales[s] = on ? v : null),
                    ),
                  ),
              ],
            ),
            Text(
              '1 ${s.low.toLowerCase()} · 5 ${s.high.toLowerCase()}',
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: FitSpacing.sm),
            Text(
              _error!,
              key: const ValueKey('recovery.error'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
            ),
          ],
          const SizedBox(height: FitSpacing.md),
          Wrap(
            spacing: FitSpacing.sm,
            runSpacing: FitSpacing.xs,
            alignment: WrapAlignment.end,
            children: <Widget>[
              if (editing)
                TextButton(
                  key: const ValueKey('recovery.cancel'),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _editing = false;
                            _error = null;
                          }),
                  child: const Text('Cancel'),
                ),
              FilledButton(
                key: const ValueKey('recovery.save'),
                onPressed: _saving || _empty ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save check-in'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _summary(RecoveryLog log) {
    final parts = <String>[
      if (log.sleepHours != null) '${_hours(log.sleepHours!)} sleep',
      for (final s in RecoveryScale.values)
        if (log.scale(s) != null) '${s.label.toLowerCase()} ${log.scale(s)}/5',
    ];
    return 'Checked in today: ${parts.join(' · ')}';
  }

  /// The honest line when the view is not live: cached (with its time) or unavailable.
  (String, String)? _status(RecoveryView? view) {
    if (view == null) return null;
    switch (view.source) {
      case RecoverySource.live:
        return null;
      case RecoverySource.cached:
        final at = DateTime.tryParse(view.storedAt ?? '');
        final zone = ref.watch(userTimezoneProvider);
        final local =
            at == null ? null : tz.TZDateTime.from(at, userLocation(zone));
        final when = local == null
            ? ''
            : ' from ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        return (
          'recovery.cached',
          '${view.offline ? 'Offline' : 'Not updated'} — showing your check-in$when. Checking in needs a connection.',
        );
      case RecoverySource.unavailable:
        return (
          'recovery.unavailable',
          view.offline
              ? 'Check-ins need a connection.'
              : 'Readiness is unavailable right now.',
        );
    }
  }
}

/// The server's readiness: the score, its band, the advice, what went into
/// it (and what was not logged), and the escalation when there is one.
class _ReadinessDisplay extends ConsumerWidget {
  const _ReadinessDisplay({required this.readiness});

  final Readiness readiness;

  static String _component(ReadinessComponent c) {
    if (!c.available) {
      return switch (c.key) {
        ReadinessComponentKey.performance => 'Not enough recent training',
        ReadinessComponentKey.adherence => 'No food logged this week',
        _ => 'Not answered',
      };
    }
    return c.penalty == 0 ? 'No effect' : '−${c.penalty} of ${c.max}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final r = readiness;
    final deload = ref.watch(todayProvider).value?.deload;
    final offered = deload != null &&
        deload.state == DeloadStatus.offered &&
        deload.trigger == DeloadTrigger.readiness;
    return Column(
      key: const ValueKey('recovery.readiness'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('READINESS', style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.xs),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: FitSpacing.sm,
          children: <Widget>[
            Text(
              '${r.score}',
              key: const ValueKey('recovery.readiness.score'),
              style: textTheme.displayMedium,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: FitSpacing.xs),
              child: Text(
                '/ 100 · ${r.band.label}',
                key: const ValueKey('recovery.readiness.band'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpacing.xs),
        Text(
          r.advice,
          key: const ValueKey('recovery.readiness.advice'),
          style: textTheme.bodyMedium,
        ),
        if (r.lowDays >= 2)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'Under 35 for ${r.lowDays} days running.',
              key: const ValueKey('recovery.readiness.run'),
              style: textTheme.bodyMedium,
            ),
          ),
        if (offered)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'A lighter week is offered in Training. Nothing changes unless you accept it.',
              key: const ValueKey('recovery.readiness.deload'),
              style: textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: FitSpacing.sm),
        for (final c in r.components)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Text(
                    c.key.label,
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ),
                // How much of this part's share it took off (none when not available).
                Expanded(
                  child: c.available
                      ? ClipRRect(
                          borderRadius: const BorderRadius.all(FitRadius.small),
                          child: LinearProgressIndicator(
                            value: c.max == 0 ? 0 : c.penalty / c.max,
                            minHeight: 6,
                            color: FitColors.ink60,
                            backgroundColor: FitColors.paper2,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: FitSpacing.sm),
                Flexible(
                  child: Text(
                    _component(c),
                    key: ValueKey('recovery.component.${c.key.wire}'),
                    textAlign: TextAlign.end,
                    style: c.available
                        ? textTheme.bodyMedium
                        : textTheme.bodyMedium
                            ?.copyWith(color: FitColors.ink35),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: FitSpacing.xs),
        Text(
          'Advice only — your plan never changes on its own. Sleep quality and stress are kept but do not move the score.',
          key: const ValueKey('recovery.readiness.note'),
          style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
        ),
      ],
    );
  }
}
