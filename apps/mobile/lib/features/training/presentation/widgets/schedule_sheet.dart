import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';

/// Beta 6.1 (F2): the presets a cycle offers, (on, off).
const kCyclePresets = <(int, int)>[(2, 1), (3, 1), (4, 1), (3, 2), (5, 2)];

/// The days a cycle of [sessions] makes with [on] and [off] — core
/// `cycleLayout` (the server decides; this only previews it).
List<int?>? previewCycle(int sessions, int on, int off) {
  if (sessions < 1 || on < 1 || off < 0) return null;
  final out = <int?>[];
  for (var s = 0; s < sessions; s += on) {
    for (var i = s; i < s + on && i < sessions; i++) {
      out.add(i);
    }
    for (var r = 0; r < off; r++) {
      out.add(null);
    }
  }
  return out.length < 2 || out.length > 14 ? null : out;
}

/// Training ⋯ → Schedule: weekdays, or "days on / off" with no weekdays.
Future<void> showScheduleSheet(BuildContext context, Program program) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _ScheduleSheet(program: program),
    );

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet({required this.program});

  final Program program;

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  late bool _cycle = widget.program.isCycle;
  int _on = 4;
  int _off = 1;
  bool _busy = false;
  String? _error;

  List<ProgramDay> get _sessions =>
      [...widget.program.days].where((d) => !d.isRest).toList()
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(programControllerProvider.notifier)
        .setSchedule(on: _cycle ? _on : null, off: _cycle ? _off : null);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _cycle
              ? 'Your plan is now a ${previewCycle(_sessions.length, _on, _off)!.length}-day cycle, starting with ${_sessions.first.sessionName}.'
              : 'Your plan is back on weekdays.',
        ),
      ),
    );
  }

  Widget _stepper(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> set,
    Key key,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: textTheme.bodyLarge)),
        IconButton(
          key: ValueKey('$key.minus'),
          onPressed: value > min ? () => set(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            key: key,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: ValueKey('$key.plus'),
          onPressed: value < max ? () => set(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sessions = _sessions;
    final layout = previewCycle(sessions.length, _on, _off);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.md,
          FitSpacing.screen,
          FitSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('SCHEDULE', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.sm),
              SegmentedButton<bool>(
                key: const ValueKey('schedule.kind'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Weekdays')),
                  ButtonSegment(value: true, label: Text('Days on / off')),
                ],
                selected: {_cycle},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _cycle = v.first),
              ),
              const SizedBox(height: FitSpacing.md),
              if (!_cycle)
                Text(
                  'Your ${sessions.length} sessions sit on the same weekdays every week.',
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                )
              else ...<Widget>[
                Wrap(
                  spacing: FitSpacing.xs,
                  runSpacing: FitSpacing.xs,
                  children: <Widget>[
                    for (final (on, off) in kCyclePresets)
                      ChoiceChip(
                        key: ValueKey('schedule.preset.$on-$off'),
                        label: Text('$on on, $off off'),
                        selected: _on == on && _off == off,
                        onSelected: (_) => setState(() {
                          _on = on;
                          _off = off;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: FitSpacing.sm),
                _stepper(
                  'Days on',
                  _on,
                  1,
                  7,
                  (v) => setState(() => _on = v),
                  const ValueKey('schedule.on'),
                ),
                _stepper(
                  'Days off',
                  _off,
                  0,
                  7,
                  (v) => setState(() => _off = v),
                  const ValueKey('schedule.off'),
                ),
                const SizedBox(height: FitSpacing.sm),
                if (layout == null)
                  Text(
                    'That makes a cycle shorter than 2 or longer than 14 days.',
                    key: const ValueKey('schedule.invalid'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                  )
                else ...<Widget>[
                  Text(
                    'A ${layout.length}-day cycle with no weekdays, starting today:',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: FitSpacing.xs),
                  for (var i = 0; i < layout.length; i++)
                    Text(
                      'Day ${i + 1} · ${layout[i] == null ? 'Rest' : sessions[layout[i]!].sessionName}',
                      key: ValueKey('schedule.day.${i + 1}'),
                      style:
                          textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                    ),
                  const SizedBox(height: FitSpacing.xs),
                  Text(
                    'Skip today moves the whole cycle a day. Your history stays.',
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ],
              const SizedBox(height: FitSpacing.md),
              FilledButton(
                key: const ValueKey('schedule.save'),
                onPressed: _busy || (_cycle && layout == null) ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Use this schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
