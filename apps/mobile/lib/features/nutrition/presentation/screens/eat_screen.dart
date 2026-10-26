import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../ai/presentation/controllers/ai_providers.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../mess/presentation/widgets/mess_widgets.dart';
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food_log.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/food_widgets.dart';
import '../widgets/log_controls.dart';
import 'food_guide_screen.dart';
import '../../../../shared/widgets/fit_glass.dart';

part 'eat_meals.dart';
part 'eat_entries.dart';

/// The Nutrition tab (Phase 8): EAT.
///
///   EAT                               Food library
///   ‹            Today · Thu 24 Sep            ›
///   REMAINING
///   1,240–1,420                     (the hero)
///   kcal left of 2,400
///   PROTEIN · CARBS · FAT strip, eaten, fibre
///   [ Log food ]
///   Breakfast / Lunch / Snacks / Dinner, each with "Add"
///
/// One vertical scroll (a ListView under pull-to-refresh). Every total is the
/// server's; a log not yet confirmed is listed as "Not synced yet" with a
/// preview and is NOT in any total (owner J10).
class EatScreen extends ConsumerWidget {
  const EatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(eatDateProvider);
    final today = ref.watch(eatDateProvider.notifier).today;
    final view = ref.watch(nutritionDayViewProvider(date));
    final refresh = ref.watch(nutritionDayRefreshProvider(date));

    return Scaffold(
      body: FitBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(nutritionDayRefreshProvider(date));
              await ref.read(nutritionDayRefreshProvider(date).future);
            },
            child: ListView(
              key: const ValueKey('eat.list'),
              padding: EdgeInsets.fromLTRB(
                fitGlass ? FitSpacing.md : FitSpacing.screen,
                FitSpacing.md,
                fitGlass ? FitSpacing.md : FitSpacing.screen,
                // Room for the floating bar.
                fitGlass ? 112 : FitSpacing.xl,
              ),
              children: <Widget>[
                _Header(date: date, today: today),
                const SizedBox(height: FitSpacing.md),
                ...view.when(
                  loading: () => const <Widget>[_HeroSkeleton()],
                  error: (e, _) => <Widget>[
                    AuthFeedback.error(failureOf(e).message),
                  ],
                  data: (v) => _dayBody(context, ref, v, refresh, today),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dayBody(
    BuildContext context,
    WidgetRef ref,
    DayView v,
    AsyncValue<Result<NutritionDay>> refresh,
    String today,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final server = v.server;
    final refreshFailure = switch (refresh) {
      AsyncData(value: Err(:final failure)) => failure,
      AsyncError(:final error) => failureOf(error),
      _ => null,
    };
    final loggable = canLogOn(v.date, today);

    final notices = <Widget>[
      if (refreshFailure != null && server != null)
        EatNotice(
          key: const ValueKey('eat.stale'),
          text: refreshFailure is Offline
              ? 'Offline — showing this day as it was last loaded${_at(v.storedAt)}.'
              : 'Could not refresh — showing this day as it was last loaded${_at(v.storedAt)}.',
        ),
      if (v.parkedCount > 0)
        EatNotice(
          key: const ValueKey('eat.parked'),
          text:
              '${v.parkedCount} food ${v.parkedCount == 1 ? 'change' : 'changes'} not synced',
          action: 'Retry',
          colour: FitColors.oxide,
          onAction: () =>
              ref.read(nutritionLogRepositoryProvider).retryParked(),
        )
      else if (v.unsyncedCount > 0)
        EatNotice(
          key: const ValueKey('eat.unsynced'),
          text:
              '${v.unsyncedCount} waiting to sync — totals update when FITOS has them.',
        ),
    ];

    final meals = _meals(v, server, loggable);

    if (server == null) {
      return <Widget>[
        ...notices,
        if (refresh.isLoading) const _HeroSkeleton(),
        if (refreshFailure != null) ...<Widget>[
          Text('Could not load this day', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          AuthFeedback.error(refreshFailure.message),
          const SizedBox(height: FitSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey('eat.retryLoad'),
              onPressed: () =>
                  ref.invalidate(nutritionDayRefreshProvider(v.date)),
              child: const Text('Try again'),
            ),
          ),
          const SizedBox(height: FitSpacing.lg),
        ],
        if (loggable) _LogButton(date: v.date),
        if (v.pending.isNotEmpty) ...meals,
      ];
    }

    final empty = server.totals.isEmpty && v.pending.isEmpty;
    return <Widget>[
      ...notices,
      FitBlock(
        glow: true,
        padding: const EdgeInsets.all(FitSpacing.md),
        child: _Hero(day: server),
      ),
      if (empty) ...<Widget>[
        const SizedBox(height: FitSpacing.sm),
        Text(
          v.date == today
              ? 'Nothing logged today.'
              : 'Nothing logged on this day.',
          key: const ValueKey('eat.empty'),
          style: textTheme.bodyLarge,
        ),
        if (!loggable)
          Text(
            'Food can be logged up to 30 days back.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
      ],
      const SizedBox(height: FitSpacing.md),
      if (loggable) _LogButton(date: v.date),
      // Beta 3.6 (F15): FITOS AI suggests a plate (today only).
      if (v.date == today &&
          ref.watch(aiAvailableProvider) &&
          ref.watch(featureOnProvider(AppFeature.foodGuide)))
        Padding(
          padding: const EdgeInsets.only(top: FitSpacing.sm),
          child: OutlinedButton.icon(
            key: const ValueKey('eat.guide'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => showFoodGuide(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ask FITOS AI what to eat'),
          ),
        ),
      // Phase 9: today's mess menu, for anyone with a mess (hidden otherwise).
      if (v.date == today) TodaysMessStrip(today: today),
      const SizedBox(height: FitSpacing.md),
      ...meals,
    ];
  }

  static String _at(String? storedAt) {
    if (storedAt == null) return '';
    final t = DateTime.tryParse(storedAt)?.toLocal();
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return ' at $hh:$mm';
  }

  /// All four meals, always: an empty meal says so and offers "Add".
  List<Widget> _meals(DayView v, NutritionDay? server, bool loggable) => [
        for (final slot in MealSlot.values)
          _MealSection(
            date: v.date,
            slot: slot,
            logs: server?.logs.where((l) => l.mealSlot == slot).toList() ??
                const <FoodLog>[],
            pending: v.pending.where((p) => p.mealSlot == slot).toList(),
            deleting: v.deleting,
            loggable: loggable,
          ),
      ];
}

class _Header extends ConsumerWidget {
  const _Header({required this.date, required this.today});

  final String date;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(eatDateProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('EAT', style: textTheme.labelSmall),
            const Spacer(),
            // Flexible: at 200 % text the label ellipsises instead of overflowing.
            Flexible(
              child: TextButton.icon(
                key: const ValueKey('eat.library'),
                onPressed: () => context.push(Routes.foodLibrary),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text(
                  'Food library',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        // ‹  Today · Thu 24 Sep  ›  — compact; tap the date to come back to today.
        Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey('eat.prev'),
              tooltip: 'Previous day',
              onPressed: notifier.previous,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                onTap: date == today ? null : notifier.toToday,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        EatFormat.dayLabel(date, today),
                        key: const ValueKey('eat.date'),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        date == today
                            ? EatFormat.shortDate(date)
                            : 'Tap to go back to today',
                        style: textTheme.bodyMedium?.copyWith(
                          color: FitColors.ink60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('eat.next'),
              tooltip: 'Next day',
              onPressed: date == today ? null : notifier.next,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const FitRule(),
      ],
    );
  }
}
