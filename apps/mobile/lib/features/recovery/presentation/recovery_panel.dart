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

String _hours(double h) =>
    '${h == h.roundToDouble() ? h.toInt() : h.toStringAsFixed(1)} h';

/// The check-in (≤ 10 s, every question optional) in a sheet: a new one, or
/// today's opened with its saved answers. Returns true when saved.
Future<bool> showCheckInSheet(BuildContext context, {RecoveryLog? log}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckInSheet(log: log),
    ) ??
    false;

/// Phase 13 (§18; ADR-019), beta 3.9's Today strip at the top of Progress:
/// today's readiness as the server computed it, or the way into the
/// check-in when there is none yet. Nothing here computes a score or
/// changes the plan; what went into the score is [ReadinessDetails].
class RecoveryPanel extends ConsumerWidget {
  const RecoveryPanel({super.key});

  static String _summary(RecoveryLog log) {
    final parts = <String>[
      if (log.sleepHours != null) '${_hours(log.sleepHours!)} sleep',
      for (final s in RecoveryScale.values)
        if (log.scale(s) != null) '${s.label.toLowerCase()} ${log.scale(s)}/5',
    ];
    return 'Checked in today: ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(recoveryTodayProvider);
    final view = async.value;
    final today = view?.today;
    final log = today?.log;
    final status = _status(ref, view);
    final live = view?.source == RecoverySource.live;
    return Padding(
      key: const ValueKey('recovery.today'),
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
          if (today != null && log != null) ...<Widget>[
            if (today.readiness case final r?) _ReadinessHeadline(readiness: r),
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
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                ),
                onPressed:
                    live ? () => showCheckInSheet(context, log: log) : null,
                child: const Text("Change today's check-in"),
              ),
            ),
          ],
          if (today != null && log == null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Not checked in yet', style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'About ten seconds; readiness is worked out from it.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: FitColors.ink60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FitSpacing.sm),
                FilledButton(
                  key: const ValueKey('recovery.checkIn.open'),
                  onPressed: () => showCheckInSheet(context),
                  child: const Text('Check in'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// The honest line when the view is not live: cached (with its time) or unavailable.
  static (String, String)? _status(WidgetRef ref, RecoveryView? view) {
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

/// The server's readiness at a glance: the score, its band, the advice, and
/// the escalation when there is one.
class _ReadinessHeadline extends ConsumerWidget {
  const _ReadinessHeadline({required this.readiness});

  final Readiness readiness;

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
      ],
    );
  }
}

/// What went into today's readiness: for each part that had something to
/// go on, a bar of what is left of its share (full when it took nothing
/// off); the parts with nothing to go on in one quiet line, never guessed.
class ReadinessDetails extends StatelessWidget {
  const ReadinessDetails({required this.readiness, super.key});

  final Readiness readiness;

  static String _missing(ReadinessComponentKey k) => switch (k) {
        ReadinessComponentKey.performance => 'not enough recent training',
        ReadinessComponentKey.adherence => 'no food logged this week',
        ReadinessComponentKey.running => 'not enough recent running',
        _ => 'not answered',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final used = [
      for (final c in readiness.components)
        if (c.available) c,
    ];
    final missing = [
      for (final c in readiness.components)
        if (!c.available) c,
    ];
    return Column(
      key: const ValueKey('recovery.readiness.details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final c in used)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                // Shares, not fixed widths: fits at 200 % text on 360 px.
                Expanded(
                  flex: 3,
                  child: Text(
                    c.key.label,
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(FitRadius.small),
                    child: LinearProgressIndicator(
                      key: ValueKey('recovery.component.${c.key.wire}.bar'),
                      value: c.max == 0 ? 1 : (c.max - c.penalty) / c.max,
                      minHeight: 6,
                      // Pine when it took nothing off; amber when it did.
                      color: c.penalty == 0 ? FitColors.pine : FitColors.amber,
                      backgroundColor: FitColors.paper2,
                    ),
                  ),
                ),
                const SizedBox(width: FitSpacing.sm),
                Expanded(
                  flex: 3,
                  child: Text(
                    c.penalty == 0 ? 'No effect' : '−${c.penalty} of ${c.max}',
                    key: ValueKey('recovery.component.${c.key.wire}'),
                    textAlign: TextAlign.end,
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'Not in the score: ${missing.map((c) => '${c.key.label.toLowerCase()} (${_missing(c.key)})').join(', ')}.',
              key: const ValueKey('recovery.components.missing'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
          ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Advice only — your plan never changes on its own. Sleep quality and stress are kept but do not move the score.',
          key: const ValueKey('recovery.readiness.note'),
          style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
        ),
      ],
    );
  }
}

class _CheckInSheet extends ConsumerStatefulWidget {
  const _CheckInSheet({required this.log});

  /// Today's saved check-in when changing it; null for a new one.
  final RecoveryLog? log;

  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
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

  @override
  void initState() {
    super.initState();
    _sleep = widget.log?.sleepHours;
    for (final s in RecoveryScale.values) {
      _scales[s] = widget.log?.scale(s);
    }
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
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    // The answers stay, to try again.
    setState(() {
      _saving = false;
      _error = checkInFailureText(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hc = ref.watch(homeContextProvider).health?.sleep;
    final hcMinutes = hc != null && hc.isAvailable ? hc.value!.round() : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          FitSpacing.screen,
          0,
          FitSpacing.screen,
          FitSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const ValueKey('recovery.checkIn'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('How are you today?', style: textTheme.titleLarge),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'About ten seconds. Every question is optional.',
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Text(
                    _sleep == null ? 'Not set' : _hours(_sleep!),
                    key: const ValueKey('recovery.sleep.value'),
                    textAlign: TextAlign.center,
                    style: _sleep == null
                        ? textTheme.bodyMedium?.copyWith(color: FitColors.ink35)
                        : textTheme.titleLarge,
                  ),
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
              const SizedBox(height: FitSpacing.md),
              // The question and what each end means, on one line.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: FitSpacing.sm,
                children: <Widget>[
                  Text(s.label, style: textTheme.bodyMedium),
                  Text(
                    '1 ${s.low.toLowerCase()} · 5 ${s.high.toLowerCase()}',
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Row(
                children: <Widget>[
                  for (var v = 1; v <= 5; v++) ...<Widget>[
                    if (v > 1) const SizedBox(width: FitSpacing.xs),
                    Expanded(
                      child: _ScaleBox(
                        key: ValueKey('recovery.${s.wire}.$v'),
                        label: '${s.label} $v of 5',
                        value: v,
                        selected: _scales[s] == v,
                        // Tapping the chosen value again clears it.
                        onTap: () => setState(
                          () => _scales[s] = _scales[s] == v ? null : v,
                        ),
                      ),
                    ),
                  ],
                ],
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
            const SizedBox(height: FitSpacing.lg),
            Row(
              children: <Widget>[
                if (widget.log != null) ...<Widget>[
                  TextButton(
                    key: const ValueKey('recovery.cancel'),
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                ],
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('recovery.save'),
                    onPressed: _saving || _empty ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : _empty
                              ? 'Answer one to save'
                              : 'Save check-in',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One of a question's five values: a full-width share of the row; the
/// chosen one a solid ink block (§6.2).
class _ScaleBox extends StatelessWidget {
  const _ScaleBox({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.all(FitRadius.small);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? FitColors.ink : FitColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? FitColors.ink : FitColors.rule,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: selected ? FitColors.paper : FitColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
