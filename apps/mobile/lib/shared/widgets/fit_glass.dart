import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// ADR-029: the iPhone-like look of the glass palettes — rounded, slightly
/// translucent blocks with a soft shadow in the palette's glow colour, over a
/// faint glow on the canvas. On Paper (`glass: false`) every widget here
/// draws nothing extra, so Paper keeps the flat §6 look.
bool get fitGlass => FitPalette.current.glass;

/// A block: a rounded translucent surface with a soft coloured shadow. On a
/// flat palette it is only its child (and [flatPadding]).
class FitBlock extends StatelessWidget {
  const FitBlock({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.flatPadding = EdgeInsets.zero,
    this.onTap,
    this.glow = false,
    super.key,
  });

  final Widget child;

  /// Inside the block (glass only).
  final EdgeInsetsGeometry padding;

  /// Around the block (glass only).
  final EdgeInsetsGeometry margin;

  /// Around the child on a flat palette.
  final EdgeInsetsGeometry flatPadding;
  final VoidCallback? onTap;

  /// A stronger glow, for the one block a screen leads with.
  final bool glow;

  /// The block surface: a sheen from the top left, translucent.
  static BoxDecoration decoration({bool glow = false, Radius? radius}) {
    final p = FitPalette.current;
    final dark = p.brightness == Brightness.dark;
    final r = BorderRadius.all(radius ?? FitRadius.block);
    return BoxDecoration(
      borderRadius: r,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? <Color>[
                p.ink.withValues(alpha: 0.085),
                p.ink.withValues(alpha: 0.035),
              ]
            : <Color>[
                Colors.white.withValues(alpha: 0.86),
                Colors.white.withValues(alpha: 0.62),
              ],
      ),
      border: Border.all(
        color: dark
            ? p.ink.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.9),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: p.glow.withValues(
            alpha: glow ? (dark ? 0.22 : 0.28) : (dark ? 0.10 : 0.16),
          ),
          blurRadius: glow ? 32 : 24,
          offset: const Offset(0, 8),
          // Outside the shape only: a translucent block must not show its
          // own shadow through itself.
          blurStyle: BlurStyle.outer,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.30 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
          blurStyle: BlurStyle.outer,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!fitGlass) {
      final body = Padding(padding: flatPadding, child: child);
      return onTap == null ? body : InkWell(onTap: onTap, child: body);
    }
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(FitRadius.block),
    );
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: decoration(glow: glow),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: _BlockScope(
            child: onTap == null
                ? Padding(padding: padding, child: child)
                : InkWell(
                    onTap: onTap,
                    customBorder: shape,
                    child: Padding(padding: padding, child: child),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Marks content as inside a block, so a grid there uses inner tiles.
class _BlockScope extends InheritedWidget {
  const _BlockScope({required super.child});

  static bool inBlock(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BlockScope>() != null;

  @override
  bool updateShouldNotify(_BlockScope oldWidget) => false;
}

/// Tiles two a row. Glass: separate rounded tiles with a gap — blocks on the
/// canvas, or recessed tiles inside a block. Flat: the §6 hairline grid.
class FitTileGrid extends StatelessWidget {
  const FitTileGrid({
    required this.tiles,
    this.margin = const EdgeInsets.symmetric(horizontal: FitSpacing.md),
    super.key,
  });

  final List<Widget> tiles;

  /// Around the grid (glass only).
  final EdgeInsetsGeometry margin;

  static const double gap = 10;

  @override
  Widget build(BuildContext context) {
    if (!fitGlass) return _flat();
    final inner = _BlockScope.inBlock(context);
    Widget tile(Widget child) => inner
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: FitColors.ink.withValues(alpha: 0.045),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: child,
          )
        : FitBlock(child: child);
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: tile(tiles[i])),
              const SizedBox(width: gap),
              Expanded(
                child: i + 1 < tiles.length
                    ? tile(tiles[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(padding: margin, child: Column(children: rows));
  }

  Widget _flat() {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows
        ..add(Divider(color: FitColors.rule, height: 1))
        ..add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                VerticalDivider(color: FitColors.rule, width: 1),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
    }
    rows.add(Divider(color: FitColors.rule, height: 1));
    return Column(children: rows);
  }
}

/// A section edge: the §6.4 hairline on Paper, nothing between blocks.
class FitRule extends StatelessWidget {
  const FitRule({super.key});

  @override
  Widget build(BuildContext context) => fitGlass
      ? const SizedBox.shrink()
      : Divider(color: FitColors.rule, height: 1);
}

/// The canvas behind a glass screen: two soft pools of the glow colour, so
/// the translucent blocks have something to show through. Nothing on Paper.
class FitBackdrop extends StatelessWidget {
  const FitBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!fitGlass) return child;
    final p = FitPalette.current;
    final dark = p.brightness == Brightness.dark;
    Widget pool(Alignment at, double radius, double alpha) => Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: at,
                  radius: radius,
                  colors: <Color>[
                    p.glow.withValues(alpha: alpha),
                    p.glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
    return Stack(
      children: <Widget>[
        pool(const Alignment(1.1, -1.05), 1.1, dark ? 0.16 : 0.20),
        pool(const Alignment(-1.2, 0.35), 0.9, dark ? 0.07 : 0.10),
        child,
      ],
    );
  }
}

/// iOS-style grouped list: an eyebrow, then rows in one block with inset
/// dividers. Flat palettes: hairline rows.
class FitGroup extends StatelessWidget {
  const FitGroup({required this.children, this.label, super.key});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 || !fitGlass) {
        rows.add(
          Divider(
            color: FitColors.rule.withValues(alpha: fitGlass ? 0.6 : 1),
            height: 1,
            indent: fitGlass ? 56 : 0,
          ),
        );
      }
      rows.add(children[i]);
    }
    if (!fitGlass) rows.add(Divider(color: FitColors.rule, height: 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              fitGlass ? FitSpacing.sm : 0,
              0,
              0,
              FitSpacing.sm,
            ),
            child: Text(
              label!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        FitBlock(child: Column(children: rows)),
      ],
    );
  }
}

/// A row in a [FitGroup]: an icon in a tinted rounded square, a title, an
/// optional value, a chevron.
class FitRow extends StatelessWidget {
  const FitRow({
    required this.icon,
    required this.title,
    this.value,
    this.valueKey,
    this.onTap,
    this.destructive = false,
    this.tint,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Key? valueKey;
  final VoidCallback? onTap;
  final bool destructive;

  /// The icon square's colour; the palette's glow by default.
  final Color? tint;

  /// In place of the chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colour =
        destructive ? FitColors.oxide : (tint ?? FitPalette.current.glow);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fitGlass ? 14 : 0,
            vertical: 10,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: fitGlass ? 0.18 : 0),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: destructive
                      ? FitColors.oxide
                      : (fitGlass &&
                              FitPalette.current.brightness == Brightness.dark
                          ? colour
                          : FitColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: destructive ? FitColors.oxide : FitColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: FitSpacing.sm),
                    child: Text(
                      value!,
                      key: valueKey,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ),
                ),
              if (trailing != null)
                trailing!
              else if (onTap != null && !destructive)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: FitColors.ink35,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
