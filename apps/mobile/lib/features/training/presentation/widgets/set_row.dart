import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/program.dart';

/// One set, editable in place: reps, weight, RIR. Built for a gym: 44 px
/// targets, −/+ on everything, tap the weight to type it. Nothing here
/// navigates; every change goes up through [onChanged].
class SetRow extends StatefulWidget {
  const SetRow({
    required this.set,
    required this.incrementKg,
    required this.enabled,
    required this.onChanged,
    this.rowKey,
    this.trailing,
    super.key,
  });

  final PlannedSet set;

  /// The exercise's load step (§12.4): 2.5 kg for a bench, 5 for a squat.
  final double incrementKg;
  final bool enabled;
  final ValueChanged<PlannedSet> onChanged;

  /// Prefix for control keys (`<rowKey>.reps.plus` …), for tests.
  final String? rowKey;

  /// After the steppers: a remove control on the plan, nothing in a session.
  final Widget? trailing;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  bool _typing = false;
  late final TextEditingController _weight = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _typing) _commitWeight();
    });
  }

  @override
  void dispose() {
    _weight.dispose();
    _focus.dispose();
    super.dispose();
  }

  Key? _k(String suffix) =>
      widget.rowKey == null ? null : ValueKey('${widget.rowKey}.$suffix');

  /// The set shows its target (the top of a range: 6–12 opens at 12). A tap
  /// steps that number by one and pins it; only this set changes.
  void _reps(int delta) {
    final s = widget.set;
    final next = (s.targetReps + delta).clamp(1, 50);
    widget.onChanged(s.copyWith(repsMin: next, repsMax: next));
  }

  void _weightStep(int direction) {
    final current = widget.set.weightKg ?? 0;
    final next =
        (current + direction * widget.incrementKg).clamp(0.0, 500.0).toDouble();
    widget.onChanged(widget.set.copyWith(weightKg: _round(next)));
  }

  void _rir(int delta) {
    widget.onChanged(
      widget.set.copyWith(rir: (widget.set.rir + delta).clamp(0, 5)),
    );
  }

  void _startTyping() {
    setState(() {
      _typing = true;
      _weight.text =
          widget.set.weightKg == null ? '' : _fmt(widget.set.weightKg!);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _commitWeight() {
    final text = _weight.text.trim().replaceAll(',', '.');
    final parsed = text.isEmpty ? null : double.tryParse(text);
    setState(() => _typing = false);
    if (text.isNotEmpty && parsed == null) return; // leave as it was
    final next = parsed == null ? null : _round(parsed.clamp(0.0, 500.0));
    if (next != widget.set.weightKg) {
      widget.onChanged(widget.set.copyWith(weightKg: next));
    }
  }

  static double _round(double v) => (v * 100).round() / 100;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = widget.set;
    final weightLabel = s.weightKg == null ? '—' : _fmt(s.weightKg!);
    return Semantics(
      label:
          'Set ${s.setIndex}: ${s.targetReps} reps, ${s.weightKg == null ? 'no weight set' : '${s.weightKg} kilograms'}, ${s.rir} reps in reserve',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '${s.setIndex}',
                style: textTheme.titleMedium?.copyWith(color: FitColors.ink60),
              ),
            ),
            // REPS
            _Stepper(
              minusKey: _k('reps.minus'),
              plusKey: _k('reps.plus'),
              enabled: widget.enabled,
              onMinus: () => _reps(-1),
              onPlus: () => _reps(1),
              // The prescription's range sits under the number until pinned.
              unit: s.repsMin == s.repsMax ? 'reps' : '${s.repsLabel} reps',
              child: Text(
                '${s.targetReps}',
                key: _k('reps'),
                style: textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: FitSpacing.sm),
            // WEIGHT
            _Stepper(
              minusKey: _k('weight.minus'),
              plusKey: _k('weight.plus'),
              enabled: widget.enabled,
              onMinus: () => _weightStep(-1),
              onPlus: () => _weightStep(1),
              unit: 'kg',
              child: _typing
                  ? SizedBox(
                      width: 56,
                      child: TextField(
                        key: _k('weight.field'),
                        controller: _weight,
                        focusNode: _focus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _commitWeight(),
                      ),
                    )
                  : InkWell(
                      key: _k('weight'),
                      onTap: widget.enabled ? _startTyping : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: Center(
                          child: Text(
                            weightLabel,
                            style: textTheme.titleLarge?.copyWith(
                              color: s.weightKg == null
                                  ? FitColors.ink35
                                  : FitColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: FitSpacing.sm),
            // RIR
            _Stepper(
              minusKey: _k('rir.minus'),
              plusKey: _k('rir.plus'),
              enabled: widget.enabled,
              onMinus: () => _rir(-1),
              onPlus: () => _rir(1),
              compact: true,
              unit: 'RIR',
              child: Text(
                '${s.rir}',
                key: _k('rir'),
                style: textTheme.titleLarge,
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

/// − value + with a tiny unit under it. Hairline language, no filled pills.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.child,
    required this.unit,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
    this.minusKey,
    this.plusKey,
    this.compact = false,
  });

  final Widget child;
  final String unit;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Key? minusKey;
  final Key? plusKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      flex: compact ? 3 : 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Tap(
                key: minusKey,
                icon: Icons.remove,
                enabled: enabled,
                onTap: onMinus,
              ),
              Expanded(child: Center(child: child)),
              _Tap(
                key: plusKey,
                icon: Icons.add,
                enabled: enabled,
                onTap: onPlus,
              ),
            ],
          ),
          Text(
            unit,
            style: textTheme.labelSmall?.copyWith(
              color: FitColors.ink35,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({
    required this.icon,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: const BorderRadius.all(FitRadius.medium),
      child: SizedBox(
        width: 40,
        height: 44,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? FitColors.ink : FitColors.ink35,
        ),
      ),
    );
  }
}
