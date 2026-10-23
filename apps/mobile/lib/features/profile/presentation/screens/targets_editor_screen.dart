import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../widgets/targets_display.dart';

/// The targets editor and its first load, refetched on every open.
final targetsViewProvider =
    FutureProvider.autoDispose<TargetsView>((ref) async {
  final r = await ref.read(profileRepositoryProvider).getTargets();
  return r.when(ok: (v) => v, err: (f) => throw f);
});

/// Beta 3.2 (ADR-031): set your own calories and protein. FITOS splits the
/// rest the way it always does; its own suggestion stays beside the fields
/// and one tap away. The limits are the server's; the carbs and fat shown
/// before saving are a preview of the same split, confirmed by the save.
class TargetsEditorScreen extends ConsumerStatefulWidget {
  const TargetsEditorScreen({super.key});

  @override
  ConsumerState<TargetsEditorScreen> createState() =>
      _TargetsEditorScreenState();
}

class _TargetsEditorScreenState extends ConsumerState<TargetsEditorScreen> {
  int? _kcal;
  int? _protein;
  bool _busy = false;
  Failure? _failure;
  CustomTargetsResponse? _saved;
  bool _reset = false;

  /// The split FITOS uses (core `adjustTargets`), for the preview only.
  static ({int fat, int carbs}) _split(int kcal, int protein, double kg) {
    final fat =
        (kg * 0.8 > kcal * 0.22 / 9 ? kg * 0.8 : kcal * 0.22 / 9).round();
    final carbs = ((kcal - protein * 4 - fat * 9) / 4).round();
    return (fat: fat, carbs: carbs < 0 ? 0 : carbs);
  }

  Future<void> _save() async {
    final kcal = _kcal;
    final protein = _protein;
    if (kcal == null || protein == null) return;
    setState(() {
      _busy = true;
      _failure = null;
      _saved = null;
      _reset = false;
    });
    final r = await ref
        .read(profileRepositoryProvider)
        .setCustomTargets(kcal: kcal, proteinG: protein);
    if (!mounted) return;
    setState(() {
      _busy = false;
      r.when(
        ok: (v) {
          _saved = v;
          ref.read(profileControllerProvider.notifier).showTargets(v.targets);
        },
        err: (f) => _failure = f,
      );
    });
    if (_saved != null) ref.invalidate(targetsViewProvider);
  }

  Future<void> _useFitos() async {
    setState(() {
      _busy = true;
      _failure = null;
      _saved = null;
    });
    final r = await ref.read(profileRepositoryProvider).resetTargets();
    if (!mounted) return;
    setState(() {
      _busy = false;
      r.when(
        ok: (v) {
          _reset = true;
          _kcal = v.current?.kcal;
          _protein = v.current?.proteinG;
          ref.read(profileControllerProvider.notifier).showTargets(v.current);
        },
        err: (f) => _failure = f,
      );
    });
    if (_reset) ref.invalidate(targetsViewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(targetsViewProvider);
    final weight =
        ref.watch(profileControllerProvider).value?.profile.latestWeightKg;

    return Scaffold(
      appBar: AppBar(
        leading:
            BackButton(onPressed: _busy ? null : () => context.popOrHome()),
      ),
      body: FitBackdrop(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(FitSpacing.screen),
              child: AuthFeedback.error(
                e is Failure ? e.message : 'Could not load your targets.',
              ),
            ),
            data: (view) {
              final current = view.current;
              final s = view.suggestion;
              final limits = view.limits;
              _kcal ??= current?.kcal ?? s?.kcal;
              _protein ??= current?.proteinG ?? s?.proteinG;
              final kcal = _kcal ?? limits.kcalMin;
              final protein = _protein ?? limits.proteinMinG;
              final split =
                  weight == null ? null : _split(kcal, protein, weight);
              final fits = split == null || protein * 4 + split.fat * 9 <= kcal;
              final unchanged = current != null &&
                  current.isCustom &&
                  kcal == current.kcal &&
                  protein == current.proteinG;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.sm,
                  FitSpacing.screen,
                  FitSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('TARGETS', style: textTheme.labelSmall),
                    const SizedBox(height: FitSpacing.xs),
                    Text('Set your own', style: textTheme.displaySmall),
                    const SizedBox(height: FitSpacing.sm),
                    Text(
                      'Choose your daily calories and protein. FITOS splits the rest into carbs and fat. '
                      'Your target stays through weight changes; changing your goal goes back to FITOS’s suggestion.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: FitSpacing.lg),
                    FitBlock(
                      padding: const EdgeInsets.all(FitSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _NumberStepper(
                            keyPrefix: 'targets.kcal',
                            label: 'Calories',
                            unit: 'kcal / day',
                            value: kcal,
                            step: 50,
                            min: limits.kcalMin,
                            max: limits.kcalMax,
                            enabled: !_busy,
                            onChanged: (v) => setState(() => _kcal = v),
                          ),
                          const SizedBox(height: FitSpacing.md),
                          _NumberStepper(
                            keyPrefix: 'targets.protein',
                            label: 'Protein',
                            unit: 'g / day',
                            value: protein,
                            step: 5,
                            min: limits.proteinMinG,
                            max: limits.proteinMaxG,
                            enabled: !_busy,
                            onChanged: (v) => setState(() => _protein = v),
                          ),
                          if (split != null) ...<Widget>[
                            const SizedBox(height: FitSpacing.md),
                            Text(
                              fits
                                  ? '≈ ${split.carbs} g carbs · ${split.fat} g fat'
                                  : 'That much protein and the minimum fat don’t fit in $kcal kcal: raise the calories or lower the protein.',
                              key: const ValueKey('targets.split'),
                              style: textTheme.bodyMedium?.copyWith(
                                color: fits ? FitColors.ink60 : FitColors.oxide,
                              ),
                            ),
                          ],
                          const SizedBox(height: FitSpacing.xs),
                          Text(
                            'Limits: ${limits.kcalMin}–${limits.kcalMax} kcal · protein ${limits.proteinMinG}–${limits.proteinMaxG} g at your weight.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: FitColors.ink35),
                          ),
                        ],
                      ),
                    ),
                    if (s != null) ...<Widget>[
                      const SizedBox(height: FitSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'FITOS suggests ${s.kcal} kcal · ${s.proteinG} g protein',
                              key: const ValueKey('targets.suggestion'),
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('targets.useSuggestionValues'),
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _kcal = s.kcal;
                                      _protein = s.proteinG;
                                    }),
                            child: const Text('Use these'),
                          ),
                        ],
                      ),
                    ],
                    if (_failure != null) ...<Widget>[
                      const SizedBox(height: FitSpacing.md),
                      AuthFeedback.error(_failure!.message),
                    ],
                    const SizedBox(height: FitSpacing.lg),
                    FilledButton(
                      key: const ValueKey('targets.save'),
                      onPressed: _busy || !fits || unchanged ? null : _save,
                      child: const Text('Save my targets'),
                    ),
                    if (current != null &&
                        current.isCustom &&
                        !_reset) ...<Widget>[
                      const SizedBox(height: FitSpacing.sm),
                      OutlinedButton(
                        key: const ValueKey('targets.reset'),
                        onPressed: _busy ? null : _useFitos,
                        child: const Text('Use FITOS’s suggestion'),
                      ),
                    ],
                    if (_reset) ...<Widget>[
                      const SizedBox(height: FitSpacing.md),
                      Text(
                        'Back on FITOS’s suggestion.',
                        key: const ValueKey('targets.resetDone'),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FitColors.pine),
                      ),
                    ],
                    if (_saved != null) ...<Widget>[
                      const SizedBox(height: FitSpacing.xl),
                      FitBlock(
                        glow: true,
                        padding: const EdgeInsets.all(FitSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('YOUR TARGETS', style: textTheme.labelSmall),
                            const SizedBox(height: FitSpacing.sm),
                            TargetsDisplay(targets: _saved!.targets),
                            for (final w in _saved!.warnings) ...<Widget>[
                              const SizedBox(height: FitSpacing.sm),
                              Text(
                                w,
                                key: ValueKey(
                                    'targets.warning.${_saved!.warnings.indexOf(w)}',),
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: FitColors.amber),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A labelled − value + with tap-to-type, clamped to [min, max].
class _NumberStepper extends StatefulWidget {
  const _NumberStepper({
    required this.keyPrefix,
    required this.label,
    required this.unit,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final String unit;
  final int value;
  final int step;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<_NumberStepper> {
  bool _typing = false;
  late final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int _clamp(int v) =>
      v < widget.min ? widget.min : (v > widget.max ? widget.max : v);

  void _commit() {
    final v = int.tryParse(_text.text.trim());
    setState(() => _typing = false);
    if (v != null) widget.onChanged(_clamp(v));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final k = widget.keyPrefix;
    Widget tap(String suffix, IconData icon, int delta) => IconButton(
          key: ValueKey('$k.$suffix'),
          onPressed: widget.enabled
              ? () => widget.onChanged(_clamp(widget.value + delta))
              : null,
          icon: Icon(icon),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        );
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.label, style: textTheme.titleMedium),
              Text(widget.unit,
                  style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),),
            ],
          ),
        ),
        tap('minus', Icons.remove, -widget.step),
        SizedBox(
          width: 84,
          child: _typing
              ? TextField(
                  key: ValueKey('$k.field'),
                  controller: _text,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                  onSubmitted: (_) => _commit(),
                  onTapOutside: (_) => _commit(),
                )
              : InkWell(
                  key: ValueKey('$k.value'),
                  onTap: widget.enabled
                      ? () => setState(() {
                            _typing = true;
                            _text.text = '${widget.value}';
                          })
                      : null,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: FitSpacing.sm),
                    child: Text(
                      '${widget.value}',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge,
                    ),
                  ),
                ),
        ),
        tap('plus', Icons.add, widget.step),
      ],
    );
  }
}
