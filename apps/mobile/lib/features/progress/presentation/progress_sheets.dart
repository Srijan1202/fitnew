import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/presentation/widgets/auth_form_field.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/progress.dart';
import 'progress_providers.dart';

/// Owner D5: readings can be dated up to 30 days back, never ahead.
const progressDaysBack = 30;

/// 72 kg, 72.4 kg.
String _kg(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

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

/// Beta 3.8 (tester feedback: "should be just a popup"): Home's log-weight
/// action. Today's weight, saved like Personal details saved it (the targets
/// follow), and optionally the tape measurements in the same sheet. Returns
/// true when the weight was saved.
Future<bool> showQuickWeightSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QuickWeightSheet(),
    ) ??
    false;

class _QuickWeightSheet extends ConsumerStatefulWidget {
  const _QuickWeightSheet();

  @override
  ConsumerState<_QuickWeightSheet> createState() => _QuickWeightSheetState();
}

class _QuickWeightSheetState extends ConsumerState<_QuickWeightSheet> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _sites = {
    for (final s in MeasurementSite.values) s: TextEditingController(),
  };
  bool _measure = false;
  bool _busy = false;

  /// The weight went through but a measurement did not: a retry sends only
  /// the measurements still missing.
  bool _weightSaved = false;
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    for (final c in _sites.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateWeight(String? v) {
    if (_weightSaved) return null;
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null) return 'Enter your weight.';
    if (n < 30 || n > 300) return 'That does not look right.';
    return null;
  }

  /// Optional: empty is fine, a number must be plausible.
  String? _validateSite(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text.replaceAll(',', '.'));
    if (n == null || n < 10 || n > 250) return 'That does not look right.';
    return null;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final actions = ref.read(progressActionsProvider);
    if (!_weightSaved) {
      final kg = double.parse(_weight.text.trim().replaceAll(',', '.'));
      final failure = await actions.logTodayWeight(kg);
      if (!mounted) return;
      if (failure != null) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
        return;
      }
      _weightSaved = true;
    }
    if (_measure) {
      for (final MapEntry(key: site, value: c) in _sites.entries) {
        final text = c.text.trim();
        if (text.isEmpty) continue;
        final failure = await actions.logMeasurement(
          site,
          double.parse(text.replaceAll(',', '.')),
        );
        if (!mounted) return;
        if (failure != null) {
          setState(() {
            _busy = false;
            _error =
                'Your weight is saved. ${site.label} and anything after it are not: ${saveFailureText(failure)}';
          });
          return;
        }
        c.clear(); // saved: a retry does not send it again
      }
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final last =
        ref.watch(profileControllerProvider).value?.profile.latestWeightKg;
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
              Text("TODAY'S WEIGHT", style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.sm),
              AuthFormField(
                fieldKey: const ValueKey('weigh.value'),
                label: 'Weight (kg)',
                controller: _weight,
                enabled: !_weightSaved,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validateWeight,
              ),
              if (last != null) ...<Widget>[
                const SizedBox(height: FitSpacing.xs),
                Text(
                  'Last time: ${_kg(last)} kg',
                  key: const ValueKey('weigh.last'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ],
              const SizedBox(height: FitSpacing.sm),
              if (!_measure)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('weigh.measure'),
                    onPressed:
                        _busy ? null : () => setState(() => _measure = true),
                    icon: const Icon(Icons.straighten),
                    label: const Text('Add measurements (optional)'),
                  ),
                )
              else ...<Widget>[
                Text(
                  'MEASUREMENTS (CM), OPTIONAL',
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: FitSpacing.xs),
                for (final s in MeasurementSite.values) ...<Widget>[
                  AuthFormField(
                    fieldKey: ValueKey('weigh.site.${s.wire}'),
                    label: s.label,
                    controller: _sites[s]!,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateSite,
                  ),
                  const SizedBox(height: FitSpacing.xs),
                ],
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                Text(
                  _error!,
                  key: const ValueKey('weigh.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ],
              const SizedBox(height: FitSpacing.md),
              FilledButton(
                key: const ValueKey('weigh.save'),
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
