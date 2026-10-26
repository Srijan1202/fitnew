part of 'log_food_screen.dart';

/* ------------------------------------------------------- saved meals -- */

class _SavedPane extends ConsumerWidget {
  const _SavedPane({required this.target, required this.onLogged});

  final LogTarget target;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedMealsProvider);
    return SliverMainAxisGroup(
      slivers: switch (async) {
        AsyncData(:final value) when value.value.isEmpty => [
            const _MessageSliver(
              icon: Icons.bookmark_border,
              title: 'No saved meals yet',
              body:
                  'A meal you eat often can be logged in one tap: on EAT, "Save as meal" on a meal you have logged.',
            ),
          ],
        AsyncData(:final value) => [
            SliverToBoxAdapter(
              child: _SectionTitle(
                'Saved meals',
                caption: value.stale
                    ? 'Offline — as last loaded.'
                    : 'One tap logs the whole meal to ${target.slot.label}.',
              ),
            ),
            SliverList.separated(
              key: const ValueKey('log.saved'),
              itemCount: value.value.length,
              separatorBuilder: (_, __) => fitGlass
                  ? const SizedBox.shrink()
                  : Divider(color: FitColors.rule, height: 1),
              itemBuilder: (_, i) => FitSegment(
                index: i,
                count: value.value.length,
                child: _SavedMealTile(
                  meal: value.value[i],
                  target: target,
                  onLogged: onLogged,
                ),
              ),
            ),
          ],
        AsyncError(:final error) => [
            _MessageSliver(
              icon: Icons.cloud_off_outlined,
              title: 'Saved meals are not available',
              body: failureOf(error) is Offline
                  ? 'Offline, and none were loaded before.'
                  : failureOf(error).message,
            ),
          ],
        _ => [const _SkeletonSliver()],
      },
    );
  }
}

class _SavedMealTile extends ConsumerWidget {
  const _SavedMealTile({
    required this.meal,
    required this.target,
    required this.onLogged,
  });

  final SavedMeal meal;
  final LogTarget target;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final preview = PortionPreview.savedMeal(meal);
    final unavailable = preview == null;
    return Padding(
      key: ValueKey('saved.${meal.id}'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.sm,
        FitSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.bookmark, color: FitColors.ink),
          const SizedBox(width: FitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(meal.name, style: textTheme.titleMedium),
                Text(
                  meal.items.map((i) => i.name).join(' · '),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  unavailable
                      ? 'A food in this meal is no longer available.'
                      : '${EatFormat.kcal(preview.kcalLow, preview.kcalHigh)} kcal · preview',
                  style: textTheme.bodyMedium?.copyWith(
                    color: unavailable ? FitColors.oxide : FitColors.ink60,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('saved.${meal.id}.delete'),
            tooltip: 'Delete saved meal',
            icon: Icon(Icons.close, size: 18, color: FitColors.ink35),
            onPressed: () async {
              final r = await ref
                  .read(nutritionLogRepositoryProvider)
                  .deleteSavedMeal(meal.id);
              if (!context.mounted) return;
              if (r case Err(:final failure)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      failure is Offline
                          ? 'Deleting a saved meal needs a connection.'
                          : failure.message,
                    ),
                  ),
                );
              } else {
                ref.invalidate(savedMealsProvider);
              }
            },
          ),
          FilledButton(
            key: ValueKey('saved.${meal.id}.log'),
            onPressed: unavailable
                ? null
                : () async {
                    await ref
                        .read(foodLoggerProvider)
                        .logSavedMeal(meal, target: target);
                    onLogged();
                  },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- quick add -- */

/// Owner J6: kcal, protein, carbohydrate and fat required; fibre optional.
class _QuickAddPane extends ConsumerStatefulWidget {
  const _QuickAddPane({required this.target, required this.onLogged});

  final LogTarget target;
  final VoidCallback onLogged;

  @override
  ConsumerState<_QuickAddPane> createState() => _QuickAddPaneState();
}

class _QuickAddPaneState extends ConsumerState<_QuickAddPane> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carb = TextEditingController();
  final _fat = TextEditingController();
  final _fibre = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carb, _fat, _fibre]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String t) =>
      double.tryParse(t.trim().replaceAll(',', '.'));

  String? Function(String?) _amount({
    required bool required,
    required double max,
  }) =>
      (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return required ? 'Required.' : null;
        final n = _parse(t);
        if (n == null) return 'Enter a number.';
        if (n < 0) return 'Cannot be negative.';
        if (n > max) return 'At most ${max.toStringAsFixed(0)}.';
        return null;
      };

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    await ref.read(foodLoggerProvider).logQuickAdd(
          QuickAdd(
            name: name.isEmpty ? null : name,
            kcal: _parse(_kcal.text)!,
            proteinG: _parse(_protein.text)!,
            carbG: _parse(_carb.text)!,
            fatG: _parse(_fat.text)!,
            fibreG: _parse(_fibre.text),
          ),
          target: widget.target,
        );
    widget.onLogged();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const number = TextInputType.numberWithOptions(decimal: true);
    Widget field(
      String key,
      String label,
      TextEditingController c,
      String? Function(String?) v, {
      bool numeric = true,
    }) =>
        AuthFormField(
          fieldKey: ValueKey('quick.$key'),
          label: label,
          controller: c,
          keyboardType: numeric ? number : null,
          textInputAction: TextInputAction.next,
          validator: v,
        );
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: a),
            const SizedBox(width: FitSpacing.md),
            Expanded(child: b),
          ],
        );
    const gap = SizedBox(height: FitSpacing.md);
    return SliverToBoxAdapter(
      child: Padding(
        key: const ValueKey('log.quick'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.md,
          FitSpacing.screen,
          0,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.bolt_outlined, color: FitColors.ink),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: Text('Quick add', style: textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Numbers from a label or a menu. Calories, protein, carbs and '
                'fat are needed; fibre only if you know it. Logged exactly as '
                'typed, as your own entry.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              gap,
              field(
                'name',
                'Name (optional)',
                _name,
                (v) => (v?.trim().length ?? 0) > 60
                    ? 'At most 60 characters.'
                    : null,
                numeric: false,
              ),
              gap,
              field(
                'kcal',
                'Calories (kcal)',
                _kcal,
                _amount(required: true, max: 5000),
              ),
              gap,
              pair(
                field(
                  'protein',
                  'Protein (g)',
                  _protein,
                  _amount(required: true, max: 500),
                ),
                field(
                  'carb',
                  'Carbs (g)',
                  _carb,
                  _amount(required: true, max: 500),
                ),
              ),
              gap,
              pair(
                field(
                  'fat',
                  'Fat (g)',
                  _fat,
                  _amount(required: true, max: 500),
                ),
                field(
                  'fibre',
                  'Fibre (g, optional)',
                  _fibre,
                  _amount(required: false, max: 500),
                ),
              ),
              const SizedBox(height: FitSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('quick.log'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _submit,
                icon: Icon(mealSlotIcon(widget.target.slot)),
                label: Text('Add to ${widget.target.slot.label}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
