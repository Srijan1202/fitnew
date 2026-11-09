import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../nutrition/domain/portion_preview.dart';
import '../../nutrition/presentation/controllers/food_logger.dart';
import '../../premium/presentation/premium_providers.dart';
import '../../premium/presentation/premium_sheet.dart';
import '../data/mess_week_api.dart';
import '../domain/recommendation.dart';

final messWeekApiProvider = Provider<MessWeekApi>(
  (ref) => DioMessWeekApi(ref.watch(dioProvider)),
);

final messWeekProvider = FutureProvider<MessWeekPlan>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(messWeekApiProvider).week();
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Beta 6.1 (premium): this week at the mess — every served meal of today
/// and the next six days with the plate FITOS would suggest, planned as if
/// the day's earlier plates were eaten. Today's can be logged.
class MessWeekScreen extends ConsumerStatefulWidget {
  const MessWeekScreen({super.key});

  @override
  ConsumerState<MessWeekScreen> createState() => _MessWeekScreenState();
}

class _MessWeekScreenState extends ConsumerState<MessWeekScreen> {
  int _day = 0;
  final Set<String> _logged = {};
  String? _busy;

  static String _dayLabel(String iso, int i) {
    if (i == 0) return 'Today';
    if (i == 1) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = DateTime.parse(iso);
    return '${days[d.weekday - 1]} ${d.day}';
  }

  static String _why(RecommendationStatus s) => switch (s) {
        RecommendationStatus.noTargets =>
          'Set your targets first, and FITOS plans the plates.',
        RecommendationStatus.nothingSafe =>
          'Nothing at this meal suits your diet and allergies.',
        RecommendationStatus.noMeal ||
        RecommendationStatus.nothingFits =>
          'No full meal fits your targets here.',
        RecommendationStatus.targetReached =>
          'The day is covered by the meals before it.',
        _ => 'No plate for this meal.',
      };

  Future<void> _log(MessWeekPlan plan, MessWeekMeal meal) async {
    final plate = meal.plate!;
    setState(() => _busy = meal.slot.wire);
    await ref.read(foodLoggerProvider).logMessPlate(
      messCode: plan.mess.code,
      menuDate: plan.today,
      target: LogTarget(date: plan.today, slot: meal.slot),
      items: [
        for (final i in plate.items)
          (
            dishSlug: i.dishSlug,
            name: i.name,
            servings: i.servings,
            servingLabel: i.servingLabel,
            preview: PreviewNutrition(
              kcalLow: i.macros.kcalLow,
              kcalHigh: i.macros.kcalHigh,
              proteinLow: i.macros.proteinLow,
              proteinHigh: i.macros.proteinHigh,
              carbLow: i.macros.carbLow,
              carbHigh: i.macros.carbHigh,
              fatLow: i.macros.fatLow,
              fatHigh: i.macros.fatHigh,
              fibreLow: null,
              fibreHigh: null,
            ),
          ),
      ],
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      _logged.add(meal.slot.wire);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged to ${meal.slot.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = ref.watch(isPremiumProvider) == false;
    final async = locked ? null : ref.watch(messWeekProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('MESS · THIS WEEK', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              if (locked)
                const PremiumPitch(
                  key: ValueKey('week.premium'),
                  feature: 'The mess week plan',
                )
              else
                ...async!.when(
                  loading: () => const <Widget>[
                    Padding(
                      padding: EdgeInsets.all(FitSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => <Widget>[
                    Text(
                      (e is Failure ? e : const Unknown()).message,
                      key: const ValueKey('week.error'),
                    ),
                    if (e is Forbidden && e.issue == 'premium-required')
                      TextButton(
                        onPressed: () => showPremiumSheet(
                          context,
                          feature: 'The mess week plan',
                        ),
                        child: const Text('See Premium'),
                      ),
                  ],
                  data: (plan) => _body(context, plan),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, MessWeekPlan plan) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final day = plan.days[_day.clamp(0, plan.days.length - 1)];
    return <Widget>[
      Text(plan.mess.label, style: textTheme.titleMedium),
      Text(
        'Planned by FITOS from the menu, your diet and your targets.',
        style: muted,
      ),
      const SizedBox(height: FitSpacing.sm),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < plan.days.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: FitSpacing.xs),
                child: ChoiceChip(
                  key: ValueKey('week.day.$i'),
                  label: Text(_dayLabel(plan.days[i].date, i)),
                  selected: i == _day,
                  onSelected: (_) => setState(() => _day = i),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: FitSpacing.md),
      if (!day.hasMenu)
        Text(
          'The menu for this day is not out yet.',
          key: const ValueKey('week.noMenu'),
          style: textTheme.bodyMedium,
        )
      else ...<Widget>[
        if (day.inferred)
          Padding(
            padding: const EdgeInsets.only(bottom: FitSpacing.sm),
            child: Text(
              'The mess has not published this day yet: this is its usual menu.',
              key: const ValueKey('week.inferred'),
              style: muted?.copyWith(color: FitColors.amber),
            ),
          ),
        for (final m in day.meals)
          Padding(
            padding: const EdgeInsets.only(bottom: FitSpacing.sm),
            child: FitBlock(
              key: ValueKey('week.meal.${m.slot.wire}'),
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(m.slot.label.toUpperCase(), style: textTheme.labelSmall),
                  const SizedBox(height: FitSpacing.xs),
                  if (m.plate == null)
                    Text(_why(m.status), style: muted)
                  else ...<Widget>[
                    for (final i in m.plate!.items)
                      Text(
                        '${i.name} · ${i.servings} × ${i.servingLabel}',
                        style: textTheme.bodyMedium,
                      ),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      '${m.plate!.totals.kcalLow.round()}–${m.plate!.totals.kcalHigh.round()} kcal · '
                      '${m.plate!.totals.proteinLow.round()}–${m.plate!.totals.proteinHigh.round()} g protein',
                      style: muted,
                    ),
                    if (_day == 0) ...<Widget>[
                      const SizedBox(height: FitSpacing.sm),
                      if (_logged.contains(m.slot.wire))
                        Text(
                          'Logged.',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.pine),
                        )
                      else
                        OutlinedButton(
                          key: ValueKey('week.log.${m.slot.wire}'),
                          onPressed: _busy != null ? null : () => _log(plan, m),
                          child: Text('Log this to ${m.slot.label}'),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        Text(
          'The day: ${day.totals.kcalLow.round()}–${day.totals.kcalHigh.round()} kcal, '
          '${day.totals.proteinLow.round()}–${day.totals.proteinHigh.round()} g protein.',
          key: const ValueKey('week.totals'),
          style: muted,
        ),
      ],
    ];
  }
}
