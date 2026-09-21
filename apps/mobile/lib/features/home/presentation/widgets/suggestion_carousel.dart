import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/home_suggestion_engine.dart';

/// "Your next move": a horizontally swipeable row of the engine's top
/// suggestions. One card is the width of the screen minus a peek of the
/// next; hairline border, no shadow, the kind as an eyebrow, the title
/// in the display face, one line of context, one action. Dots below
/// when there is more than one.
class SuggestionCarousel extends StatefulWidget {
  const SuggestionCarousel({
    required this.suggestions,
    required this.onAction,
    super.key,
  });

  final List<Suggestion> suggestions;
  final ValueChanged<Suggestion> onAction;

  static String eyebrow(SuggestionType t) => switch (t) {
        SuggestionType.deload => 'DELOAD',
        SuggestionType.resumeWorkout ||
        SuggestionType.startWorkout ||
        SuggestionType.workoutDone ||
        SuggestionType.neglect ||
        SuggestionType.restDay =>
          'TRAIN',
        SuggestionType.eatProtein || SuggestionType.eatCalories => 'EAT',
        SuggestionType.recover => 'RECOVER',
        SuggestionType.celebratePr => 'RECORD',
        SuggestionType.volume => 'VOLUME',
        SuggestionType.move => 'MOVE',
        SuggestionType.connectHealth => 'HEALTH',
      };

  static String actionLabel(SuggestionAction a) => switch (a) {
        SuggestionAction.resumeWorkout => 'Resume workout',
        SuggestionAction.startWorkout => 'Start workout',
        SuggestionAction.viewSummary => 'See the summary',
        SuggestionAction.viewPlan => 'Open your plan',
        SuggestionAction.logFood => 'Log food',
        SuggestionAction.viewActivity => 'View activity',
        SuggestionAction.viewRecovery => 'View recovery',
        SuggestionAction.viewVolume => 'Training volume',
        SuggestionAction.connectHealth => 'Connect Health data',
      };

  /// Semantic colour only where it carries meaning (§6.2).
  static Color eyebrowColor(SuggestionType t) => switch (t) {
        SuggestionType.deload => FitColors.amber,
        SuggestionType.recover => FitColors.amber,
        SuggestionType.celebratePr ||
        SuggestionType.workoutDone =>
          FitColors.pine,
        _ => FitColors.ink60,
      };

  @override
  State<SuggestionCarousel> createState() => _SuggestionCarouselState();
}

class _SuggestionCarouselState extends State<SuggestionCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final n = widget.suggestions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: n,
            onPageChanged: (i) => setState(() => _page = i),
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
                  onAction: () => widget.onAction(s),
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
    required this.onAction,
    required this.textTheme,
    super.key,
  });

  final Suggestion suggestion;
  final VoidCallback onAction;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Container(
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: FitColors.rule)),
        borderRadius: BorderRadius.all(FitRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            SuggestionCarousel.eyebrow(s.type),
            style: textTheme.labelSmall?.copyWith(
              color: SuggestionCarousel.eyebrowColor(s.type),
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
          Text(
            s.subtitle,
            key: ValueKey('home.suggestion.${s.id}.subtitle'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: ValueKey('home.suggestion.${s.id}.action'),
              onPressed: onAction,
              child: Text(SuggestionCarousel.actionLabel(s.action)),
            ),
          ),
        ],
      ),
    );
  }
}

/// "More for you": the rest of the engine's list as plain rows.
class MoreForYou extends StatelessWidget {
  const MoreForYou({
    required this.suggestions,
    required this.onAction,
    super.key,
  });

  final List<Suggestion> suggestions;
  final ValueChanged<Suggestion> onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (final s in suggestions) ...<Widget>[
          const Divider(color: FitColors.rule, height: 1),
          InkWell(
            key: ValueKey('home.more.${s.id}'),
            onTap: () => onAction(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FitSpacing.screen,
                vertical: FitSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(s.title, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          s.subtitle,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.ink60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: FitColors.ink60,
                  ),
                ],
              ),
            ),
          ),
        ],
        const Divider(color: FitColors.rule, height: 1),
      ],
    );
  }
}
