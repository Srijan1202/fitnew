import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../profile/data/profile_repository.dart';
import '../../domain/run.dart';
import '../controllers/run_recorder.dart';
import '../controllers/running_providers.dart';
import '../widgets/run_report.dart';

/// Beta 4.0 (ADR-038): the run just finished — its summary from the phone's
/// own figures (the server's replace them once it has the run), a name, a
/// note, how hard it felt; then Save or Discard. Going back keeps it
/// waiting: Running shows "Save or discard" until one is chosen.
class RunFinishScreen extends ConsumerStatefulWidget {
  const RunFinishScreen({super.key});

  @override
  ConsumerState<RunFinishScreen> createState() => _RunFinishScreenState();
}

class _RunFinishScreenState extends ConsumerState<RunFinishScreen> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _distance = TextEditingController();
  int? _effort;
  bool _saving = false;
  String? _distanceError;
  Future<RunDetail?>? _preview;
  String? _previewFor;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _distance.dispose();
    super.dispose();
  }

  Future<RunDetail?> _load(String id) async {
    final weight =
        ref.read(profileControllerProvider).value?.profile.latestWeightKg;
    final d =
        await ref.read(runningRepositoryProvider).local(id, weightKg: weight);
    if (d != null && _name.text.isEmpty) _name.text = d.summary.name;
    return d;
  }

  Future<void> _save(LiveRun run) async {
    final unit = ref.read(runSettingsProvider).unit;
    double? treadmill;
    if (run.kind == RunKind.treadmill) {
      final v = double.tryParse(_distance.text.trim().replaceAll(',', '.'));
      if (v == null || v <= 0 || v * unit.metres > 200000) {
        setState(
          () => _distanceError = 'Type the distance the treadmill shows',
        );
        return;
      }
      treadmill = v * unit.metres;
    }
    setState(() => _saving = true);
    final name = _name.text.trim().isEmpty
        ? defaultRunName(run.startedAt.toLocal(), run.kind)
        : _name.text.trim();
    final id = await ref.read(runRecorderProvider.notifier).save(
          name: name.length > 60 ? name.substring(0, 60) : name,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          effort: _effort,
          treadmillDistanceM: treadmill,
        );
    if (!mounted) return;
    if (id == null) {
      setState(() => _saving = false);
      return;
    }
    context.pushReplacement(Routes.runDetail(id));
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('run.discard.confirm'),
        title: const Text('Discard this run?'),
        content: const Text('It will not be saved anywhere.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const ValueKey('run.discard.yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Discard', style: TextStyle(color: FitColors.oxide)),
          ),
        ],
      ),
    );
    if (!(yes ?? false) || !mounted) return;
    await ref.read(runRecorderProvider.notifier).discard();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runRecorderProvider);
    final unit = ref.watch(runSettingsProvider).unit;
    final t = Theme.of(context).textTheme;
    if (run == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('No run to save.', style: t.bodyLarge)),
      );
    }
    if (_previewFor != run.id) {
      _previewFor = run.id;
      _preview = _load(run.id);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Run summary')),
      body: FutureBuilder<RunDetail?>(
        future: _preview,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return RunReport(
            run: d,
            unit: unit,
            header: Padding(
              padding: const EdgeInsets.only(bottom: FitSpacing.sm),
              child: TextField(
                key: const ValueKey('run.name'),
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            footer: [
              if (run.kind == RunKind.treadmill) ...[
                const SizedBox(height: FitSpacing.lg),
                TextField(
                  key: const ValueKey('run.treadmillDistance'),
                  controller: _distance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Distance (${unit.label})',
                    helperText: 'From the treadmill’s screen',
                    errorText: _distanceError,
                  ),
                ),
              ],
              const SizedBox(height: FitSpacing.lg),
              Text('HOW HARD WAS IT?', style: t.labelSmall),
              const SizedBox(height: FitSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var e = 1; e <= 10; e++)
                    ChoiceChip(
                      key: ValueKey('run.effort.$e'),
                      label: Text('$e'),
                      selected: _effort == e,
                      onSelected: (on) =>
                          setState(() => _effort = on ? e : null),
                    ),
                ],
              ),
              if (_effort != null)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.xs),
                  child: Text(effortWord(_effort!), style: t.bodyMedium),
                ),
              const SizedBox(height: FitSpacing.md),
              TextField(
                key: const ValueKey('run.note'),
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: FitSpacing.lg),
              FilledButton(
                key: const ValueKey('run.save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _saving ? null : () => _save(run),
                child: const Text('Save run'),
              ),
              const SizedBox(height: FitSpacing.sm),
              TextButton(
                key: const ValueKey('run.discard'),
                onPressed: _saving ? null : _discard,
                child: Text(
                  'Discard',
                  style: TextStyle(color: FitColors.oxide),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
