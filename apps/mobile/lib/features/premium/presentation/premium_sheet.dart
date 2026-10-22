import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/tokens.dart';
import '../domain/avatars.dart';
import '../domain/premium.dart';
import 'premium_providers.dart';
import '../../../shared/widgets/fit_glass.dart';

/// Phase 19 (ADR-027): what premium unlocks, and the request. Shown by the
/// AI tab, by every premium entry point, and from Profile → Premium.
Future<void> showPremiumSheet(BuildContext context, {String? feature}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PremiumSheet(feature: feature),
    );

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet({this.feature});

  final String? feature;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          FitSpacing.screen,
          0,
          FitSpacing.screen,
          FitSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: PremiumPitch(
            key: const ValueKey('premium.sheet'),
            feature: feature,
          ),
        ),
      );
}

/// What premium unlocks and the request, as one column: in the sheet, and
/// in place of the AI tab for a free user.
class PremiumPitch extends ConsumerWidget {
  const PremiumPitch({this.feature, super.key});

  final String? feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final status = ref.watch(premiumStatusProvider).value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.workspace_premium, color: kGold),
            const SizedBox(width: FitSpacing.sm),
            Text('FITOS PREMIUM', style: textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          feature == null ? 'More from FITOS' : '$feature is part of Premium',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: FitSpacing.md),
        for (final (title, body) in kPremiumPerks)
          Padding(
            padding: const EdgeInsets.only(bottom: FitSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check, size: 18, color: kGoldDeep),
                ),
                const SizedBox(width: FitSpacing.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$title. ',
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: body),
                      ],
                    ),
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'During the beta, premium is free: ask, and the FITOS team turns it on.',
          style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
        ),
        const SizedBox(height: FitSpacing.md),
        PremiumRequestPanel(status: status),
      ],
    );
  }
}

/// The request, as the status allows it: ask (with an optional message),
/// waiting, the owner's answer, or premium already.
class PremiumRequestPanel extends ConsumerStatefulWidget {
  const PremiumRequestPanel({required this.status, super.key});

  final PremiumStatus? status;

  @override
  ConsumerState<PremiumRequestPanel> createState() =>
      _PremiumRequestPanelState();
}

class _PremiumRequestPanelState extends ConsumerState<PremiumRequestPanel> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref
        .read(premiumApiProvider)
        .request(message: _message.text.trim());
    ref.invalidate(premiumStatusProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r case Err(:final failure)) _error = failure.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = widget.status;
    if (s != null && s.premium) {
      return Text(
        s.source == 'admin'
            ? 'You have Premium as an administrator.'
            : 'You have Premium. Enjoy it.',
        key: const ValueKey('premium.active'),
        style: textTheme.bodyLarge?.copyWith(color: FitColors.pine),
      );
    }
    if (s != null && s.pending) {
      return Text(
        'Requested. You will see Premium here as soon as it is approved.',
        key: const ValueKey('premium.pending'),
        style: textTheme.bodyLarge,
      );
    }
    final denied = s?.request?.status == PremiumRequestStatus.denied;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (denied)
          Padding(
            padding: const EdgeInsets.only(bottom: FitSpacing.sm),
            child: Text(
              'Your last request was not approved'
              '${s!.request!.note == null ? '.' : ': ${s.request!.note}'}'
              ' You can ask again.',
              key: const ValueKey('premium.denied'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
            ),
          ),
        TextField(
          key: const ValueKey('premium.message'),
          controller: _message,
          enabled: !_busy,
          maxLength: 500,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Anything to add? (optional)',
            border: fitGlass
                ? null
                : const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('premium.request'),
          style: FilledButton.styleFrom(
            backgroundColor: kGoldDeep,
            shape: fitGlass ? null : const RoundedRectangleBorder(),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _busy ? null : _request,
          icon: const Icon(Icons.workspace_premium),
          label: Text(_busy ? 'Asking…' : 'Request Premium'),
        ),
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: Text(
              e,
              key: const ValueKey('premium.error'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
            ),
          ),
      ],
    );
  }
}
