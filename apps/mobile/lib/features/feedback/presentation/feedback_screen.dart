import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/env.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/feedback_api.dart';
import '../../../shared/widgets/fit_glass.dart';

final feedbackApiProvider =
    Provider<FeedbackApi>((ref) => DioFeedbackApi(ref.watch(dioProvider)));

/// Phase 19 (§31 "feedback channel", ADR-026): Profile → Send feedback. A
/// category and a message; the app adds its version. Nothing else about the
/// phone is sent. A failure keeps the text so nothing typed is lost.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  FeedbackCategory? _category;
  bool _busy = false;
  String? _message;
  bool _sent = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_busy && _category != null && _text.text.trim().isNotEmpty;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final build = await ref.read(appBuildProvider.future).catchError((_) => 0);
    final r = await ref.read(feedbackApiProvider).send(
          category: _category!,
          message: _text.text.trim(),
          appVersion: '${Env.appVersion}+$build',
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Ok():
          _sent = true;
          _text.clear();
          _category = null;
          _message = 'Sent. Thank you: the developer reads every one.';
        case Err(:final failure):
          _sent = false;
          _message = switch (failure) {
            Offline() =>
              'Feedback needs a connection. Your text is still here.',
            // The server's hourly limit against spam (20 an hour).
            RateLimited() =>
              'That is a lot of feedback in one hour, thank you! Please send this one a little later. Your text is still here.',
            _ => failure.message,
          };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('SEND FEEDBACK', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              Text(
                'Something broke, something is missing, or an idea: it goes '
                'straight to the developer, with the app version. Nothing else '
                'about your phone is sent.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.lg),
              Text('ABOUT', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Wrap(
                spacing: FitSpacing.sm,
                runSpacing: FitSpacing.sm,
                children: <Widget>[
                  for (final c in FeedbackCategory.values)
                    ChoiceChip(
                      key: ValueKey('feedback.category.${c.wire}'),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                                _category = c;
                                _sent = false;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.lg),
              TextField(
                key: const ValueKey('feedback.message'),
                controller: _text,
                enabled: !_busy,
                minLines: 5,
                maxLines: 12,
                maxLength: kFeedbackMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What happened, or what would help?',
                  border: fitGlass
                      ? null
                      : const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                ),
                onChanged: (_) => setState(() => _sent = false),
              ),
              const SizedBox(height: FitSpacing.sm),
              FilledButton(
                key: const ValueKey('feedback.send'),
                style: FilledButton.styleFrom(
                  shape: fitGlass ? null : const RoundedRectangleBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _ready ? _send : null,
                child: Text(_busy ? 'Sending…' : 'Send'),
              ),
              if (_message case final m?)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.sm),
                  child: Text(
                    m,
                    key: const ValueKey('feedback.result'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: _sent ? FitColors.pine : FitColors.oxide,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
