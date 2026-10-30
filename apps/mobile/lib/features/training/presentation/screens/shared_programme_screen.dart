import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../data/shared_programme_api.dart';
import '../controllers/program_controller.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Beta 3.3 (ADR-034): Training → Use a shared programme. Type or paste the
/// code (or the link), see the programme, then use it: a copy replaces your
/// current programme; your history, records and weights stay.
class SharedProgrammeScreen extends ConsumerStatefulWidget {
  const SharedProgrammeScreen({super.key});

  @override
  ConsumerState<SharedProgrammeScreen> createState() =>
      _SharedProgrammeScreenState();
}

class _SharedProgrammeScreenState extends ConsumerState<SharedProgrammeScreen> {
  final _code = TextEditingController();
  SharedProgramme? _preview;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _look() async {
    final code = parseShareCode(_code.text);
    if (code == null) {
      setState(
        () => _error = 'That is not a FITOS code. It looks like FIT-K7Q2XM.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(sharedProgrammeApiProvider).preview(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      r.when(
        ok: (p) => _preview = p,
        err: (f) => _error = f is NotFound
            ? 'No programme is shared with that code. It may have been stopped.'
            : f.message,
      );
    });
  }

  Future<void> _use(SharedProgramme p) async {
    final hasProgramme = ref.read(programControllerProvider).value != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('shared.confirm'),
        backgroundColor: FitColors.paper,
        title: Text('Use “${p.name}”?'),
        content: Text(
          hasProgramme
              ? 'It replaces your current programme, which is kept, not deleted. Your history, records and weights stay yours.'
              : 'It becomes your programme. You can edit any day of it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('shared.confirm.use'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Use it'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final failure =
        await ref.read(programControllerProvider.notifier).useShared(p.code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      setState(() => _error = failure.message);
      return;
    }
    context.go(Routes.plan);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Use a shared programme'),
      ),
      body: FitBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FitSpacing.screen),
            children: <Widget>[
              Text(
                'Enter the code a friend shared with you, or paste their link.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.md),
              TextField(
                key: const ValueKey('shared.code'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'FIT-K7Q2XM'),
                onSubmitted: (_) => _look(),
              ),
              const SizedBox(height: FitSpacing.sm),
              FilledButton(
                key: const ValueKey('shared.look'),
                onPressed: _busy ? null : _look,
                child: const Text('Show the programme'),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                Text(
                  _error!,
                  key: const ValueKey('shared.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ],
              if (p != null) ...<Widget>[
                const SizedBox(height: FitSpacing.lg),
                Text(
                  p.name,
                  key: const ValueKey('shared.name'),
                  style: textTheme.headlineSmall,
                ),
                Text(
                  '${p.daysPerWeek} training days a week · sets and reps only, no weights',
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
                const SizedBox(height: FitSpacing.md),
                for (final d in p.days.where((d) => !d.isRest))
                  _SharedDayBlock(day: d),
                const SizedBox(height: FitSpacing.md),
                FilledButton(
                  key: const ValueKey('shared.use'),
                  onPressed: _busy ? null : () => _use(p),
                  child: const Text('Use this programme'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedDayBlock extends StatelessWidget {
  const _SharedDayBlock({required this.day});

  final SharedDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: FitBlock(
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_weekdays[day.dayOfWeek - 1]} · ${day.sessionName}',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: FitSpacing.xs),
            for (final x in day.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(x.name, style: textTheme.bodyLarge),
                          if (x.missingEquipment.isNotEmpty)
                            Text(
                              'Needs ${x.missingEquipment.map((q) => q.replaceAll('-', ' ')).join(', ')}',
                              key: const ValueKey('shared.needs'),
                              style: textTheme.bodySmall
                                  ?.copyWith(color: FitColors.amber),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      x.prescription,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Training → ⋯ → Share programme: makes a code and offers it.
Future<void> shareProgramme(BuildContext context, WidgetRef ref) async {
  final r = await ref.read(sharedProgrammeApiProvider).share();
  if (!context.mounted) return;
  final share = r.when<MyShare?>(ok: (s) => s, err: (_) => null);
  if (share == null) {
    r.when(
      ok: (_) {},
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
    return;
  }
  await showModalBottomSheet<void>(
    // Above the floating tab bar (beta 4.8, owner: Save hid behind it).
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: FitColors.paper,
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('share.sheet'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Share “${share.name}”', style: textTheme.titleLarge),
              const SizedBox(height: FitSpacing.sm),
              SelectableText(
                displayShareCode(share.code),
                key: const ValueKey('share.code'),
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Friends enter it in Training → Use a shared programme, or open ${share.url}. '
                'They get the days, exercises, sets and reps, never your weights or your name. '
                'Later changes to your programme are not in this code.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.md),
              FilledButton.icon(
                key: const ValueKey('share.send'),
                icon: const Icon(Icons.ios_share),
                onPressed: () =>
                    ref.read(textSharerProvider).share(share.message),
                label: const Text('Share'),
              ),
              TextButton(
                key: const ValueKey('share.copy'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: displayShareCode(share.code)),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Copy the code'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
