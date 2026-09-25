import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/presentation/widgets/auth_form_field.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../domain/progress.dart';
import 'progress_providers.dart';

/// Owner D5: readings can be dated up to 30 days back, never ahead.
const progressDaysBack = 30;

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What a failed save says. Offline is said plainly: nothing was queued.
String saveFailureText(Failure f) => f is Offline
    ? "You're offline. Readings are saved online only — nothing was stored. Try again when you're connected."
    : f.message;

/// Log a weight (Progress). Returns true when saved.
Future<bool> showWeightSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReadingSheet(site: null),
    ) ??
    false;

/// Log a tape measurement (Progress). Returns true when saved.
Future<bool> showMeasurementSheet(
  BuildContext context, {
  MeasurementSite initial = MeasurementSite.waist,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReadingSheet(site: initial),
    ) ??
    false;

class _ReadingSheet extends ConsumerStatefulWidget {
  const _ReadingSheet({required this.site});

  /// Null for a weight.
  final MeasurementSite? site;

  @override
  ConsumerState<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends ConsumerState<_ReadingSheet> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  late MeasurementSite? _site = widget.site;
  String? _date; // null = today
  bool _busy = false;
  String? _error;

  bool get _weight => widget.site == null;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) {
      return _weight ? 'Enter your weight.' : 'Enter the measurement.';
    }
    final (lo, hi) = _weight ? (30.0, 300.0) : (10.0, 250.0);
    if (n < lo || n > hi) return 'That does not look right.';
    return null;
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(ref.read(localTodayProvider));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date == null ? today : DateTime.parse(_date!),
      firstDate: today.subtract(const Duration(days: progressDaysBack)),
      lastDate: today,
    );
    if (picked != null && mounted) {
      final iso = _iso(picked);
      setState(() => _date = iso == _iso(today) ? null : iso);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final value = double.parse(_value.text.trim());
    setState(() {
      _busy = true;
      _error = null;
    });
    final actions = ref.read(progressActionsProvider);
    final failure = _weight
        ? await actions.logWeight(value, date: _date)
        : await actions.logMeasurement(_site!, value, date: _date);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = saveFailureText(failure);
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.lg + inset,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _weight ? 'LOG WEIGHT' : 'LOG MEASUREMENT',
                style: textTheme.labelSmall,
              ),
              const SizedBox(height: FitSpacing.sm),
              if (!_weight)
                Wrap(
                  spacing: FitSpacing.sm,
                  runSpacing: FitSpacing.xs,
                  children: <Widget>[
                    for (final s in MeasurementSite.values)
                      ChoiceChip(
                        key: ValueKey('progress.sheet.site.${s.wire}'),
                        label: Text(s.label),
                        selected: _site == s,
                        onSelected: (_) => setState(() => _site = s),
                      ),
                  ],
                ),
              if (!_weight) const SizedBox(height: FitSpacing.sm),
              AuthFormField(
                fieldKey: const ValueKey('progress.sheet.value'),
                label: _weight ? 'Weight (kg)' : 'Measurement (cm)',
                controller: _value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validate,
              ),
              const SizedBox(height: FitSpacing.sm),
              // A Wrap, not a Row: at 200 % text on a 360 px phone the button
              // moves under the date instead of overflowing.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: FitSpacing.sm,
                children: <Widget>[
                  Text(
                    _date == null ? 'Today' : _date!,
                    key: const ValueKey('progress.sheet.date'),
                    style: textTheme.bodyLarge,
                  ),
                  TextButton(
                    key: const ValueKey('progress.sheet.pickDate'),
                    onPressed: _busy ? null : _pickDate,
                    child: const Text('Change date'),
                  ),
                ],
              ),
              Text(
                _weight
                    ? 'One reading per day; saving again replaces it. Your calorie target does not change from a single weigh-in.'
                    : 'One reading per site per day; saving again replaces it.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                Text(
                  _error!,
                  key: const ValueKey('progress.sheet.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ],
              const SizedBox(height: FitSpacing.md),
              FilledButton(
                key: const ValueKey('progress.sheet.save'),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
