import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/demo/exercise_demos.dart';
import '../controllers/exercise_providers.dart';
import 'exercise_demo_view.dart';

/// Beta 5.0 (owner): "How" mid-workout — the demo and the cues in a sheet,
/// without leaving the session. Null when the lift has no demo.
Future<void> showExerciseDemoSheet(
  BuildContext context, {
  required String exerciseId,
  required String slug,
  required String name,
}) async {
  final match = demoFor(slug);
  if (match == null) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        key: const ValueKey('demo.sheet'),
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          0,
          FitSpacing.screen,
          FitSpacing.xl,
        ),
        children: [
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: FitSpacing.md),
          ExerciseDemoView(demo: match.demo, name: name, note: match.note),
          const SizedBox(height: FitSpacing.md),
          _Cues(exerciseId: exerciseId),
        ],
      ),
    ),
  );
}

/// The library's own cues, numbered as the demo's key moments.
class _Cues extends ConsumerWidget {
  const _Cues({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final detail = ref.watch(exerciseDetailProvider(exerciseId)).value;
    if (detail == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < detail.instructions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: FitSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}', style: t.titleMedium),
                ),
                Expanded(
                  child: Text(detail.instructions[i], style: t.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
