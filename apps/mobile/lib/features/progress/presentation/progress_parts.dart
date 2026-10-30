part of 'progress_screen.dart';

/* ------------------------------------------------------- building blocks -- */

/// §6.2: corners of 2 px and an ink outline for this page's secondary buttons.
// A getter: built on each read, so it follows the palette.
ButtonStyle get _squareOutline => OutlinedButton.styleFrom(
      foregroundColor: FitColors.ink,
      side: BorderSide(color: FitColors.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(FitRadius.small),
      ),
      minimumSize: const Size.fromHeight(44),
    );

class _Pad extends StatelessWidget {
  const _Pad({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        // Beta 4.8: the screen margin every tab uses.
        padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
        child: child,
      );
}

/// ADR-029: a section's body in a rounded block; nothing extra on Paper.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FitBlock(
        // Beta 4.8: the screen margin every tab uses (it was 12).
        margin: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
        child: child,
      );
}

/// §6.4: a section starts with a hairline, 14 px, then its label and one
/// line on what it shows (beta 3.9: every section the same way, and the
/// label is never repeated inside the block).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.sub});

  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const FitRule(),
          SizedBox(height: fitGlass ? FitSpacing.sm : FitSpacing.afterRule),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Beta 4.8: the label style of every other section.
                Text(title.toUpperCase(), style: textTheme.labelSmall),
                if (sub != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: fitGlass ? FitSpacing.sm : FitSpacing.md),
        ],
      ),
    );
  }
}

/// A metric tile: label, the number as the hero, one line of context.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    this.valueKey,
    this.captionKey,
    this.muted = false,
    this.bar,
  });

  final String label;
  final String value;
  final String caption;
  final Key? valueKey;
  final Key? captionKey;

  /// A quieter value (a message rather than a number).
  final bool muted;

  /// A 0–1 share drawn as a thin bar under the value (adherence).
  final double? bar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: fitGlass ? 14 : FitSpacing.screen,
        vertical: fitGlass ? 12 : FitSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          if (muted)
            Text(
              value,
              key: valueKey,
              style: textTheme.titleMedium?.copyWith(color: FitColors.ink60),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          else
            // A number shrinks to fit its tile ("−0.4 kg / week") rather
            // than ending in an ellipsis.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                style: textTheme.displaySmall,
                maxLines: 1,
              ),
            ),
          if (bar != null) ...<Widget>[
            const SizedBox(height: FitSpacing.sm),
            _Bar(bar!),
          ],
          const SizedBox(height: FitSpacing.xs),
          Text(
            caption,
            key: captionKey,
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

/// Two tiles a row, divided by hairlines (the Home grid).
class _StatGrid extends StatelessWidget {
  const _StatGrid(this.tiles);

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => FitTileGrid(
        tiles: tiles,
        margin: const EdgeInsets.symmetric(horizontal: FitSpacing.md),
      );
}

/// A thin share bar: pine fill (on track, §6.2) on the recessed paper.
class _Bar extends StatelessWidget {
  const _Bar(this.share);

  final double share;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.all(FitRadius.small),
        child: LinearProgressIndicator(
          value: share.clamp(0, 1),
          minHeight: 6,
          color: FitColors.pine,
          backgroundColor: FitColors.paper2,
        ),
      );
}

/// A quiet explanatory line with an icon.
class _Note extends StatelessWidget {
  const _Note(this.text, {this.textKey, this.icon = Icons.info_outline});

  final String text;

  /// On the text itself, so it can be found and read.
  final Key? textKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: FitColors.ink60),
        ),
        const SizedBox(width: FitSpacing.sm),
        Expanded(
          child: Text(
            text,
            key: textKey,
            style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ),
      ],
    );
  }
}

/// A recessed panel for instructions (sparse states, §6.6).
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.body, this.panelKey});

  final String title;
  final String body;
  final Key? panelKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: panelKey,
      width: double.infinity,
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: BoxDecoration(
        color: fitGlass
            ? FitColors.ink.withValues(alpha: 0.045)
            : FitColors.paper2,
        borderRadius: BorderRadius.all(FitRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: FitSpacing.xs),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

/// A hairline between rows inside a block (inset on glass).
class _RowRule extends StatelessWidget {
  const _RowRule();

  @override
  Widget build(BuildContext context) => Divider(
        color: FitColors.rule,
        height: 1,
        indent: fitGlass ? FitSpacing.md : 0,
        endIndent: fitGlass ? FitSpacing.md : 0,
      );
}
