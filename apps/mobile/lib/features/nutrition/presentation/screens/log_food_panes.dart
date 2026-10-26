part of 'log_food_screen.dart';

/* -------------------------------------------------------------- mess -- */

/// Phase 9: the chosen meal's dishes from the user's mess menu for the day.
/// Tap one for the portion step; it logs through the Phase 8 queue.
class _MessPane extends ConsumerWidget {
  const _MessPane({
    required this.date,
    required this.slot,
    required this.onLogged,
  });

  final String date;
  final MealSlot slot;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(messMenuProvider((date: date, code: null))).value;
    if (state is! MenuLoaded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final menu = state.menu;
    final meal = menu.meal(slot);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
      sliver: SliverList.list(
        children: <Widget>[
          const SizedBox(height: FitSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${slot.label.toUpperCase()} · ${menu.mess.label.toUpperCase()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall,
                ),
              ),
              TextButton(
                key: const ValueKey('log.mess.full'),
                onPressed: () {
                  ref.read(messDateProvider.notifier).set(date);
                  context.push(Routes.mess);
                },
                child: const Text('Full menu'),
              ),
            ],
          ),
          MenuStatus(state: state, now: DateTime.now()),
          if (meal == null || meal.dishes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
              child: Text(
                'No ${slot.label.toLowerCase()} on this menu.',
                key: const ValueKey('log.mess.empty'),
                style: textTheme.bodyLarge,
              ),
            )
          else
            for (final dish in <MessDish>[
              ...meal.dishes.where((d) => !d.isAmbient),
              ...meal.dishes.where((d) => d.isAmbient),
            ])
              MessDishRow(
                dish: dish,
                logged: menu.isLogged(dish.slug),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  final logged = await openMessDish(
                    context,
                    ref,
                    dish: dish,
                    menu: menu,
                    slot: slot,
                  );
                  if (logged) onLogged();
                },
              ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ shared -- */

/// A food to pick: name; source badge and the nutrition of its first
/// serving (a range when estimated); an add affordance. Compact, one row.
class LogFoodRow extends StatelessWidget {
  const LogFoodRow({
    required this.food,
    required this.onTap,
    this.detail,
    super.key,
  });

  final Food food;
  final VoidCallback onTap;

  /// A line that replaces the default nutrition summary's lead ("Last: …").
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = food.headline;
    final summary = '${FoodFormat.kcal(row)} · '
        '${FoodFormat.about(row.proteinLow, row.proteinHigh)} g protein · '
        '${FoodFormat.servingShort(row)}';
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.sm,
            FitSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      food.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        FoodSourceBadge(food: food),
                        const SizedBox(width: FitSpacing.sm),
                        Expanded(
                          child: Text(
                            detail == null ? summary : '$detail · $summary',
                            style: textTheme.bodyMedium?.copyWith(
                              color: FitColors.ink60,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.screen,
        FitSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: textTheme.labelSmall),
          if (caption != null)
            Text(
              caption!,
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
        ],
      ),
    );
  }
}

/// A message as a sliver: what happened, what to do (§6.6).
class _MessageSliver extends StatelessWidget {
  const _MessageSliver({
    required this.title,
    required this.body,
    this.icon,
    this.action,
  });

  final String title;
  final String body;
  final IconData? icon;

  /// Beta 3.2: under the body, e.g. "Ask us to add it".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: FitColors.ink60),
              const SizedBox(width: FitSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: FitSpacing.xs),
                  Text(
                    body,
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                  if (action != null) ...<Widget>[
                    const SizedBox(height: FitSpacing.md),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static skeleton rows while a list loads (no spinner, §6.6).
class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) => SliverList.list(
        children: <Widget>[
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FitSpacing.screen,
                vertical: FitSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 140 + (i % 3) * 40.0,
                    height: 16,
                    color: FitColors.paper2,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  Container(width: 200, height: 12, color: FitColors.paper2),
                ],
              ),
            ),
        ],
      );
}

typedef _PickFood = Future<void> Function(
  Food food, {
  String? rowLabel,
  NutritionBasis? rowBasis,
  double? servings,
});

/// Recent foods as slivers (under a title), or nothing when there are none.
List<Widget> _recentSlivers(
  BuildContext context,
  AsyncValue<Cached<List<RecentFood>>> async,
  _PickFood onPick, {
  required bool showEmpty,
}) {
  return switch (async) {
    AsyncData(:final value) when value.value.isEmpty => [
        if (showEmpty)
          const _MessageSliver(
            icon: Icons.history,
            title: 'Nothing logged yet',
            body:
                'Foods you log show up here with the portion you used last, ready to log again.',
          ),
      ],
    AsyncData(:final value) => [
        SliverToBoxAdapter(
          child: _SectionTitle(
            'Recent',
            caption: value.stale ? 'Offline — as last loaded.' : null,
          ),
        ),
        SliverList.separated(
          itemCount: value.value.length,
          separatorBuilder: (_, __) => fitGlass
              ? const SizedBox.shrink()
              : Divider(color: FitColors.rule, height: 1),
          itemBuilder: (_, i) {
            final r = value.value[i];
            return FitSegment(
              index: i,
              count: value.value.length,
              child: LogFoodRow(
                key: ValueKey('recent.${r.food.slug}'),
                food: r.food,
                detail:
                    'Last ${FoodFormat.number(r.lastServings)} × ${r.lastServingLabel}',
                onTap: () => onPick(
                  r.food,
                  rowLabel: r.lastServingLabel,
                  rowBasis: r.lastBasis,
                  servings: r.lastServings,
                ),
              ),
            );
          },
        ),
      ],
    AsyncError(:final error) => [
        if (showEmpty)
          _MessageSliver(
            icon: Icons.cloud_off_outlined,
            title: 'Recent foods are not available',
            body: failureOf(error) is Offline
                ? 'Offline, and nothing was loaded before. Quick add works offline.'
                : failureOf(error).message,
          ),
      ],
    _ => [if (showEmpty) const _SkeletonSliver()],
  };
}

/* ------------------------------------------------------------ recent -- */

class _RecentPane extends ConsumerWidget {
  const _RecentPane({required this.onPick});

  final _PickFood onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverMainAxisGroup(
      slivers: _recentSlivers(
        context,
        ref.watch(recentFoodsProvider),
        onPick,
        showEmpty: true,
      ),
    );
  }
}

/* ------------------------------------------------------------ search -- */

class _SearchPane extends ConsumerStatefulWidget {
  const _SearchPane({required this.onPick});

  final void Function(Food food) onPick;

  @override
  ConsumerState<_SearchPane> createState() => _SearchPaneState();
}

class _SearchPaneState extends ConsumerState<_SearchPane> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _set(String v) => setState(() => _q = v.trim());

  @override
  Widget build(BuildContext context) {
    final results = _q.isEmpty ? null : ref.watch(logSearchProvider(_q));
    return SliverMainAxisGroup(
      slivers: <Widget>[
        // Pinned: stays above the results — and above the keyboard, since
        // the Scaffold shrinks the viewport for it.
        PinnedHeaderSliver(
          child: ColoredBox(
            color: FitColors.paper,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                FitSpacing.sm,
              ),
              child: TextField(
                key: const ValueKey('log.search'),
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search foods — dal, roti, idly…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            _set('');
                          },
                        ),
                ),
                onChanged: (v) {
                  setState(() {}); // the clear button
                  _debounce?.cancel();
                  _debounce =
                      Timer(const Duration(milliseconds: 250), () => _set(v));
                },
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _set(v);
                },
              ),
            ),
          ),
        ),
        if (results == null)
          ..._recentSlivers(
            context,
            ref.watch(recentFoodsProvider),
            (food, {rowLabel, rowBasis, servings}) async => widget.onPick(food),
            showEmpty: false,
          )
        else
          ...switch (results) {
            AsyncData(:final value) when value.isEmpty => [
                _MessageSliver(
                  icon: Icons.search_off,
                  title: 'No food matches “$_q”',
                  body:
                      'Try a shorter name, add it from its label in the Food library, or use Quick add.',
                  action: AskToAddFood(query: _q),
                ),
              ],
            AsyncData(:final value) => [
                const SliverToBoxAdapter(child: _SectionTitle('Results')),
                SliverList.separated(
                  key: const ValueKey('log.results'),
                  itemCount: value.length,
                  separatorBuilder: (_, __) => fitGlass
                      ? const SizedBox.shrink()
                      : Divider(color: FitColors.rule, height: 1),
                  itemBuilder: (_, i) => FitSegment(
                    index: i,
                    count: value.length,
                    child: LogFoodRow(
                      key: ValueKey('food.${value[i].food.slug}'),
                      food: value[i].food,
                      onTap: () => widget.onPick(value[i].food),
                    ),
                  ),
                ),
              ],
            AsyncError(:final error) => [
                _MessageSliver(
                  icon: Icons.cloud_off_outlined,
                  title: 'Search needs a connection',
                  body: failureOf(error) is Offline
                      ? 'Recent foods, saved meals and quick add work offline.'
                      : failureOf(error).message,
                ),
              ],
            _ => [const _SkeletonSliver()],
          },
      ],
    );
  }
}
