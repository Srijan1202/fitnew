import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../nutrition/domain/entities/food_log.dart';
import '../../../nutrition/presentation/widgets/eat_widgets.dart';
import '../../../nutrition/presentation/widgets/food_widgets.dart';
import '../../../nutrition/presentation/widgets/log_controls.dart';
import '../../data/mess_repository.dart';
import '../../domain/mess.dart';
import '../mess_providers.dart';

/// Words for the mess screens. Every number is the server's.
abstract final class MessFormat {
  /// "120–185 kcal · 1 katori", or "No estimate yet".
  static String dishLine(MessDish d) {
    final n = d.nutrition;
    if (n == null) return 'No estimate yet';
    return '${FoodFormat.kcal(n)} · ${n.servingLabel}';
  }

  /// "3 h ago", "2 days ago", from an ISO instant; '' when unknown.
  static String ago(String? iso, DateTime now) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return '';
    final d = now.difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    final days = d.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }

  /// "14:05" local, from an ISO instant.
  static String clock(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

/// The diet mark: the national veg / non-veg convention (a dot in a square),
/// with its label for screen readers. `unknown` is hollow and grey — never
/// drawn as veg (§14.5).
class DietMark extends StatelessWidget {
  const DietMark({required this.diet, super.key});

  final DietClass diet;

  Color get _colour => switch (diet) {
        DietClass.veg => FitColors.pine,
        DietClass.egg => FitColors.amber,
        DietClass.nonveg => FitColors.oxide,
        DietClass.unknown => FitColors.ink35,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: diet.label,
      excludeSemantics: true,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          border: Border.all(color: _colour, width: 1.5),
          borderRadius: const BorderRadius.all(FitRadius.small),
        ),
        alignment: Alignment.center,
        child: diet == DietClass.unknown
            ? null
            : Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _colour,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

/// One dish: diet mark, name, estimate and serving; a tick when logged.
/// Compact, holds at 200 % text (the name wraps to two lines, the rest
/// ellipsises).
class MessDishRow extends StatelessWidget {
  const MessDishRow({
    required this.dish,
    required this.logged,
    required this.onTap,
    super.key,
  });

  final MessDish dish;
  final bool logged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = dish.isAmbient;
    return InkWell(
      key: ValueKey('mess.dish.${dish.slug}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: DietMark(diet: dish.diet),
              ),
              const SizedBox(width: FitSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dish.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (muted ? textTheme.bodyLarge : textTheme.titleMedium)
                              ?.copyWith(color: muted ? FitColors.ink60 : null),
                    ),
                    Text(
                      [
                        MessFormat.dishLine(dish),
                        if (dish.correctionPending) 'report pending',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: dish.nutrition == null
                            ? FitColors.ink35
                            : FitColors.ink60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FitSpacing.sm),
              if (logged)
                const Icon(
                  Icons.check,
                  key: ValueKey('mess.logged'),
                  size: 20,
                  color: FitColors.pine,
                  semanticLabel: 'Logged',
                )
              else if (dish.nutrition != null)
                const Icon(Icons.add_circle_outline, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}

/// The qualifiers every menu carries (§14.4, owner D19/D20): how the menu was
/// found, how fresh the server's copy is, and whether this is the phone's
/// saved copy. An inferred menu is NEVER shown without its banner.
class MenuStatus extends StatelessWidget {
  const MenuStatus({required this.state, required this.now, super.key});

  final MenuLoaded state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final menu = state.menu;
    final fresh = menu.mess.freshness;
    final r = menu.resolution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (r is InferredMenu)
          _Banner(
            key: const ValueKey('mess.inferred'),
            title: 'Inferred menu',
            text:
                'The mess has not published ${EatFormat.shortDate(r.date)}. It repeats every ${r.cycleLengthDays} days, so this is the menu of ${EatFormat.shortDate(r.sourceDate)}. It may differ.',
          ),
        if (r is UnavailableMenu)
          _Banner(
            key: const ValueKey('mess.unavailable'),
            title: 'No menu for this day',
            text: r.latestAvailable == null
                ? 'The mess has not published a menu FITOS could read.'
                : 'The mess has not published ${EatFormat.shortDate(r.date)}, and FITOS cannot infer it. The latest published day is ${EatFormat.shortDate(r.latestAvailable!)}.',
          ),
        if (state.fromCache)
          EatNotice(
            key: const ValueKey('mess.offline'),
            text: state.failure is Offline
                ? 'Offline — showing the menu saved on this phone at ${MessFormat.clock(state.storedAt)}.'
                : 'Could not refresh — showing the menu saved at ${MessFormat.clock(state.storedAt)}.',
          ),
        if (fresh.stale)
          EatNotice(
            key: const ValueKey('mess.stale'),
            colour: FitColors.amber,
            text: fresh.lastSuccessAt == null
                ? 'FITOS has not been able to fetch this mess menu yet.'
                : 'FITOS last fetched this menu ${MessFormat.ago(fresh.lastSuccessAt, now)}; the mess site may not be answering.',
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.text, super.key});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      padding: const EdgeInsets.all(FitSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: FitColors.amber, width: 3)),
        color: FitColors.paper2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(color: FitColors.amber),
          ),
          const SizedBox(height: 2),
          Text(text, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// EAT: today's mess, compact — the mess, the meal of the hour, how the
/// menu was found; tap for the whole menu. Hidden for anyone without a mess.
class TodaysMessStrip extends ConsumerWidget {
  const TodaysMessStrip({required this.today, super.key});

  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messMenuProvider((date: today, code: null))).value;
    if (state is! MenuLoaded) return const SizedBox.shrink();
    final menu = state.menu;
    final slot = MealSlot.forHour(ref.watch(localHourProvider));
    final meal = menu.meal(slot);
    final qualifier = switch (menu.resolution) {
      ExactMenu() => null,
      InferredMenu() => 'inferred',
      UnavailableMenu() => 'no menu published',
    };
    final line = meal == null
        ? 'No menu for today'
        : '${slot.label} · ${meal.dishes.where((d) => !d.isAmbient).length} dishes';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _strip(context, menu, line, qualifier, state.fromCache),
        // Phase 10: straight to today's suggestion.
        const SuggestedPlateLink(),
      ],
    );
  }

  Widget _strip(
    BuildContext context,
    MessMenu menu,
    String line,
    String? qualifier,
    bool fromCache,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: const ValueKey('eat.mess'),
      onTap: () => context.push(Routes.mess),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
          child: Row(
            children: <Widget>[
              const Icon(Icons.restaurant_outlined, color: FitColors.ink),
              const SizedBox(width: FitSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "TODAY'S MESS",
                      style: textTheme.labelSmall,
                    ),
                    Text(
                      menu.mess.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        line,
                        if (qualifier != null) qualifier,
                        if (fromCache) 'saved copy',
                      ].join(' · '),
                      key: const ValueKey('eat.mess.line'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: qualifier == null
                            ? FitColors.ink60
                            : FitColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}

/// A meal section header: icon, slot, how many dishes.
class MessMealHeader extends StatelessWidget {
  const MessMealHeader({required this.meal, super.key});

  final MessMeal meal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(mealSlotIcon(meal.slot), size: 20, color: FitColors.ink),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: Text(
              meal.slot.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// EAT: a link from the mess strip to today's suggestion.
class SuggestedPlateLink extends ConsumerWidget {
  const SuggestedPlateLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('eat.mess.suggest'),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () {
          ref.read(messDateProvider.notifier).toToday();
          ref.read(messBrowseProvider.notifier).show(null);
          context.push(Routes.mess);
        },
        icon: const Icon(Icons.restaurant_menu, size: 18),
        label: const Text('Suggested plate'),
      ),
    );
  }
}
