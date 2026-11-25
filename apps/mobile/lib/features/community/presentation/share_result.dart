import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fitos_wordmark.dart';
import '../../running/presentation/screens/share_run_screen.dart';
import '../domain/club_goals.dart';

/// Beta 6.6 (M2): what a shared result says: club names and averages, or
/// the club's place; never a member's name or handle. Made on the phone and
/// handed to the share sheet; nothing is uploaded.
class ResultCardText {
  const ResultCardText({
    required this.title,
    required this.big,
    required this.line,
    required this.fileName,
  });

  /// After a match.
  factory ResultCardText.match(ClubMatch m) {
    final title = switch (m.result) {
      MatchResult.won => '${m.us.name} won',
      MatchResult.lost => '${m.them.name} won',
      _ => 'A draw',
    };
    return ResultCardText(
      title: title,
      big: '${m.us.name} ${countText(m.us.score ?? 0)} · '
          '${countText(m.them.score ?? 0)} ${m.them.name}',
      line: '${m.perMemberUnit} · the week of ${dayLabel(m.weekFrom)}',
      fileName: 'fitos-match-${m.weekFrom}.png',
    );
  }

  /// The club's place in the league.
  factory ResultCardText.league(String club, ClubLeague l) {
    final me = l.me!;
    final over = l.seasonFinished;
    return ResultCardText(
      title: over
          ? '$club finished ${ordinalOf(me.place)}'
          : '$club is ${ordinalOf(me.place)}',
      big: '${ordinalOf(me.place)} of ${l.clubs} · ${me.points} '
          '${me.points == 1 ? 'point' : 'points'}',
      line: 'FITOS club league · ${dayLabel(l.seasonFrom!)} to '
          '${dayLabel(l.seasonTo!)}',
      fileName: 'fitos-league-${l.seasonFrom}.png',
    );
  }

  final String title;
  final String big;
  final String line;
  final String fileName;
}

/// A sheet with the card and a Share button.
Future<void> showShareResult(
  BuildContext context,
  ResultCardText text,
) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ShareResultSheet(text: text),
    );

class _ShareResultSheet extends ConsumerStatefulWidget {
  const _ShareResultSheet({required this.text});

  final ResultCardText text;

  @override
  ConsumerState<_ShareResultSheet> createState() => _ShareResultSheetState();
}

class _ShareResultSheetState extends ConsumerState<_ShareResultSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      await ref.read(runSharerProvider).share(
            png.buffer.asUint8List(),
            widget.text.fileName,
            'image/png',
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final x = widget.text;
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: _card,
            child: Container(
              key: const ValueKey('shareResult.card'),
              padding: const EdgeInsets.all(FitSpacing.lg),
              decoration: BoxDecoration(
                color: FitColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FitColors.rule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FitosWordmark(size: 28),
                  const SizedBox(height: FitSpacing.lg),
                  Text(x.title, style: t.titleLarge),
                  const SizedBox(height: FitSpacing.xs),
                  Text(
                    x.big,
                    style:
                        t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  Text(
                    x.line,
                    style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FitSpacing.md),
          Text(
            'Club names and averages only, never who is in a club. The '
            'picture is made on your phone.',
            style: t.bodySmall?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.md),
          FilledButton.icon(
            key: const ValueKey('shareResult.share'),
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share),
            label: Text(_busy ? 'Making the picture…' : 'Share'),
          ),
        ],
      ),
    );
  }
}
