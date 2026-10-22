import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/crash_reporting.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../profile/domain/entities/vocabulary.dart';
import 'policy_text.dart';
import 'privacy_providers.dart';
import '../../../shared/widgets/fit_glass.dart';

/// Phase 17 (§23, ADR-023): the privacy policy, consent per purpose (FITOS AI
/// on or off), downloading everything, and deleting the account.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  void _say(String text, {bool error = false}) => setState(() {
        _message = text;
        _messageIsError = error;
      });

  Future<void> _setAi(bool granted) async {
    setState(() => _busy = true);
    final r = await ref
        .read(privacyApiProvider)
        .setConsent(ConsentType.aiProcessing, granted: granted);
    ref.invalidate(consentsProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r case Err(:final failure)) _say(failure.message, error: true);
  }

  Future<void> _reconsent() async {
    setState(() => _busy = true);
    Failure? failure;
    for (final t in ConsentType.required) {
      final r = await ref.read(privacyApiProvider).setConsent(t, granted: true);
      if (r case Err(failure: final f)) failure = f;
    }
    ref.invalidate(consentsProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) _say(failure.message, error: true);
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    final r = await ref.read(privacyApiProvider).exportJson();
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        final day = DateTime.now().toIso8601String().substring(0, 10);
        try {
          await ref
              .read(exportSharerProvider)
              .share(value, 'fitos-export-$day.json');
          if (mounted) _say('Your data is ready: choose where to save it.');
        } on Object {
          if (mounted) _say('Could not hand the file over.', error: true);
        }
      case Err(:final failure):
        _say(failure.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(privacyApiProvider).deleteAccount();
    if (!mounted) return;
    switch (r) {
      case Ok():
        // Signed out at the end: the router takes the user to sign-in.
        await ref.read(accountEraserProvider).eraseLocal();
      case Err(:final failure):
        setState(() => _busy = false);
        _say(failure.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final consents = ref.watch(consentsProvider);
    final c = consents.value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('PRIVACY & DATA', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            key: const ValueKey('privacy.scroll'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              if (c != null && c.needsReconsent)
                _Card(
                  key: const ValueKey('privacy.reconsent'),
                  border: FitColors.amber,
                  children: <Widget>[
                    Text(
                      'The privacy policy changed',
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      'Version ${c.currentPolicyVersion}. Read it below, then accept it to keep using FITOS.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: FitSpacing.sm),
                    FilledButton(
                      key: const ValueKey('privacy.reconsent.accept'),
                      onPressed: _busy ? null : _reconsent,
                      child: const Text('Accept the updated policy'),
                    ),
                  ],
                ),
              FitSection(
                label: 'FITOS AI',
                children: <Widget>[
                  if (consents.hasError && c == null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: FitSpacing.md),
                      child: Text(
                        (consents.error is Failure
                                ? consents.error! as Failure
                                : const Unknown())
                            .message,
                        key: const ValueKey('privacy.loadError'),
                      ),
                    ),
                  SwitchListTile(
                    key: const ValueKey('privacy.ai'),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Allow FITOS AI', style: textTheme.titleMedium),
                    subtitle: const Text(
                      "Chat, Describe your meal and Explain simply send what you ask to Google's Gemini. "
                      'Off: those features ask before they are used.',
                    ),
                    value: c?.granted(ConsentType.aiProcessing) ?? false,
                    onChanged: c == null || _busy ? null : _setAi,
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.lg),
              FitSection(
                label: 'CRASH REPORTS',
                children: <Widget>[
                  SwitchListTile(
                    key: const ValueKey('privacy.crash'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Send crash reports',
                      style: textTheme.titleMedium,
                    ),
                    subtitle: const Text(
                      'When FITOS crashes, what went wrong goes to Google Firebase Crashlytics: '
                      'never your health, food or workout data. Off: nothing is sent, and unsent reports are deleted.',
                    ),
                    value: ref.watch(crashReportsProvider).value ?? true,
                    onChanged: (v) =>
                        ref.read(crashReportsProvider.notifier).set(v),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.lg),
              FitSection(
                label: 'YOUR DATA',
                children: <Widget>[
                  const SizedBox(height: FitSpacing.sm),
                  Text(
                    'Everything FITOS holds about you, in one machine-readable file (JSON).',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  OutlinedButton.icon(
                    key: const ValueKey('privacy.download'),
                    style: OutlinedButton.styleFrom(
                      shape: fitGlass ? null : const RoundedRectangleBorder(),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _busy ? null : _download,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download my data'),
                  ),
                  const SizedBox(height: FitSpacing.md),
                  Text(
                    'Deleting your account removes every record of it from FITOS at once, '
                    'and your sign-in. It cannot be undone.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  OutlinedButton.icon(
                    key: const ValueKey('privacy.delete'),
                    style: OutlinedButton.styleFrom(
                      shape: fitGlass ? null : const RoundedRectangleBorder(),
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: FitColors.oxide,
                      side: BorderSide(color: FitColors.oxide),
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete my account'),
                  ),
                  if (_message case final m?)
                    Padding(
                      padding: const EdgeInsets.only(top: FitSpacing.sm),
                      child: Text(
                        m,
                        key: const ValueKey('privacy.message'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: _messageIsError
                              ? FitColors.oxide
                              : FitColors.pine,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.lg),
              FitSection(
                label: 'PRIVACY POLICY · VERSION $kPolicyVersion',
                labelKey: const ValueKey('privacy.policy'),
                children: <Widget>[
                  for (final (title, body) in kPolicySections)
                    Padding(
                      padding: const EdgeInsets.only(top: FitSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, style: textTheme.titleMedium),
                          const SizedBox(height: FitSpacing.xs),
                          Text(body, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, required this.border, super.key});

  final List<Widget> children;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: FitSpacing.md),
        padding: const EdgeInsets.all(FitSpacing.md),
        decoration: fitNoticeDecoration(border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

/// Typing DELETE is the confirmation (the server checks the same word).
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim() == 'DELETE';
    return AlertDialog(
      key: const ValueKey('privacy.delete.dialog'),
      shape: fitGlass ? null : const RoundedRectangleBorder(),
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Every workout, meal, weigh-in, check-in and setting is removed now, '
            'with your sign-in. Download your data first if you want a copy.',
          ),
          const SizedBox(height: FitSpacing.md),
          TextField(
            key: const ValueKey('privacy.delete.confirm'),
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('privacy.delete.go'),
          style: FilledButton.styleFrom(backgroundColor: FitColors.oxide),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete everything'),
        ),
      ],
    );
  }
}
