import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';

enum OrphanResolution { finish, discard }

/// When the server's session ends if the user chooses "Finish": at its last
/// logged set (so History shows the real duration and the ISO week it was
/// trained in), or its start when nothing was logged.
String orphanCompletedAt(WorkoutSession s) {
  var last = s.startedAt;
  for (final x in s.exercises) {
    for (final set in x.sets) {
      if (set.loggedAt.compareTo(last) > 0) last = set.loggedAt;
    }
  }
  return last;
}

int _setCount(WorkoutSession s) =>
    s.exercises.fold(0, (n, x) => n + x.sets.length);

/// Phase 6.6 Gate 7 — "Unfinished session on FITOS". The server holds an
/// active session this phone does not have (see [orphanedSessionProvider]);
/// until it ends, new sessions from this phone are refused. The user chooses
/// — sessions never end by themselves (owner 8.5): **Finish** records it as
/// completed (into History), **Discard** abandons it. Then the work queued
/// behind the server's one-active-session rule is sent again.
class OrphanSessionNotice extends ConsumerStatefulWidget {
  const OrphanSessionNotice({super.key});

  @override
  ConsumerState<OrphanSessionNotice> createState() =>
      _OrphanSessionNoticeState();
}

class _OrphanSessionNoticeState extends ConsumerState<OrphanSessionNotice> {
  bool _busy = false;
  Failure? _failure;

  Future<void> _resolve(WorkoutSession s, OrphanResolution how) async {
    final finish = how == OrphanResolution.finish;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('orphan.confirm'),
        title: Text(finish ? 'Finish this session?' : 'Discard this session?'),
        content: Text(
          finish
              ? '${s.name} goes into your History as completed, with the ${_setCount(s)} sets logged in it.'
              : '${s.name} is closed as abandoned. Its sets stay on FITOS but do not count as a completed session.',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey('orphan.confirm.cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const ValueKey('orphan.confirm.ok'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(finish ? 'Finish it' : 'Discard it'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final api = ref.read(workoutApiProvider);
    final result = finish
        ? await api.complete(
            s.id,
            CompleteSessionRequest(completedAt: orphanCompletedAt(s)),
          )
        : await api.abandon(s.id);
    if (!mounted) return;
    switch (result) {
      case Err<WorkoutSession>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
        // Maybe it already ended elsewhere: ask the server again.
        ref.invalidate(todayProvider);
      case Ok<WorkoutSession>():
        // The block is gone: send what this phone queued behind it (a new
        // session's start, its sets, its completion), then refresh.
        await ref.read(workoutRepositoryProvider).retryParked();
        if (!mounted) return;
        ref
          ..invalidate(todayProvider)
          ..invalidate(historyProvider)
          ..invalidate(volumeProvider);
        setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(orphanedSessionProvider).value;
    if (s == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final started = DateTime.tryParse(s.startedAt)?.toLocal();
    final when = started == null
        ? s.startedAt
        : '${started.year}-${_pad(started.month)}-${_pad(started.day)} '
            '${_pad(started.hour)}:${_pad(started.minute)}';
    final sets = _setCount(s);
    return DecoratedBox(
      key: const ValueKey('orphan.notice'),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: FitColors.oxide),
          bottom: BorderSide(color: FitColors.rule),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'UNFINISHED SESSION ON FITOS',
              style: textTheme.labelSmall?.copyWith(color: FitColors.oxide),
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              '${s.name} · started $when · $sets ${sets == 1 ? 'set' : 'sets'}',
              key: const ValueKey('orphan.summary'),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'This phone no longer has it, and FITOS allows one session in progress at a time — new sessions from this phone cannot reach FITOS until you finish or discard it.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            if (_failure != null) ...<Widget>[
              const SizedBox(height: FitSpacing.xs),
              Text(
                _failure!.message,
                key: const ValueKey('orphan.error'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
              ),
            ],
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: FitSpacing.sm,
              children: <Widget>[
                if (sets > 0)
                  OutlinedButton(
                    key: const ValueKey('orphan.finish'),
                    onPressed: _busy
                        ? null
                        : () => _resolve(s, OrphanResolution.finish),
                    child: const Text('Finish it'),
                  ),
                TextButton(
                  key: const ValueKey('orphan.discard'),
                  onPressed: _busy
                      ? null
                      : () => _resolve(s, OrphanResolution.discard),
                  child: const Text('Discard it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
