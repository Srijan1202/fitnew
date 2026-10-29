import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../premium/presentation/rewards_providers.dart';
import '../../domain/coach.dart';
import '../../domain/efforts.dart';
import '../../domain/run.dart';
import '../controllers/run_recorder.dart';
import '../controllers/running_providers.dart';
import '../widgets/efforts_widgets.dart';
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

  /// Beta 4.2: said once per run, so a rebuild does not repeat it.
  String? _spokenFor;

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

  /// Beta 4.2 (owner: straight away, offline too): the records this run
  /// beats and the badges it earns, worked out on the phone (the server's
  /// figures stand once it has the run). Records are only known against the
  /// last records this phone saw, badges against the last list of earned
  /// ones; without either, nothing is claimed. Spoken once if the voice
  /// coach is on.
  List<Widget> _achievements(String runId, RunDetail d) {
    final t = Theme.of(context).textTheme;
    final records = ref.watch(recordsProvider).value;
    final earned = ref.watch(earnedBadgesProvider).value;
    final track = d.track;
    final beaten = records == null || track == null
        ? const <BestEffort>[]
        : newRecords(bestEfforts(track), records.recordTimes);
    final badges = earned == null || track == null
        ? const <DistanceBadge>[]
        : [
            for (final b in badgesFor(d.summary.distanceM))
              if (!earned.containsKey(b)) b,
          ];
    if (beaten.isEmpty && badges.isEmpty) return const [];
    if (_spokenFor != runId && ref.read(runSettingsProvider).voice) {
      _spokenFor = runId;
      final words = [
        for (final e in beaten)
          'New record. ${e.key.label.replaceAll(' km', ' kilometres').replaceAll(' m', ' metres')} in ${spokenDuration(e.seconds.round())}.',
        for (final b in badges) 'Badge earned: ${b.label}.',
      ];
      unawaited(ref.read(runVoiceProvider).say(words.join(' ')));
    }
    return [
      FitBlock(
        key: const ValueKey('run.achievements'),
        glow: true,
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in beaten)
              Padding(
                padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                child: Row(
                  children: [
                    const EffortMedal(rank: 1),
                    const SizedBox(width: FitSpacing.sm),
                    Expanded(
                      child: Text(
                        'New record: ${e.key.label} in ${effortTime(e.seconds)}',
                        key: ValueKey('run.newRecord.${e.key.wire}'),
                        style: t.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            for (final b in badges)
              Padding(
                padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.military_tech, color: FitColors.accent),
                    const SizedBox(width: FitSpacing.sm),
                    Expanded(
                      child: Text(
                        b.unlocks == null
                            ? 'Badge earned: ${b.label}'
                            : 'Badge earned: ${b.label}. You unlocked ${b.unlocks}.',
                        key: ValueKey('run.newBadge.${b.id}'),
                        style: t.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Saved with the run.',
              style: t.bodySmall?.copyWith(color: FitColors.ink60),
            ),
          ],
        ),
      ),
      const SizedBox(height: FitSpacing.md),
    ];
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
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._achievements(run.id, d),
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                  child: TextField(
                    key: const ValueKey('run.name'),
                    controller: _name,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
              ],
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
