import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../../premium/presentation/premium_providers.dart';
import '../../../premium/presentation/premium_sheet.dart';
import '../../../privacy/presentation/privacy_providers.dart';
import '../../data/ai_programme_api.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';

final aiProgrammeApiProvider = Provider<AiProgrammeApi>(
  (ref) => DioAiProgrammeApi(ref.watch(dioProvider)),
);

/// The weekdays a week of [n] sessions takes (core `trainingDays`).
List<int> weekdaysFor(int n) => switch (n) {
      2 => [1, 4],
      3 => [1, 3, 5],
      4 => [1, 2, 4, 5],
      5 => [1, 2, 3, 5, 6],
      _ => [1, 2, 3, 4, 5, 6],
    };

/// The custom programme a draft becomes: its sessions on the usual
/// weekdays, no weights (the first session's sets fill them, as always).
PutProgramRequest requestFromDraft(AiProgrammeDraft d) {
  final days = weekdaysFor(d.days.length);
  return PutProgramRequest(
    name: d.name,
    days: [
      for (var i = 0; i < d.days.length; i++)
        CustomDay(
          dayOfWeek: days[i],
          sessionName: d.days[i].name,
          exercises: [
            for (final x in d.days[i].exercises)
              CustomExercise(
                exerciseId: x.exerciseId,
                setCount: x.setCount,
                repMin: x.repMin,
                repMax: x.repMax,
                targetRir: x.targetRir,
              ),
          ],
        ),
    ],
  );
}

/// Beta 6.1 (premium): Build with FITOS AI. A few answers, FITOS AI builds a
/// week from the exercises this person can do, FITOS checks it, and it is
/// used only on "Use this programme".
class AiProgrammeScreen extends ConsumerStatefulWidget {
  const AiProgrammeScreen({super.key});

  @override
  ConsumerState<AiProgrammeScreen> createState() => _AiProgrammeScreenState();
}

class _AiProgrammeScreenState extends ConsumerState<AiProgrammeScreen> {
  int _sessions = 3;
  int _minutes = 60;
  final Set<MuscleGroup> _focus = {};
  final List<ExerciseSummary> _avoid = [];
  final _note = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  String? _error;
  AiProgrammeDraft? _draft;

  @override
  void dispose() {
    _note.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    if (!await ensureAiConsent(context, ref) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(aiProgrammeApiProvider).draft(
          sessions: _sessions,
          minutes: _minutes,
          focus: [for (final m in _focus) m.wire],
          avoid: [for (final x in _avoid) x.id],
          note: _note.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Ok(:final value):
          _draft = value;
          // The draft starts at the top of the page.
          if (_scroll.hasClients) _scroll.jumpTo(0);
        case Err(:final failure):
          _error = failure is Forbidden && failure.issue == 'premium-required'
              ? null
              : failure.message;
          if (failure is Forbidden && failure.issue == 'premium-required') {
            showPremiumSheet(context, feature: 'Build with FITOS AI');
          }
      }
    });
  }

  Future<void> _use() async {
    final d = _draft!;
    setState(() => _busy = true);
    final failure = await ref
        .read(programControllerProvider.notifier)
        .putCustom(requestFromDraft(d));
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      setState(() => _error = failure.message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${d.name} is your programme now.')),
    );
    context.go(Routes.plan);
  }

  Future<void> _pickAvoid() async {
    final picked = await context.push<ExerciseSummary>(Routes.exercisePicker);
    if (picked == null || !mounted) return;
    if (_avoid.any((x) => x.id == picked.id) || _avoid.length >= 30) return;
    setState(() => _avoid.add(picked));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = ref.watch(isPremiumProvider) == false;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('BUILD WITH FITOS AI', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              if (locked)
                const PremiumPitch(
                  key: ValueKey('aiprog.premium'),
                  feature: 'Build with FITOS AI',
                )
              else if (_draft != null)
                ..._preview(context, _draft!)
              else
                ..._form(context),
              if (_error != null) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                Text(
                  _error!,
                  key: const ValueKey('aiprog.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    return <Widget>[
      Text('A week built for you', style: textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(
        'From your goal, your level and the exercises your equipment allows. FITOS checks the plan before you see it.',
        style: muted,
      ),
      const SizedBox(height: FitSpacing.md),
      Text('SESSIONS A WEEK', style: textTheme.labelSmall),
      Wrap(
        spacing: FitSpacing.xs,
        children: <Widget>[
          for (var n = 2; n <= 6; n++)
            ChoiceChip(
              key: ValueKey('aiprog.sessions.$n'),
              label: Text('$n'),
              selected: _sessions == n,
              onSelected: (_) => setState(() => _sessions = n),
            ),
        ],
      ),
      const SizedBox(height: FitSpacing.sm),
      Text('MINUTES A SESSION', style: textTheme.labelSmall),
      Wrap(
        spacing: FitSpacing.xs,
        children: <Widget>[
          for (final m in const [45, 60, 75, 90])
            ChoiceChip(
              key: ValueKey('aiprog.minutes.$m'),
              label: Text('$m'),
              selected: _minutes == m,
              onSelected: (_) => setState(() => _minutes = m),
            ),
        ],
      ),
      const SizedBox(height: FitSpacing.sm),
      Text('BRING UP (UP TO 3, OPTIONAL)', style: textTheme.labelSmall),
      Wrap(
        spacing: FitSpacing.xs,
        runSpacing: FitSpacing.xs,
        children: <Widget>[
          for (final m in MuscleGroup.values)
            FilterChip(
              key: ValueKey('aiprog.focus.${m.wire}'),
              label: Text(m.label),
              selected: _focus.contains(m),
              onSelected: (on) => setState(() {
                if (!on) {
                  _focus.remove(m);
                } else if (_focus.length < 3) {
                  _focus.add(m);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: FitSpacing.sm),
      Text('LEAVE OUT', style: textTheme.labelSmall),
      Wrap(
        spacing: FitSpacing.xs,
        runSpacing: FitSpacing.xs,
        children: <Widget>[
          for (final x in _avoid)
            InputChip(
              label: Text(x.name),
              onDeleted: () => setState(() => _avoid.remove(x)),
            ),
          ActionChip(
            key: const ValueKey('aiprog.avoid.add'),
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('An exercise'),
            onPressed: _pickAvoid,
          ),
        ],
      ),
      const SizedBox(height: FitSpacing.sm),
      TextField(
        key: const ValueKey('aiprog.note'),
        controller: _note,
        maxLength: 200,
        decoration:
            const InputDecoration(labelText: 'Anything else? (optional)'),
      ),
      Text(
        "This line goes to Google's Gemini as you write it. Leave out anything you would not want sent.",
        key: const ValueKey('aiprog.noteWarning'),
        style: muted,
      ),
      const SizedBox(height: FitSpacing.md),
      FilledButton.icon(
        key: const ValueKey('aiprog.build'),
        onPressed: _busy ? null : _build,
        icon: const Icon(Icons.auto_awesome),
        label: Text(_busy ? 'Building your week…' : 'Build my week'),
      ),
    ];
  }

  List<Widget> _preview(BuildContext context, AiProgrammeDraft d) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final days = weekdaysFor(d.days.length);
    return <Widget>[
      Text(
        d.name,
        key: const ValueKey('aiprog.name'),
        style: textTheme.headlineSmall,
      ),
      if (d.why.isNotEmpty) ...<Widget>[
        const SizedBox(height: 4),
        Text(d.why, style: textTheme.bodyMedium),
      ],
      if (d.adjustments.isNotEmpty) ...<Widget>[
        const SizedBox(height: FitSpacing.sm),
        Text('FITOS CHANGED', style: textTheme.labelSmall),
        for (final a in d.adjustments) Text(a, style: muted),
      ],
      const SizedBox(height: FitSpacing.md),
      for (var i = 0; i < d.days.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: FitSpacing.sm),
          child: FitBlock(
            key: ValueKey('aiprog.day.$i'),
            padding: const EdgeInsets.all(FitSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${programDayLabel(days[i], cycle: false)} · ${d.days[i].name}',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: FitSpacing.xs),
                for (final x in d.days[i].exercises)
                  Text(
                    '${x.name} · ${x.setCount} × ${x.repMin}–${x.repMax}',
                    style: textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      Text(
        'Weights come from your first sessions. Your current programme is kept, not deleted.',
        style: muted,
      ),
      const SizedBox(height: FitSpacing.md),
      FilledButton(
        key: const ValueKey('aiprog.use'),
        onPressed: _busy ? null : _use,
        child: const Text('Use this programme'),
      ),
      TextButton(
        key: const ValueKey('aiprog.again'),
        onPressed: _busy ? null : () => setState(() => _draft = null),
        child: const Text('Ask again'),
      ),
    ];
  }
}
