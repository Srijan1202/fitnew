import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../ai/domain/entities/ai_draft.dart';
import '../../../ai/presentation/controllers/ai_providers.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import '../controllers/food_logger.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/food_widgets.dart';
import '../widgets/log_controls.dart';

/// Opens "Describe your meal" for a day and meal; true when something was
/// logged (the caller closes the log sheet then).
Future<bool> showDescribeMeal(BuildContext context, LogTarget target) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DescribeMealScreen(target: target),
      ),
    ) ??
    false;

/// Phase 14 (§13.4, §19; ADR-020 D2/D6): a meal in the user's own words.
///
/// FITOS AI reads the text into foods and amounts; the server matches each
/// one to the FITOS food database at a portion of that food's own rows, so
/// the numbers are the database's. A food FITOS does not have comes back as
/// the model's estimate, labelled so; one whose estimate is not believable
/// comes back as a problem to enter by hand. It is a DRAFT (§19.2): the user
/// checks it, changes amounts, leaves things out, and only "Add" logs —
/// through the ordinary queue, so it reaches the server like any other log.
class DescribeMealScreen extends ConsumerStatefulWidget {
  const DescribeMealScreen({required this.target, super.key});

  final LogTarget target;

  @override
  ConsumerState<DescribeMealScreen> createState() => _DescribeMealScreenState();
}

/// One draft line as the user has adjusted it.
class _Line {
  _Line(this.item)
      : include = item.loggable,
        servings = item.match?.servings ?? 1;

  final DraftItem item;
  bool include;
  double servings;

  PreviewNutrition? get preview {
    final m = item.match;
    if (m != null) return PortionPreview.scale(m.row, servings);
    final e = item.estimate;
    if (e != null) {
      return PortionPreview.quickAdd(
        QuickAdd(
          kcal: e.kcal,
          proteinG: e.proteinG,
          carbG: e.carbG,
          fatG: e.fatG,
        ),
      );
    }
    return null;
  }
}

class _DescribeMealScreenState extends ConsumerState<DescribeMealScreen> {
  static const maxChars = 500;
  final _text = TextEditingController();
  bool _reading = false;
  bool _adding = false;
  Failure? _failure;
  List<_Line>? _lines;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final text = _text.text.trim();
    if (text.length < 2 || _reading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _reading = true;
      _failure = null;
    });
    final r = await ref.read(aiApiProvider).parseFood(text);
    if (!mounted) return;
    r.when(
      ok: (answer) => setState(() {
        _lines = [for (final i in answer.draft.items) _Line(i)];
        _reading = false;
      }),
      err: (f) => setState(() {
        _failure = f;
        _reading = false;
      }),
    );
  }

  /// Steps of half a serving, or 25 g on a per-100 g row; 0.1–20 servings.
  void _step(_Line line, int dir) {
    final m = line.item.match!;
    final step = m.row.basis == NutritionBasis.per100g ? 0.25 : 0.5;
    final next = ((line.servings + dir * step) * 100).roundToDouble() / 100;
    setState(() {
      line.servings =
          next.clamp(PortionPreview.servingsMin, PortionPreview.servingsMax);
    });
  }

  List<_Line> get _chosen => [
        for (final l in _lines ?? const <_Line>[])
          if (l.include && l.item.loggable) l,
      ];

  Future<void> _add() async {
    final chosen = _chosen;
    if (chosen.isEmpty || _adding) return;
    setState(() => _adding = true);
    await ref.read(foodLoggerProvider).logDraft(
      foods: [
        for (final l in chosen)
          if (l.item.match case final m?)
            (foodId: m.foodId, name: m.name, row: m.row, servings: l.servings),
      ],
      estimates: [
        for (final l in chosen)
          if (l.item.estimate case final e?)
            QuickAdd(
              name: e.name,
              kcal: e.kcal,
              proteinG: e.proteinG,
              carbG: e.carbG,
              fatG: e.fatG,
            ),
      ],
      target: widget.target,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lines = _lines;
    final chosen = _chosen;
    PreviewNutrition? total;
    for (final l in chosen) {
      final p = l.preview;
      if (p != null) total = total == null ? p : total + p;
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('DESCRIBE YOUR MEAL', style: textTheme.labelSmall),
            Text(
              widget.target.slot.label,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('describe.scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.screen,
            FitSpacing.xl,
          ),
          children: <Widget>[
            Text(
              'Write what you ate, the way you would say it. FITOS AI finds '
              'each food in the FITOS database. Nothing is logged until you '
              'check it and tap Add.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            TextField(
              key: const ValueKey('describe.input'),
              controller: _text,
              minLines: 2,
              maxLines: 5,
              maxLength: maxChars,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _read(),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '2 chapati, a katori of dal and a glass of lassi',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
            ),
            Text(
              'Only this text is sent to FITOS AI — not your profile or your log.',
              key: const ValueKey('describe.privacy'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('describe.read'),
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed:
                  _reading || _text.text.trim().length < 2 ? null : _read,
              icon: _reading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _reading
                    ? 'Reading…'
                    : (lines == null ? 'Read it' : 'Read it again'),
              ),
            ),
            if (_failure case final f?)
              Padding(
                padding: const EdgeInsets.only(top: FitSpacing.sm),
                child: Text(
                  aiFailureText(f),
                  key: const ValueKey('describe.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ),
            if (lines != null) ...<Widget>[
              const SizedBox(height: FitSpacing.lg),
              Text('CHECK BEFORE ADDING', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              const Divider(color: FitColors.rule, height: 1),
              if (lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
                  child: Text(
                    'No food found in that. Try naming what you ate and how much.',
                    key: const ValueKey('describe.empty'),
                    style: textTheme.bodyLarge,
                  ),
                ),
              for (final (i, l) in lines.indexed)
                _LineTile(
                  index: i,
                  line: l,
                  onInclude: (v) => setState(() => l.include = v),
                  onStep: (d) => _step(l, d),
                ),
              if (total != null) ...<Widget>[
                const SizedBox(height: FitSpacing.md),
                Text(
                  'About ${EatFormat.kcal(total.kcalLow, total.kcalHigh)} kcal · '
                  '${EatFormat.grams(total.proteinLow, total.proteinHigh)} protein',
                  key: const ValueKey('describe.total'),
                  style: textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: FitSpacing.md),
              FilledButton.icon(
                key: const ValueKey('describe.add'),
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: chosen.isEmpty || _adding ? null : _add,
                icon: Icon(mealSlotIcon(widget.target.slot)),
                label: Text(
                  chosen.isEmpty
                      ? 'Nothing chosen'
                      : 'Add ${chosen.length} to ${widget.target.slot.label}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.index,
    required this.line,
    required this.onInclude,
    required this.onStep,
  });

  final int index;
  final _Line line;
  final ValueChanged<bool> onInclude;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final item = line.item;
    final m = item.match;
    final e = item.estimate;
    final p = line.preview;
    final unsure = item.confidence != AiConfidence.high;
    final (String name, String tag, Color tagColor) = m != null
        ? (m.name, 'FITOS', FitColors.pine)
        : e != null
            ? (e.name, 'ESTIMATE', FitColors.amber)
            : (item.phrase, 'NOT FOUND', FitColors.oxide);
    return DecoratedBox(
      key: ValueKey('describe.item.$index'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 40,
              child: item.loggable
                  ? Checkbox(
                      key: ValueKey('describe.item.$index.include'),
                      value: line.include,
                      shape: const RoundedRectangleBorder(),
                      onChanged: (v) => onInclude(v ?? false),
                    )
                  : const Padding(
                      padding: EdgeInsets.only(top: FitSpacing.sm),
                      child: Icon(Icons.error_outline, color: FitColors.oxide),
                    ),
            ),
            const SizedBox(width: FitSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          name,
                          key: ValueKey('describe.item.$index.name'),
                          style: textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: FitSpacing.sm),
                      Text(
                        tag,
                        key: ValueKey('describe.item.$index.tag'),
                        style: textTheme.labelSmall?.copyWith(color: tagColor),
                      ),
                    ],
                  ),
                  Text(
                    'You wrote “${item.phrase}”',
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                  if (m != null) ...<Widget>[
                    const SizedBox(height: FitSpacing.xs),
                    Row(
                      children: <Widget>[
                        _StepButton(
                          key: ValueKey('describe.item.$index.less'),
                          icon: Icons.remove,
                          onPressed: line.servings > PortionPreview.servingsMin
                              ? () => onStep(-1)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            FoodLogger.servingsText(m.row, line.servings),
                            key: ValueKey('describe.item.$index.portion'),
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        _StepButton(
                          key: ValueKey('describe.item.$index.more'),
                          icon: Icons.add,
                          onPressed: line.servings < PortionPreview.servingsMax
                              ? () => onStep(1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                  if (p != null)
                    Text(
                      '${EatFormat.kcal(p.kcalLow, p.kcalHigh)} kcal · '
                      '${EatFormat.grams(p.proteinLow, p.proteinHigh)} protein',
                      key: ValueKey('describe.item.$index.kcal'),
                      style: textTheme.bodyMedium,
                    ),
                  if (e != null)
                    Text(
                      'Not in FITOS: FITOS AI estimated it'
                      '${e.grams != null ? ' for about ${FoodFormat.number(e.grams!)} g' : ''}. '
                      'Logged as a quick add.',
                      style:
                          textTheme.bodySmall?.copyWith(color: FitColors.amber),
                    )
                  else if (m != null && unsure)
                    Text(
                      'Check this: FITOS AI was not sure of the food or the amount.',
                      key: ValueKey('describe.item.$index.unsure'),
                      style:
                          textTheme.bodySmall?.copyWith(color: FitColors.amber),
                    ),
                  if (item.problem case final problem?)
                    Text(
                      problem,
                      key: ValueKey('describe.item.$index.problem'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed, super.key});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      );
}
