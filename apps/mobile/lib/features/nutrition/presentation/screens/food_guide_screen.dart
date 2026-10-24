import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../ai/domain/entities/food_guide.dart';
import '../../../ai/presentation/controllers/ai_providers.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../mess/data/mess_repository.dart';
import '../../../mess/presentation/mess_providers.dart';
import '../../../premium/presentation/premium_providers.dart';
import '../../../privacy/presentation/privacy_providers.dart';
import '../../domain/entities/food_log.dart';
import '../controllers/food_logger.dart';
import '../widgets/food_widgets.dart';

/// Opens "What should I eat?"; true when a plate was logged.
Future<bool> showFoodGuide(BuildContext context) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FoodGuideScreen(),
      ),
    ) ??
    false;

/// Things a hostel student often has to hand (the owner's list, F15), each
/// pinned to its plain food on the server (GUIDE_STAPLES). Milk and paneer
/// wait for plain entries in the food database (BACKLOG E24).
const kGuideCommonItems = <String>[
  'Bread',
  'Eggs',
  'Curd',
  'Peanut butter',
  'Oats',
  'Banana',
  'Apple',
  'Whey protein',
  'Roasted chana',
  'Almonds',
  'Sprouts',
  'Instant noodles',
];

/// Beta 3.6 (owner, F15): "What should I eat?" — premium FITOS AI.
///
/// The person picks the meal, ticks or types what they have, and/or uses
/// today's mess menu, and may say what they feel like. FITOS AI suggests up
/// to three plates from those only; every number is the food database's or
/// the mess table's, and each plate says how it fits what is left of today.
/// **Log this** logs that plate through the ordinary queue.
class FoodGuideScreen extends ConsumerStatefulWidget {
  const FoodGuideScreen({super.key});

  @override
  ConsumerState<FoodGuideScreen> createState() => _FoodGuideScreenState();
}

class _FoodGuideScreenState extends ConsumerState<FoodGuideScreen> {
  late MealSlot _slot = MealSlot.forHour(ref.read(localHourProvider));
  bool? _fromMess;
  final Set<String> _have = <String>{};
  final List<String> _typed = <String>[];
  final _other = TextEditingController();
  final _feel = TextEditingController();
  bool _busy = false;
  String? _error;
  FoodGuideResponse? _answer;

  @override
  void dispose() {
    _other.dispose();
    _feel.dispose();
    super.dispose();
  }

  List<String> get _all => [..._have, ..._typed];

  void _addTyped() {
    final t = _other.text.trim();
    if (t.isEmpty || _all.length >= kGuideHaveMax) return;
    setState(() {
      if (!_typed.contains(t)) _typed.add(t);
      _other.clear();
    });
  }

  Future<void> _ask(bool hasMess) async {
    // FITOS AI is premium, and its own consent (asked once, before first use).
    if (!await ensurePremium(context, ref, feature: 'What should I eat?') ||
        !mounted) {
      return;
    }
    if (!await ensureAiConsent(context, ref) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final feel = _feel.text.trim();
    final r = await ref.read(aiApiProvider).foodGuide(
          FoodGuideRequest(
            slot: _slot,
            fromMess: hasMess && (_fromMess ?? true),
            have: _all,
            feel: feel.isEmpty ? null : feel,
          ),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Ok(:final value):
          _answer = value;
        case Err(:final failure):
          _error = aiFailureText(failure);
      }
    });
  }

  Future<void> _log(FoodGuideResponse a, GuideOption o) async {
    await ref.read(foodLoggerProvider).logGuidePlate(
          option: o,
          messCode: a.messCode,
          menuDate: a.menuDate,
          target: LogTarget(date: a.date, slot: a.slot),
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final today = ref.watch(localTodayProvider);
    final hasMess = ref.watch(messMenuProvider((date: today, code: null))).value
        is MenuLoaded;
    final fromMess = hasMess && (_fromMess ?? true);
    final ready = !_busy && (fromMess || _all.isNotEmpty);
    final answer = _answer;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        centerTitle: false,
        title: Text('WHAT SHOULD I EAT?', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            key: const ValueKey('guide.list'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              Text(
                'Tell FITOS AI what you have, and it suggests a plate that '
                'fits what is left of your day. The numbers are FITOS\'s own.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.lg),
              Text('MEAL', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Wrap(
                spacing: FitSpacing.sm,
                runSpacing: FitSpacing.sm,
                children: <Widget>[
                  for (final s in MealSlot.values)
                    ChoiceChip(
                      key: ValueKey('guide.slot.${s.wire}'),
                      label: Text(s.label),
                      selected: _slot == s,
                      onSelected:
                          _busy ? null : (_) => setState(() => _slot = s),
                    ),
                ],
              ),
              if (hasMess) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                SwitchListTile(
                  key: const ValueKey('guide.mess'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text("From today's mess menu"),
                  subtitle: const Text('Only dishes that fit your diet'),
                  value: fromMess,
                  onChanged:
                      _busy ? null : (v) => setState(() => _fromMess = v),
                ),
              ],
              const SizedBox(height: FitSpacing.md),
              Text('WHAT I HAVE', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Wrap(
                spacing: FitSpacing.sm,
                runSpacing: FitSpacing.sm,
                children: <Widget>[
                  for (final item in kGuideCommonItems)
                    FilterChip(
                      key: ValueKey('guide.have.$item'),
                      label: Text(item),
                      selected: _have.contains(item),
                      onSelected: _busy
                          ? null
                          : (on) => setState(() {
                                if (!on) {
                                  _have.remove(item);
                                } else if (_all.length < kGuideHaveMax) {
                                  _have.add(item);
                                }
                              }),
                    ),
                  for (final t in _typed)
                    InputChip(
                      key: ValueKey('guide.typed.$t'),
                      label: Text(t),
                      onDeleted:
                          _busy ? null : () => setState(() => _typed.remove(t)),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.sm),
              TextField(
                key: const ValueKey('guide.other'),
                controller: _other,
                enabled: !_busy,
                maxLength: kGuideHaveItemMax,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Something else (e.g. 2 bananas)',
                  suffixIcon: IconButton(
                    key: const ValueKey('guide.other.add'),
                    tooltip: 'Add',
                    icon: const Icon(Icons.add),
                    onPressed: _busy ? null : _addTyped,
                  ),
                ),
                onSubmitted: (_) => _addTyped(),
              ),
              TextField(
                key: const ValueKey('guide.feel'),
                controller: _feel,
                enabled: !_busy,
                maxLength: kGuideFeelMax,
                decoration: const InputDecoration(
                  hintText: 'I feel like… (optional, e.g. something spicy)',
                ),
              ),
              const SizedBox(height: FitSpacing.sm),
              FilledButton.icon(
                key: const ValueKey('guide.ask'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: ready ? () => _ask(hasMess) : null,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_busy ? 'Thinking…' : 'Suggest'),
              ),
              if (_error case final e?)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.sm),
                  child: Text(
                    e,
                    key: const ValueKey('guide.error'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                  ),
                ),
              if (answer != null) ..._results(context, answer),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _results(BuildContext context, FoodGuideResponse a) {
    final textTheme = Theme.of(context).textTheme;
    final notes = <String>[
      if (a.messNote case final n?) n,
      if (a.unknown.isNotEmpty)
        'Not in FITOS yet, so not used: ${a.unknown.join(', ')}.',
      if (a.refused.isNotEmpty)
        'Left out for your diet or allergies: ${a.refused.join(', ')}.',
    ];
    return <Widget>[
      const SizedBox(height: FitSpacing.lg),
      for (final n in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: FitSpacing.xs),
          child: Text(
            n,
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ),
      if (a.options.isEmpty)
        Text(
          'FITOS AI could not make a sensible plate from that. Add a few more things you have.',
          key: const ValueKey('guide.none'),
          style: textTheme.bodyLarge,
        ),
      for (var i = 0; i < a.options.length; i++)
        _OptionCard(
          key: ValueKey('guide.option.$i'),
          index: i,
          option: a.options[i],
          remainingKcal: a.remainingKcal,
          remainingProteinG: a.remainingProteinG,
          onLog: () => _log(a, a.options[i]),
        ),
    ];
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.index,
    required this.option,
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.onLog,
    super.key,
  });

  final int index;
  final GuideOption option;
  final int? remainingKcal;
  final int? remainingProteinG;
  final VoidCallback onLog;

  /// "Fills 32 of your 55 g protein left · about 520 of 700 kcal".
  String? get _fit {
    final p = remainingProteinG;
    final k = remainingKcal;
    if (p == null || k == null) return null;
    final protein = option.totals.proteinG;
    final kcal = option.totals.kcal;
    final proteinPart = p == 0
        ? 'Protein for today is covered'
        : 'Fills ${protein > p ? p : protein} of your $p g protein left';
    return '$proteinPart · about $kcal of $k kcal left';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FitBlock(
      padding: const EdgeInsets.all(FitSpacing.md),
      flatPadding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      margin: const EdgeInsets.only(bottom: FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(option.title, style: textTheme.titleMedium),
          if (option.why.isNotEmpty)
            Text(option.why, style: textTheme.bodyMedium),
          const SizedBox(height: FitSpacing.sm),
          for (final item in option.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${FoodFormat.number(item.servings)} × ${item.servingLabel} '
                '${item.name}${item.fromMess ? ' (mess)' : ''} · '
                '${item.macros.kcal} kcal · ${item.macros.proteinG} g protein',
                style: textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'About ${option.totals.kcal} kcal · ${option.totals.proteinG} g protein',
            key: ValueKey('guide.option.$index.totals'),
            style: textTheme.labelLarge,
          ),
          if (_fit case final f?)
            Text(
              f,
              key: ValueKey('guide.option.$index.fit'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.pine),
            ),
          if (option.caution.isNotEmpty)
            Text(
              'Check the label for: ${option.caution.join(', ')}',
              key: ValueKey('guide.option.$index.caution'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.amber),
            ),
          const SizedBox(height: FitSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: ValueKey('guide.option.$index.log'),
              onPressed: onLog,
              child: const Text('Log this'),
            ),
          ),
        ],
      ),
    );
  }
}
