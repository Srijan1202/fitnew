import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/run.dart';
import '../controllers/running_providers.dart';
import '../widgets/run_report.dart';

/// Beta 4.0 (ADR-038): one run from the history — the server's record (or
/// the phone's preview until it has it). Share, edit or delete it.
class RunDetailScreen extends ConsumerWidget {
  const RunDetailScreen({required this.id, super.key});

  final String id;

  Future<void> _edit(BuildContext context, WidgetRef ref, RunDetail run) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(run: run),
    );
    if (changed ?? false) ref.invalidate(runDetailProvider(id));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('run.delete.confirm'),
        title: const Text('Delete this run?'),
        content: const Text(
          'The run, its route and its splits are deleted from FITOS. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const ValueKey('run.delete.yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: FitColors.oxide)),
          ),
        ],
      ),
    );
    if (!(yes ?? false)) return;
    await ref.read(runningRepositoryProvider).delete(id);
    ref.invalidate(runListProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(runDetailProvider(id));
    final unit = ref.watch(runSettingsProvider).unit;
    final t = Theme.of(context).textTheme;
    final run = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(run?.summary.name ?? 'Run'),
        actions: [
          if (run != null) ...[
            if (run.track != null)
              IconButton(
                key: const ValueKey('run.share'),
                tooltip: 'Share or export',
                icon: const Icon(Icons.ios_share),
                onPressed: () => context.push(Routes.runShare(id)),
              ),
            PopupMenuButton<String>(
              key: const ValueKey('run.menu'),
              onSelected: (v) => switch (v) {
                'edit' => _edit(context, ref, run),
                'delete' => _delete(context, ref),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  key: ValueKey('run.edit'),
                  value: 'edit',
                  child: Text('Edit name, note and effort'),
                ),
                PopupMenuItem(
                  key: ValueKey('run.delete'),
                  value: 'delete',
                  child: Text('Delete run'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: FitBackdrop(
        child: switch (async) {
          AsyncData(value: final d?) => RunReport(
              run: d,
              unit: unit,
              // Beta 4.4: a route to replay.
              onReplay: d.track == null
                  ? null
                  : () => context.push(Routes.runReplay(d.id)),
            ),
          AsyncData() => Center(
              child: Padding(
                padding: const EdgeInsets.all(FitSpacing.lg),
                child: Text(
                  'This run is not on this phone and FITOS cannot reach the '
                  'server. Try again when you are online.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge,
                ),
              ),
            ),
          AsyncError() => Center(
              child: Text('Could not open this run.', style: t.bodyLarge),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.run});

  final RunDetail run;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.run.summary.name);
  late final _note = TextEditingController(text: widget.run.note ?? '');
  late int? _effort = widget.run.summary.effort;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final note = _note.text.trim();
    final before = widget.run;
    await ref.read(runningRepositoryProvider).edit(
          before.id,
          name: name.isNotEmpty && name != before.summary.name ? name : null,
          note: note != (before.note ?? '') ? note : null,
          effort: _effort != null && _effort != before.summary.effort
              ? _effort
              : null,
          clearEffort: _effort == null && before.summary.effort != null,
        );
    ref.invalidate(runListProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit run', style: t.titleLarge),
          const SizedBox(height: FitSpacing.md),
          TextField(
            key: const ValueKey('run.edit.name'),
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            key: const ValueKey('run.edit.note'),
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: FitSpacing.sm),
          Text('HOW HARD WAS IT?', style: t.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var e = 1; e <= 10; e++)
                ChoiceChip(
                  key: ValueKey('run.edit.effort.$e'),
                  label: Text('$e'),
                  selected: _effort == e,
                  onSelected: (on) => setState(() => _effort = on ? e : null),
                ),
            ],
          ),
          const SizedBox(height: FitSpacing.lg),
          FilledButton(
            key: const ValueKey('run.edit.save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
