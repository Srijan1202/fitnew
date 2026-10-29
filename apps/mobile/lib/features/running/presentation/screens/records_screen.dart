import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../controllers/running_providers.dart';
import '../widgets/efforts_widgets.dart';

/// Beta 4.2 (owner 2026-10-29): Running → Records — the record at each
/// distance, from every saved run; the last copy when offline.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(recordsProvider);
    final records = async.value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Running records'),
      ),
      body: FitBackdrop(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recordsProvider);
            await ref.read(recordsProvider.future);
          },
          child: ListView(
            key: const ValueKey('records.list'),
            padding: const EdgeInsets.all(FitSpacing.screen),
            children: [
              if (records != null)
                RecordsCard(records: records)
              else if (async.isLoading)
                const Padding(
                  padding: EdgeInsets.all(FitSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Text(
                  'Your records show here once FITOS can reach the server.',
                  key: const ValueKey('records.unavailable'),
                  style: t.bodyLarge,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
