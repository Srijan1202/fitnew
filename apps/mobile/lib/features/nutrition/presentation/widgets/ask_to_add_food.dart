import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../controllers/food_providers.dart';

/// Beta 3.2 (ADR-032): "Ask us to add it" under a search that found nothing.
/// The search itself was already reported quietly; this says a person wants
/// it, which moves it up the admin panel's list.
class AskToAddFood extends ConsumerStatefulWidget {
  const AskToAddFood({required this.query, super.key});

  final String query;

  @override
  ConsumerState<AskToAddFood> createState() => _AskToAddFoodState();
}

class _AskToAddFoodState extends ConsumerState<AskToAddFood> {
  bool _busy = false;
  bool? _sent;

  @override
  void didUpdateWidget(AskToAddFood old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _sent = null;
  }

  Future<void> _ask() async {
    setState(() => _busy = true);
    final ok = await ref.read(missingFoodReporterProvider).ask(widget.query);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_sent ?? false) {
      return Text(
        'Thanks. We’ll look at adding “${widget.query}” in a coming update.',
        key: const ValueKey('food.ask.done'),
        style: textTheme.bodyMedium?.copyWith(color: FitColors.pine),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlinedButton.icon(
          key: const ValueKey('food.ask'),
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: Text('Ask us to add “${widget.query}”'),
        ),
        if (_sent == false) ...<Widget>[
          const SizedBox(height: FitSpacing.xs),
          Text(
            'Could not send that just now. Try again when you are online.',
            key: const ValueKey('food.ask.failed'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
          ),
        ],
      ],
    );
  }
}
