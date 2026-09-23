import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/toggle_wrap.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/food.dart';
import '../controllers/food_providers.dart';

/// Add a food from its label (Phase 7). The numbers are the user's, stored
/// exactly as typed and marked as theirs: private, unverified. Checks mirror
/// the server's (§7.3); the server stays authoritative.
///
/// One `clientFoodId` per form: a save whose reply was lost is re-sent with
/// the same id, and the server answers with the food it already made.
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key});

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  static const _uuid = Uuid();

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _servingLabel = TextEditingController();
  final _servingGrams = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carb = TextEditingController();
  final _fat = TextEditingController();
  final _fibre = TextEditingController();

  late final String _clientFoodId = _uuid.v4();
  NutritionBasis _basis = NutritionBasis.perServing;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _brand,
      _servingLabel,
      _servingGrams,
      _kcal,
      _protein,
      _carb,
      _fat,
      _fibre,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? Function(String?) _amount({
    required bool required,
    required double max,
    String unit = 'g',
  }) =>
      (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return required ? 'Enter the label value.' : null;
        final v = _parse(text);
        if (v == null) return 'Enter a number.';
        if (v < 0) return 'Cannot be negative.';
        if (v > max) return 'At most ${max.toStringAsFixed(0)} $unit.';
        return null;
      };

  String? _text(String? value, {required bool required, required int max}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return required ? 'Required.' : null;
    if (t.length > max) return 'At most $max characters.';
    return null;
  }

  /// The rules that span fields, as the server applies them. Fibre is not
  /// added to the weight: labels count it inside carbohydrate.
  String? _crossCheck() {
    final kcal = _parse(_kcal.text) ?? 0;
    final grams = (_parse(_protein.text) ?? 0) +
        (_parse(_carb.text) ?? 0) +
        (_parse(_fat.text) ?? 0);
    if (_basis == NutritionBasis.per100g) {
      if (kcal > 900) return 'No food has more than 900 kcal per 100 g.';
      if (grams > 100) {
        return 'Protein, carbohydrate and fat add up to more than 100 g per 100 g.';
      }
    } else {
      final serving = _parse(_servingGrams.text);
      if (serving != null && grams > serving) {
        return 'Protein, carbohydrate and fat weigh more than the serving.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    final cross = _crossCheck();
    if (cross != null) {
      setState(() => _error = cross);
      return;
    }
    final perServing = _basis == NutritionBasis.perServing;
    final brand = _brand.text.trim();
    final request = CreateFoodRequest(
      clientFoodId: _clientFoodId,
      name: _name.text.trim(),
      brand: brand.isEmpty ? null : brand,
      basis: _basis,
      servingLabel: perServing ? _servingLabel.text.trim() : null,
      servingGrams: perServing ? _parse(_servingGrams.text) : null,
      kcal: _parse(_kcal.text)!,
      proteinG: _parse(_protein.text)!,
      carbG: _parse(_carb.text)!,
      fatG: _parse(_fat.text)!,
      fibreG: _parse(_fibre.text),
    );
    setState(() => _saving = true);
    final result = await ref.read(foodRepositoryProvider).create(request);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        ref.invalidate(foodSearchProvider);
        context.pushReplacement(Routes.foodDetail(value.id), extra: value);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final perServing = _basis == NutritionBasis.perServing;
    const decimal = TextInputType.numberWithOptions(decimal: true);
    Widget gap() => const SizedBox(height: FitSpacing.md);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('ADD A FOOD', style: textTheme.labelSmall),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            key: const ValueKey('food.form'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              Text('From its label', style: textTheme.displaySmall),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Copy the numbers from the nutrition label. Only you will see '
                'this food, and FITOS marks it as yours, not verified.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.lg),
              AuthFormField(
                fieldKey: const ValueKey('food.form.name'),
                label: 'Name',
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: (v) => _text(v, required: true, max: 80),
              ),
              gap(),
              AuthFormField(
                fieldKey: const ValueKey('food.form.brand'),
                label: 'Brand (optional)',
                controller: _brand,
                textInputAction: TextInputAction.next,
                validator: (v) => _text(v, required: false, max: 60),
              ),
              const SizedBox(height: FitSpacing.lg),
              Text('THE LABEL GIVES VALUES', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              ToggleWrap<NutritionBasis>(
                keyPrefix: 'food.form.basis',
                options: NutritionBasis.values,
                isSelected: (b) => b == _basis,
                onTap: (b) => setState(() => _basis = b),
                label: (b) => b.label,
                enabled: !_saving,
              ),
              if (perServing) ...<Widget>[
                gap(),
                AuthFormField(
                  fieldKey: const ValueKey('food.form.servingLabel'),
                  label: 'Serving, as the label says (e.g. 1 bar)',
                  controller: _servingLabel,
                  textInputAction: TextInputAction.next,
                  validator: (v) => _text(v, required: true, max: 60),
                ),
                gap(),
                AuthFormField(
                  fieldKey: const ValueKey('food.form.servingGrams'),
                  label: 'Serving weight in g (optional)',
                  controller: _servingGrams,
                  keyboardType: decimal,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final base = _amount(required: false, max: 5000)(v);
                    if (base != null) return base;
                    final g = _parse(v ?? '');
                    return g != null && g == 0 ? 'Must be more than 0.' : null;
                  },
                ),
              ],
              gap(),
              AuthFormField(
                fieldKey: const ValueKey('food.form.kcal'),
                label: 'Energy (kcal)',
                controller: _kcal,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                validator: _amount(required: true, max: 5000, unit: 'kcal'),
              ),
              gap(),
              AuthFormField(
                fieldKey: const ValueKey('food.form.protein'),
                label: 'Protein (g)',
                controller: _protein,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                validator: _amount(required: true, max: 500),
              ),
              gap(),
              AuthFormField(
                fieldKey: const ValueKey('food.form.carb'),
                label: 'Carbohydrate (g)',
                controller: _carb,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                validator: _amount(required: true, max: 500),
              ),
              gap(),
              AuthFormField(
                fieldKey: const ValueKey('food.form.fat'),
                label: 'Fat (g)',
                controller: _fat,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                validator: _amount(required: true, max: 500),
              ),
              gap(),
              AuthFormField(
                fieldKey: const ValueKey('food.form.fibre'),
                label: 'Fibre (g) — leave empty if the label does not say',
                controller: _fibre,
                keyboardType: decimal,
                textInputAction: TextInputAction.done,
                validator: _amount(required: false, max: 500),
              ),
              if (_error != null) ...<Widget>[
                gap(),
                AuthFeedback.error(_error!),
              ],
              const SizedBox(height: FitSpacing.lg),
              FilledButton(
                key: const ValueKey('food.form.save'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save food'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
