import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../workout/presentation/controllers/rest_timer.dart'
    show sharedPreferencesProvider;

/// Phase 6.6 (owner B3): a user who onboarded before the name existed is
/// asked once, here on Home. Save writes `users.display_name` through the
/// profile; "Not now" remembers the choice on this phone. Never shown
/// again once either happens.
class NamePrompt extends ConsumerStatefulWidget {
  const NamePrompt({super.key});

  static const dismissedKey = 'home.nameAsked';

  @override
  ConsumerState<NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends ConsumerState<NamePrompt> {
  final _name = TextEditingController();
  bool _busy = false;
  Failure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 40) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure =
        await ref.read(profileControllerProvider.notifier).setDisplayName(name);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  Future<void> _notNow() async {
    await ref
        .read(sharedPreferencesProvider)
        .value
        ?.setBool(NamePrompt.dismissedKey, true);
    ref.invalidate(namePromptDismissedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('home.namePrompt'),
      margin: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: FitColors.rule)),
        borderRadius: BorderRadius.all(FitRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('ONE THING', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text('What should we call you?', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          AuthFormField(
            fieldKey: const ValueKey('home.namePrompt.field'),
            label: 'Your name',
            controller: _name,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          if (_failure != null) ...<Widget>[
            const SizedBox(height: FitSpacing.xs),
            Text(
              _failure!.message,
              key: const ValueKey('home.namePrompt.error'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
            ),
          ],
          const SizedBox(height: FitSpacing.sm),
          Row(
            children: <Widget>[
              FilledButton(
                key: const ValueKey('home.namePrompt.save'),
                onPressed: _busy || _name.text.trim().isEmpty ? null : _save,
                child: const Text('Save'),
              ),
              const SizedBox(width: FitSpacing.sm),
              TextButton(
                key: const ValueKey('home.namePrompt.notNow'),
                onPressed: _busy ? null : _notNow,
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// True once the user chose "Not now" on this phone.
final namePromptDismissedProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  return prefs?.getBool(NamePrompt.dismissedKey) ?? false;
});
