import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../mess/domain/mess.dart';
import '../../../mess/presentation/mess_providers.dart';
import '../../../mess/presentation/widgets/mess_sheets.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';

/// Phase 9 (owner D13): change the mess after onboarding. Picks from the
/// server's list; the server refuses any other. "I do not eat at a VIT mess"
/// clears it. Afterwards "my mess" is re-learnt and the menus refetched.
Future<void> changeMess(
  BuildContext context,
  WidgetRef ref, {
  String? currentCode,
}) async {
  final choice = await showMessPicker(
    context,
    currentCode: currentCode,
    allowNone: true,
  );
  if (choice == null || !context.mounted) return;
  final m = choice.mess;
  final failure = await ref.read(profileControllerProvider.notifier).setMess(
        m == null
            ? null
            : MessRef(
                providerId: m.providerSlug,
                hostelId: m.hostelId,
                messId: m.messId,
              ),
      );
  await ref.read(messRepositoryProvider).forgetMine();
  ref
    ..invalidate(messMenuProvider)
    ..invalidate(messBrowseProvider);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? (m == null ? 'Mess cleared.' : 'Your mess is now ${m.label}.')
            : failure is Offline
                ? 'Changing the mess needs a connection.'
                : failure.message,
      ),
    ),
  );
}

/// Profile: "Mess — Men's Hostel · Vegetarian   Change".
class MessSettingRow extends ConsumerWidget {
  const MessSettingRow({required this.mess, super.key});

  final MessRef? mess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final m = mess;
    final list = ref.watch(messesProvider).value;
    final known = m == null
        ? null
        : list
            ?.where((x) => x.hostelId == m.hostelId && x.messId == m.messId)
            .firstOrNull;
    final value =
        m == null ? 'Not set' : known?.label ?? '${m.hostelId} · ${m.messId}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text('Mess', style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              key: const ValueKey('profile.mess'),
              style: textTheme.bodyLarge,
            ),
          ),
          TextButton(
            key: const ValueKey('profile.mess.change'),
            onPressed: () => changeMess(context, ref, currentCode: known?.code),
            child: Text(m == null ? 'Choose' : 'Change'),
          ),
        ],
      ),
    );
  }
}

/// The MESS screen's "Choose your mess" action.
class MessSettingButton extends ConsumerWidget {
  const MessSettingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        key: const ValueKey('mess.choose'),
        onPressed: () => changeMess(context, ref),
        child: const Text('Choose your mess'),
      ),
    );
  }
}

/// A mess's name for a profile reference, from the server list.
String messLabelOf(MessRef ref, List<Mess> list) =>
    list
        .where((m) => m.hostelId == ref.hostelId && m.messId == ref.messId)
        .firstOrNull
        ?.label ??
    '${ref.hostelId} · ${ref.messId}';
