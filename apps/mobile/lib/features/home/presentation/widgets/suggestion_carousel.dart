import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../today/domain/today.dart';
import '../../../today/presentation/today_words.dart';
import '../../domain/home_suggestion_engine.dart';

/// "Your next move": a horizontally swipeable row of at most four cards —
/// the server's TODAY actions and the device-only suggestions, by band.
/// One card is the width of the screen minus a peek of the next; hairline
/// border, no shadow, the kind as an eyebrow, the headline in the display
/// face, one line of context, the primary action — and, on a server card,
/// "Not today". Tapping a server card opens its "why". Dots below when
/// there is more than one.
class SuggestionCarousel extends StatefulWidget {
  const SuggestionCarousel({
    required this.suggestions,
    required this.onAction,
    this.onOpen,
    this.onDismiss,
    this.onShown,
    this.recorded = const {},
    this.messConfigured = false,
    super.key,
  });

  final List<Suggestion> suggestions;
  final ValueChanged<Suggestion> onAction;

  /// A server card tapped (→ `opened` and its "why" sheet).
  final ValueChanged<Suggestion>? onOpen;

  /// "Not today" on a server card (→ `dismissed`).
  final ValueChanged<Suggestion>? onDismiss;

  /// A server card actually on screen (→ `shown`, once per action).
  final ValueChanged<Suggestion>? onShown;

  /// Events already recorded on this phone, by server action id.
  final Map<String, Set<TodayEventName>> recorded;

  /// Whether the user has a mess (eat actions then open MESS).
  final bool messConfigured;

  static String eyebrow(Suggestion s) {
    final kind = s.today?.kind;
    if (kind != null) {
      return s.cached
          ? '${TodayWords.eyebrow(kind)} · OFFLINE'
          : TodayWords.eyebrow(kind);
    }
    return switch (s.type) {
      SuggestionType.resumeWorkout => 'TRAIN',
      SuggestionType.recover => 'RECOVER',
      SuggestionType.move => 'MOVE',
      SuggestionType.connectHealth => 'HEALTH',
      SuggestionType.today => '',
    };
  }

  static String actionLabel(Suggestion s, {bool messConfigured = false}) {
    final a = s.today;
    if (a != null) return TodayWords.primary(a, messConfigured: messConfigured);
    return switch (s.action) {
      SuggestionAction.resumeWorkout => 'Resume workout',
      SuggestionAction.viewActivity => 'View activity',
      SuggestionAction.viewRecovery => 'View recovery',
      SuggestionAction.connectHealth => 'Connect Health data',
      SuggestionAction.today => '',
    };
  }

  /// Semantic colour only where it carries meaning (§6.2).
  static Color eyebrowColor(Suggestion s) {
    final kind = s.today?.kind;
    if (kind != null) return TodayWords.eyebrowColor(kind);
    return s.type == SuggestionType.recover ? FitColors.amber : FitColors.ink60;
  }

  @override
  State<SuggestionCarousel> createState() => _SuggestionCarouselState();
}

class _SuggestionCarouselState extends State<SuggestionCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  /// Reported this lifetime; the ledger dedups across rebuilds and restarts.
  final _reported = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reportVisible() {
    final n = widget.suggestions.length;
    if (n == 0 || widget.onShown == null) return;
    final s = widget.suggestions[_page.clamp(0, n - 1)];
    final id = s.today?.id;
    if (id == null || _reported.contains(id)) return;
    _reported.add(id);
    widget.onShown!(s);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final n = widget.suggestions.length;
    if (_page >= n && n > 0) _page = n - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportVisible();
    });
    // Room for two buttons and larger text (§6.8: text scales to 200 %).
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 212 * scale,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: n,
            onPageChanged: (i) {
              setState(() => _page = i);
            },
            itemBuilder: (context, i) {
              final s = widget.suggestions[i];
              return Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? FitSpacing.screen : FitSpacing.sm,
                  right: i == n - 1 ? FitSpacing.screen : 0,
                ),
                child: _Card(
                  key: ValueKey('home.suggestion.${s.id}'),
                  suggestion: s,
                  messConfigured: widget.messConfigured,
                  recorded: s.today == null
                      ? const {}
                      : widget.recorded[s.today!.id] ?? const {},
                  onAction: () => widget.onAction(s),
                  onOpen: s.isServer && widget.onOpen != null
                      ? () => widget.onOpen!(s)
                      : null,
                  onDismiss: s.isServer && widget.onDismiss != null
                      ? () => widget.onDismiss!(s)
                      : null,
                  textTheme: textTheme,
                ),
              );
            },
          ),
        ),
        if (n > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              0,
            ),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < n; i++)
                  Container(
                    key: ValueKey('home.dot.$i'),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i == _page ? FitColors.ink : FitColors.ink35,
                      borderRadius: const BorderRadius.all(FitRadius.small),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.suggestion,
    required this.messConfigured,
    required this.recorded,
    required this.onAction,
    required this.onOpen,
    required this.onDismiss,
    required this.textTheme,
    super.key,
  });

  final Suggestion suggestion;
  final bool messConfigured;
  final Set<TodayEventName> recorded;
  final VoidCallback onAction;
  final VoidCallback? onOpen;
  final VoidCallback? onDismiss;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    // Once accepted, "Not today" is no longer a choice (P2).
    final canDismiss =
        onDismiss != null && !recorded.contains(TodayEventName.accepted);
    final body = Padding(
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            SuggestionCarousel.eyebrow(s),
            key: ValueKey('home.suggestion.${s.id}.eyebrow'),
            style: textTheme.labelSmall?.copyWith(
              color: SuggestionCarousel.eyebrowColor(s),
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            s.title,
            key: ValueKey('home.suggestion.${s.id}.title'),
            style: textTheme.displaySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: FitSpacing.xs),
          Flexible(
            child: Text(
              s.subtitle,
              key: ValueKey('home.suggestion.${s.id}.subtitle'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: FitSpacing.sm,
            runSpacing: FitSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton(
                key: ValueKey('home.suggestion.${s.id}.action'),
                onPressed: onAction,
                child: Text(
                  SuggestionCarousel.actionLabel(
                    s,
                    messConfigured: messConfigured,
                  ),
                ),
              ),
              if (canDismiss)
                TextButton(
                  key: ValueKey('home.suggestion.${s.id}.dismiss'),
                  onPressed: onDismiss,
                  child: const Text('Not today'),
                ),
            ],
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: FitColors.rule),
        borderRadius: BorderRadius.all(FitRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: onOpen == null
          ? body
          : InkWell(
              key: ValueKey('home.suggestion.${s.id}.open'),
              onTap: onOpen,
              child: body,
            ),
    );
  }
}
