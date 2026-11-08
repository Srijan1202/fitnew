import 'dart:typed_data';

import '../../../premium/presentation/premium_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../ai/domain/entities/ai_draft.dart';
import '../../../ai/presentation/controllers/ai_providers.dart';
import '../../data/meal_photo_source.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import '../controllers/food_logger.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/food_widgets.dart';
import '../widgets/log_controls.dart';
import '../../../privacy/presentation/privacy_providers.dart';
import '../../../../shared/widgets/fit_glass.dart';

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

/// Beta 5.5 (owner): "Snap a meal" — the same draft from a photo of the
/// plate; true when something was logged.
Future<bool> showPhotoMeal(BuildContext context, LogTarget target) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DescribeMealScreen(target: target, photo: true),
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
///
/// Beta 5.5 ([photo]): the camera opens first; the photo is read against
/// the mess menu for this meal, and a dish on it comes back at the mess
/// table's numbers (logged as a mess log). The photo is never kept.
class DescribeMealScreen extends ConsumerStatefulWidget {
  const DescribeMealScreen({
    required this.target,
    this.photo = false,
    super.key,
  });

  final LogTarget target;
  final bool photo;

  @override
  ConsumerState<DescribeMealScreen> createState() => _DescribeMealScreenState();
}

/// One draft line as the user has adjusted it.
class _Line {
  _Line(this.item)
      : include = item.loggable,
        servings = item.match?.servings ?? item.messDish?.servings ?? 1;

  final DraftItem item;
  bool include;
  double servings;

  PreviewNutrition? get preview {
    final m = item.match;
    if (m != null) return PortionPreview.scale(m.row, servings);
    final d = item.messDish;
    if (d != null) {
      double v(String k) => (d.perServing[k] ?? 0) * servings;
      return PreviewNutrition(
        kcalLow: v('kcalLow'),
        kcalHigh: v('kcalHigh'),
        proteinLow: v('proteinLow'),
        proteinHigh: v('proteinHigh'),
        carbLow: v('carbLow'),
        carbHigh: v('carbHigh'),
        fatLow: v('fatLow'),
        fatHigh: v('fatHigh'),
        fibreLow: null,
        fibreHigh: null,
      );
    }
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

  /// Beta 5.5: the photo being read (in memory only), its menu, and why a
  /// photo could not be sent.
  Uint8List? _photo;
  String? _messCode;
  String? _menuDate;
  String? _photoNote;

  @override
  void initState() {
    super.initState();
    if (widget.photo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _snap(camera: true));
    }
  }

  /// Beta 5.5: the camera (or the gallery), then the photo read into a
  /// draft. Closing the camera before any photo closes Snap a meal too.
  Future<void> _snap({required bool camera}) async {
    if (_reading) return;
    final navigator = Navigator.of(context);
    void leaveIfEmpty() {
      if (_photo == null && mounted) navigator.pop(false);
    }

    if (!await ensurePremium(context, ref, feature: 'Snap a meal') ||
        !mounted) {
      return leaveIfEmpty();
    }
    if (!await ensureAiConsent(context, ref) || !mounted) {
      return leaveIfEmpty();
    }
    final pick = await ref
        .read(mealPhotoSourceProvider)
        .pick(camera: camera, navigator: navigator);
    if (!mounted) return;
    final bytes = pick.bytes;
    // Beta 5.7: a gallery closed without a photo keeps Snap a meal open.
    if (bytes == null) return pick.left ? leaveIfEmpty() : null;
    final mime = photoMimeOf(bytes);
    setState(() {
      _photo = bytes;
      _lines = null;
      _failure = null;
      _photoNote = mime == null
          ? 'FITOS AI reads JPEG, PNG and WebP photos. Take one with the camera.'
          : null;
      _reading = mime != null;
    });
    if (mime == null) return;
    final r = await ref.read(aiApiProvider).parseFoodPhoto(
          bytes: bytes,
          mimeType: mime,
          slot: widget.target.slot.wire,
          date: widget.target.date,
        );
    if (!mounted) return;
    r.when(
      ok: (answer) => setState(() {
        _lines = [for (final i in answer.draft.items) _Line(i)];
        _messCode = answer.messCode;
        _menuDate = answer.menuDate;
        _reading = false;
      }),
      err: (f) => setState(() {
        _failure = f;
        _reading = false;
      }),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final text = _text.text.trim();
    if (text.length < 2 || _reading) return;
    FocusScope.of(context).unfocus();
    // Phase 17: FITOS AI is its own consent (asked once, before first use).
    // Phase 19: FITOS AI is premium.
    if (!await ensurePremium(context, ref, feature: 'Describe your meal') ||
        !mounted) {
      return;
    }
    if (!await ensureAiConsent(context, ref) || !mounted) return;
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
  /// Beta 5.5: a mess dish in halves, 0.25–10.
  void _step(_Line line, int dir) {
    if (line.item.messDish != null) {
      final next = line.servings + dir * 0.5;
      setState(() {
        line.servings = next.clamp(
          DraftMessDish.servingsMin,
          DraftMessDish.servingsMax,
        );
      });
      return;
    }
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
      messDishes: [
        for (final l in chosen)
          if (l.item.messDish case final d?)
            (
              dishSlug: d.dishSlug,
              name: d.name,
              servingLabel: d.servingLabel,
              servings: l.servings,
              preview: l.preview!,
            ),
      ],
      messCode: _messCode,
      menuDate: _menuDate,
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
            Text(
              widget.photo ? 'SNAP A MEAL' : 'DESCRIBE YOUR MEAL',
              style: textTheme.labelSmall,
            ),
            Text(
              widget.target.slot.label,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: FitBackdrop(
        child: SafeArea(
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
              if (widget.photo)
                ..._photoSection(textTheme)
              else ...<Widget>[
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
                  decoration: InputDecoration(
                    hintText: '2 chapati, a katori of dal and a glass of lassi',
                    border: fitGlass
                        ? null
                        : const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                          ),
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
                    shape: fitGlass ? null : const RoundedRectangleBorder(),
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
              ],
              if (_failure case final f?)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.sm),
                  child: Text(
                    aiFailureText(f),
                    key: const ValueKey('describe.error'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                  ),
                ),
              if (lines != null) ...<Widget>[
                const SizedBox(height: FitSpacing.lg),
                Text('CHECK BEFORE ADDING', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.xs),
                const FitRule(),
                if (lines.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: FitSpacing.md),
                    child: Text(
                      widget.photo
                          ? "Couldn't see any food in that photo. Retake it, or describe the meal instead."
                          : 'No food found in that. Try naming what you ate and how much.',
                      key: const ValueKey('describe.empty'),
                      style: textTheme.bodyLarge,
                    ),
                  ),
                for (final (i, l) in lines.indexed)
                  _LineTile(
                    index: i,
                    line: l,
                    photo: widget.photo,
                    onInclude: (v) => setState(() => l.include = v),
                    onStep: (d) => _step(l, d),
                  ),
                if (total != null) ...<Widget>[
                  const SizedBox(height: FitSpacing.md),
                  Text(
                    '${FoodFormat.capitalised(EatFormat.kcal(total.kcalLow, total.kcalHigh))} kcal · '
                    '${EatFormat.grams(total.proteinLow, total.proteinHigh)} protein',
                    key: const ValueKey('describe.total'),
                    style: textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: FitSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('describe.add'),
                  style: FilledButton.styleFrom(
                    shape: fitGlass ? null : const RoundedRectangleBorder(),
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
      ),
    );
  }

  /// Beta 5.5: the photo, Retake and Gallery, and what happens to it.
  List<Widget> _photoSection(TextTheme textTheme) {
    final photo = _photo;
    return <Widget>[
      Text(
        'A photo of your plate. FITOS AI finds each food — the dishes on '
        "your mess menu first. Nothing is logged until you check it and tap Add.",
        style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
      ),
      const SizedBox(height: FitSpacing.md),
      if (photo != null)
        ClipRRect(
          borderRadius: fitGlass
              ? const BorderRadius.all(FitRadius.block)
              : BorderRadius.zero,
          child: Image.memory(
            photo,
            key: const ValueKey('photo.preview'),
            height: 200,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox(height: 200),
          ),
        ),
      const SizedBox(height: FitSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('photo.camera'),
              style: OutlinedButton.styleFrom(
                shape: fitGlass ? null : const RoundedRectangleBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _reading ? null : () => _snap(camera: true),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(photo == null ? 'Take a photo' : 'Retake'),
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('photo.gallery'),
              style: OutlinedButton.styleFrom(
                shape: fitGlass ? null : const RoundedRectangleBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _reading ? null : () => _snap(camera: false),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ),
        ],
      ),
      Text(
        'The photo goes to FITOS AI for this one reading and is never kept.',
        key: const ValueKey('photo.privacy'),
        style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
      ),
      if (_reading)
        Padding(
          padding: const EdgeInsets.only(top: FitSpacing.md),
          child: Row(
            key: const ValueKey('photo.reading'),
            children: <Widget>[
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: FitSpacing.sm),
              Text('Reading your plate…', style: textTheme.bodyLarge),
            ],
          ),
        ),
      if (_photoNote case final note?)
        Padding(
          padding: const EdgeInsets.only(top: FitSpacing.sm),
          child: Text(
            note,
            key: const ValueKey('photo.note'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
          ),
        ),
      if (_lines?.isEmpty ?? false)
        Padding(
          padding: const EdgeInsets.only(top: FitSpacing.sm),
          child: TextButton.icon(
            key: const ValueKey('photo.describe'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<bool>(
                fullscreenDialog: true,
                builder: (_) => DescribeMealScreen(target: widget.target),
              ),
            ),
            // An icon the 5.3 release's font already has: a patch cannot
            // carry font changes.
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Describe it instead'),
          ),
        ),
    ];
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.index,
    required this.line,
    required this.onInclude,
    required this.onStep,
    this.photo = false,
  });

  final int index;
  final bool photo;
  final _Line line;
  final ValueChanged<bool> onInclude;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final item = line.item;
    final m = item.match;
    final d = item.messDish;
    final e = item.estimate;
    final p = line.preview;
    final unsure = item.confidence != AiConfidence.high;
    final (String name, String tag, Color tagColor) = m != null
        ? (m.name, 'FITOS', FitColors.pine)
        : d != null
            ? (d.name, 'MESS', FitColors.pine)
            : e != null
                ? (e.name, 'ESTIMATE', FitColors.amber)
                : (item.phrase, 'NOT FOUND', FitColors.oxide);
    final stepped = m != null || d != null;
    final atMin = d != null
        ? line.servings <= DraftMessDish.servingsMin
        : line.servings <= PortionPreview.servingsMin;
    final atMax = d != null
        ? line.servings >= DraftMessDish.servingsMax
        : line.servings >= PortionPreview.servingsMax;
    return DecoratedBox(
      key: ValueKey('describe.item.$index'),
      decoration: BoxDecoration(
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
                      shape: fitGlass ? null : const RoundedRectangleBorder(),
                      onChanged: (v) => onInclude(v ?? false),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: FitSpacing.sm),
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
                    photo
                        ? 'FITOS AI saw “${item.phrase}”'
                        : 'You wrote “${item.phrase}”',
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                  if (stepped) ...<Widget>[
                    const SizedBox(height: FitSpacing.xs),
                    Row(
                      children: <Widget>[
                        _StepButton(
                          key: ValueKey('describe.item.$index.less'),
                          icon: Icons.remove,
                          onPressed: atMin ? null : () => onStep(-1),
                        ),
                        Expanded(
                          child: Text(
                            m != null
                                ? FoodLogger.servingsText(m.row, line.servings)
                                : '${FoodFormat.number(line.servings)} × ${d!.servingLabel}',
                            key: ValueKey('describe.item.$index.portion'),
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        _StepButton(
                          key: ValueKey('describe.item.$index.more'),
                          icon: Icons.add,
                          onPressed: atMax ? null : () => onStep(1),
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
                  else if (stepped && unsure)
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
            shape: fitGlass ? null : const RoundedRectangleBorder(),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      );
}
