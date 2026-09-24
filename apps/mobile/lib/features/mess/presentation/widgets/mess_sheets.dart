import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/tokens.dart';
import '../../../nutrition/domain/entities/food_log.dart';
import '../../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../../nutrition/presentation/controllers/food_logger.dart';
import '../../../nutrition/presentation/widgets/log_controls.dart';
import '../../../nutrition/presentation/widgets/portion_sheet.dart';
import '../../domain/mess.dart';
import '../mess_providers.dart';
import 'mess_widgets.dart';

/// Tap a dish. With an estimate, on a day that can be logged: the Phase 8
/// portion step, with the estimate's qualifiers and "Report wrong
/// nutrition"; the log goes through the Phase 8 queue (works offline).
/// Otherwise an information sheet says why it cannot be logged.
/// Returns true when a log was queued.
Future<bool> openMessDish(
  BuildContext context,
  WidgetRef ref, {
  required MessDish dish,
  required MessMenu menu,
  required MealSlot slot,
}) async {
  final today = ref.read(eatDateProvider.notifier).today;
  final loggable = canLogOn(menu.date, today);
  final row = dish.nutrition;
  if (row == null || !loggable) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitColors.paper,
      builder: (ctx) => _DishInfoSheet(
        dish: dish,
        reason: row == null
            ? 'FITOS has no estimate for this dish yet, so it cannot be logged from the menu. Use Quick add in Log food, or report what you know.'
            : menu.date.compareTo(today) > 0
                ? 'This day has not happened yet: its menu can be viewed, not logged.'
                : 'Food can be logged up to 30 days back.',
      ),
    );
    return false;
  }
  final choice = await showPortionSheet(
    context,
    food: dish.asFood(),
    slot: slot,
    footer: MessEstimateNote(dish: dish),
  );
  if (choice == null) return false;
  await ref.read(foodLoggerProvider).logMessDish(
        messCode: menu.mess.code,
        menuDate: menu.date,
        dishSlug: dish.slug,
        dishName: dish.name,
        row: choice.row,
        portion: choice.portion,
        asGrams: choice.asGrams,
        target: LogTarget(date: menu.date, slot: choice.slot),
      );
  return true;
}

/// Under the portion preview: what kind of number this is, and a way to say
/// it is wrong.
class MessEstimateNote extends ConsumerWidget {
  const MessEstimateNote({required this.dish, super.key});

  final MessDish dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final n = dish.nutrition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          [
            'Mess estimate',
            if (n != null) n.confidence.label.toLowerCase(),
            'fibre not known',
          ].join(' · '),
          key: const ValueKey('mess.estimateNote'),
          style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
        ),
        if (dish.correctionPending)
          Text(
            'Your report is pending review.',
            key: const ValueKey('mess.reportPending'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          )
        else
          TextButton(
            key: const ValueKey('mess.report'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => showCorrectionSheet(context, ref, dish: dish),
            child: const Text('Report wrong nutrition'),
          ),
      ],
    );
  }
}

class _DishInfoSheet extends ConsumerWidget {
  const _DishInfoSheet({required this.dish, required this.reason});

  final MessDish dish;
  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final n = dish.nutrition;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('mess.info'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                DietMark(diet: dish.diet),
                const SizedBox(width: FitSpacing.sm),
                Expanded(
                  child: Text(dish.name, style: textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              dish.diet.label,
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            if (n != null) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              Wrap(
                spacing: FitSpacing.lg,
                runSpacing: FitSpacing.sm,
                children: <Widget>[
                  MacroCell(
                    label: 'Per ${n.servingLabel}',
                    value: MessFormat.dishLine(dish).split(' · ').first,
                  ),
                ],
              ),
            ],
            const SizedBox(height: FitSpacing.md),
            Text(reason, key: const ValueKey('mess.info.reason')),
            const SizedBox(height: FitSpacing.md),
            MessEstimateNote(dish: dish),
          ],
        ),
      ),
    );
  }
}

/// "Report wrong nutrition" (owner D17): stored as pending on the server;
/// the estimate does not change until a later review. Online only.
Future<void> showCorrectionSheet(
  BuildContext context,
  WidgetRef ref, {
  required MessDish dish,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FitColors.paper,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _CorrectionSheet(dish: dish),
    ),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Thanks — your report is pending review. The estimate does not change until then.',
        ),
      ),
    );
    ref.invalidate(messMenuProvider);
  }
}

class _CorrectionSheet extends ConsumerStatefulWidget {
  const _CorrectionSheet({required this.dish});

  final MessDish dish;

  @override
  ConsumerState<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends ConsumerState<_CorrectionSheet> {
  CorrectionField _field = CorrectionField.kcal;
  DietClass? _diet;
  final _low = TextEditingController();
  final _high = TextEditingController();
  final _note = TextEditingController();
  final _id = const Uuid().v4();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _low.dispose();
    _high.dispose();
    _note.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  MessCorrectionRequest? _request() {
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (_field.isMacro) {
      final lo = _num(_low);
      final hi = _num(_high) ?? lo;
      if (lo == null || hi == null || lo < 0 || hi < lo) return null;
      return MessCorrectionRequest(
        clientCorrectionId: _id,
        field: _field,
        low: lo,
        high: hi,
        note: note,
      );
    }
    if (_field == CorrectionField.diet) {
      if (_diet == null) return null;
      return MessCorrectionRequest(
        clientCorrectionId: _id,
        field: _field,
        diet: _diet,
        note: note,
      );
    }
    if (note == null) return null;
    return MessCorrectionRequest(
      clientCorrectionId: _id,
      field: _field,
      note: note,
    );
  }

  Future<void> _send() async {
    final request = _request();
    if (request == null) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    final result = await ref
        .read(messRepositoryProvider)
        .correct(widget.dish.slug, request);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _busy = false;
          _problem = failure is Offline
              ? 'Reporting needs a connection.'
              : failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unit = _field.unit;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('mess.correction'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('REPORT', style: textTheme.labelSmall),
            Text(widget.dish.name, style: textTheme.titleLarge),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'Your report is reviewed before anything changes. Until then the estimate stays as it is.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            Text('WHAT IS WRONG', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceWrap<CorrectionField>(
              keyPrefix: 'correction.field',
              options: CorrectionField.values,
              selected: _field,
              label: (f) => f.label,
              onSelect: (f) => setState(() => _field = f),
            ),
            const SizedBox(height: FitSpacing.md),
            if (_field.isMacro)
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const ValueKey('correction.low'),
                      controller: _low,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'From ($unit)',
                        helperText:
                            'per ${widget.dish.nutrition?.servingLabel ?? 'serving'}',
                      ),
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('correction.high'),
                      controller: _high,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: 'To ($unit)'),
                    ),
                  ),
                ],
              )
            else if (_field == CorrectionField.diet)
              ChoiceWrap<DietClass?>(
                keyPrefix: 'correction.diet',
                options: const [DietClass.veg, DietClass.egg, DietClass.nonveg],
                selected: _diet,
                label: (d) => d?.label ?? '',
                onSelect: (d) => setState(() => _diet = d),
              ),
            const SizedBox(height: FitSpacing.sm),
            TextField(
              key: const ValueKey('correction.note'),
              controller: _note,
              maxLength: 280,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _field == CorrectionField.other
                    ? 'What is wrong'
                    : 'Note (optional)',
              ),
            ),
            if (_problem != null)
              Text(
                _problem!,
                key: const ValueKey('correction.problem'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
              ),
            const SizedBox(height: FitSpacing.md),
            FilledButton(
              key: const ValueKey('correction.send'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy || _request() == null ? null : _send,
              child: Text(_busy ? 'Sending…' : 'Send report'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks one of the server's messes (Profile and the MESS screen's
/// browser). Returns the chosen mess, or null. With [allowNone], a
/// "Not a VIT student" row returns [MessChoice.none].
Future<MessChoice?> showMessPicker(
  BuildContext context, {
  String? currentCode,
  bool allowNone = false,
  String title = 'Choose your mess',
}) {
  return showModalBottomSheet<MessChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FitColors.paper,
    builder: (ctx) => _MessPicker(
      currentCode: currentCode,
      allowNone: allowNone,
      title: title,
    ),
  );
}

/// A picker's answer: a mess, or "not a VIT student".
class MessChoice {
  const MessChoice(this.mess);
  final Mess? mess;

  static const MessChoice none = MessChoice(null);
}

class _MessPicker extends ConsumerWidget {
  const _MessPicker({
    required this.currentCode,
    required this.allowNone,
    required this.title,
  });

  final String? currentCode;
  final bool allowNone;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final messes = ref.watch(messesProvider);
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('mess.picker'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: FitSpacing.sm),
            ...messes.when(
              loading: () => const <Widget>[
                Padding(
                  padding: EdgeInsets.all(FitSpacing.lg),
                  child: Center(child: Text('Loading the messes…')),
                ),
              ],
              error: (e, _) => <Widget>[
                Text(
                  e is Offline
                      ? 'The list of messes needs a connection the first time.'
                      : (e is Failure
                          ? e.message
                          : 'Could not load the messes.'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(messesProvider),
                  child: const Text('Try again'),
                ),
              ],
              data: (list) => <Widget>[
                for (final hostel in <String>{
                  for (final m in list) m.hostelLabel,
                }) ...<Widget>[
                  const SizedBox(height: FitSpacing.sm),
                  Text(hostel.toUpperCase(), style: textTheme.labelSmall),
                  for (final m in list.where((m) => m.hostelLabel == hostel))
                    ListTile(
                      key: ValueKey('mess.pick.${m.code}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.messLabel),
                      trailing: m.code == currentCode
                          ? const Icon(Icons.check, color: FitColors.pine)
                          : null,
                      onTap: () => Navigator.of(context).pop(MessChoice(m)),
                    ),
                  const Divider(color: FitColors.rule, height: 1),
                ],
                if (allowNone)
                  ListTile(
                    key: const ValueKey('mess.pick.none'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I do not eat at a VIT mess'),
                    onTap: () => Navigator.of(context).pop(MessChoice.none),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
