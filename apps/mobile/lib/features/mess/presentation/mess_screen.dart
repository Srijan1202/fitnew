import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/presentation/widgets/auth_form_field.dart';
import '../../nutrition/domain/entities/food_log.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../nutrition/presentation/widgets/eat_widgets.dart';
import '../../profile/presentation/widgets/mess_setting.dart';
import '../data/mess_repository.dart';
import '../domain/mess.dart';
import 'mess_providers.dart';
import 'widgets/mess_sheets.dart';
import 'widgets/mess_widgets.dart';

/// MESS (Phase 9, §31): a mess menu for a day, by meal.
///
///   MESS                                   [swap]
///   Men's Hostel · Vegetarian
///   ‹            Today · Thu 24 Sep            ›
///   (inferred / unavailable banner, freshness, offline copy)
///   Breakfast — dishes (diet mark, name, estimate, logged ✓)
///   Lunch · Snacks · Dinner
///   As published ▸  (the mess's own text)
///
/// Served from the server's mirror; the qualifiers are always shown. Tap a
/// dish with an estimate to log it (Phase 8 portion step and queue).
class MessScreen extends ConsumerWidget {
  const MessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final date = ref.watch(messDateProvider);
    final dates = ref.read(messDateProvider.notifier);
    final code = ref.watch(messBrowseProvider);
    final key = (date: date, code: code);
    final state = ref.watch(messMenuProvider(key));
    final today = dates.today;
    final loaded =
        state.value is MenuLoaded ? state.value! as MenuLoaded : null;

    Future<void> browse() async {
      final choice = await showMessPicker(
        context,
        currentCode: loaded?.menu.mess.code,
        title: 'Show another mess',
      );
      if (choice?.mess != null) {
        ref.read(messBrowseProvider.notifier).show(choice!.mess!.code);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('MESS', style: textTheme.labelSmall),
            Text(
              loaded?.menu.mess.label ?? 'Mess menu',
              key: const ValueKey('mess.title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey('mess.switch'),
            tooltip: 'Show another mess',
            onPressed: browse,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(messMenuProvider(key));
            await ref.read(messMenuProvider(key).future);
          },
          child: ListView(
            key: const ValueKey('mess.list'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              0,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              if (code != null)
                EatNotice(
                  key: const ValueKey('mess.browsing'),
                  text: 'Showing another mess. Your own mess is unchanged.',
                  action: 'Mine',
                  onAction: () =>
                      ref.read(messBrowseProvider.notifier).show(null),
                ),
              _DateBar(date: date, today: today),
              ...state.when(
                loading: () => const <Widget>[
                  Padding(
                    padding: EdgeInsets.all(FitSpacing.lg),
                    child: Center(
                      child: Text('Loading the menu…'),
                    ),
                  ),
                ],
                error: (e, _) => <Widget>[
                  const AuthFeedback.error('Could not load the menu.'),
                ],
                data: (s) => switch (s) {
                  MenuNotConfigured() => <Widget>[
                      const SizedBox(height: FitSpacing.md),
                      Text(
                        'Choose your mess',
                        key: const ValueKey('mess.notConfigured'),
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: FitSpacing.xs),
                      Text(
                        'FITOS shows your VIT mess menu here, with an estimate for each dish.',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FitColors.ink60),
                      ),
                      const SizedBox(height: FitSpacing.md),
                      const MessSettingButton(),
                    ],
                  MenuFailed(:final failure) => <Widget>[
                      const SizedBox(height: FitSpacing.md),
                      AuthFeedback.error(failure.message),
                      const SizedBox(height: FitSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          key: const ValueKey('mess.retry'),
                          onPressed: () =>
                              ref.invalidate(messMenuProvider(key)),
                          child: const Text('Try again'),
                        ),
                      ),
                    ],
                  final MenuLoaded m => _menuBody(context, ref, m),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _menuBody(BuildContext context, WidgetRef ref, MenuLoaded s) {
    final menu = s.menu;
    return <Widget>[
      MenuStatus(state: s, now: DateTime.now()),
      for (final meal in menu.meals) ...<Widget>[
        MessMealHeader(
          meal: meal,
          key: ValueKey('mess.meal.${meal.slot.wire}'),
        ),
        const Divider(color: FitColors.rule, height: 1),
        // Ambient items (bread, tea, jam…) after the meal's own dishes.
        for (final dish in <MessDish>[
          ...meal.dishes.where((d) => !d.isAmbient),
          ...meal.dishes.where((d) => d.isAmbient),
        ])
          MessDishRow(
            dish: dish,
            logged: menu.isLogged(dish.slug),
            onTap: () => _tap(context, ref, menu, meal.slot, dish),
          ),
        _AsPublished(meal: meal),
      ],
    ];
  }

  Future<void> _tap(
    BuildContext context,
    WidgetRef ref,
    MessMenu menu,
    MealSlot slot,
    MessDish dish,
  ) async {
    final logged = await openMessDish(
      context,
      ref,
      dish: dish,
      menu: menu,
      slot: slot,
    );
    if (logged && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${dish.name}.')),
      );
    }
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date, required this.today});

  final String date;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final n = ref.read(messDateProvider.notifier);
    return Row(
      children: <Widget>[
        IconButton(
          key: const ValueKey('mess.prev'),
          tooltip: 'Previous day',
          onPressed: n.canGoBack ? n.previous : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: InkWell(
            onTap: date == today ? null : n.toToday,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _label(date, today),
                    key: const ValueKey('mess.date'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    date == today
                        ? EatFormat.shortDate(date)
                        : 'Tap to go back to today',
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('mess.next'),
          tooltip: 'Next day',
          onPressed: n.canGoForward ? n.next : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  static String _label(String date, String today) => date == shiftDate(today, 1)
      ? 'Tomorrow'
      : EatFormat.dayLabel(date, today);
}

/// The mess's own text for the meal, verbatim (owner D20), behind a toggle.
class _AsPublished extends StatefulWidget {
  const _AsPublished({required this.meal});

  final MessMeal meal;

  @override
  State<_AsPublished> createState() => _AsPublishedState();
}

class _AsPublishedState extends State<_AsPublished> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('mess.raw.${widget.meal.slot.wire}'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: const Text('As published'),
          ),
        ),
        if (_open)
          Text(
            widget.meal.rawMenu,
            key: ValueKey('mess.raw.${widget.meal.slot.wire}.text'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
      ],
    );
  }
}
