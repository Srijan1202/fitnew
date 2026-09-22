import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The FITOS wordmark (Phase 6.6): the mark — a geometric F whose middle
/// bar runs on as the hairline — beside the name in the display face.
/// Drawn, not an image, so it is crisp at any size and needs no asset.
class FitosWordmark extends StatelessWidget {
  const FitosWordmark({this.size = 40, this.withName = true, super.key});

  /// Height of the mark in logical pixels.
  final double size;
  final bool withName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: 'FITOS',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(size, size),
            painter: const _MarkPainter(),
          ),
          if (withName) ...<Widget>[
            SizedBox(width: size * 0.3),
            Text(
              'FITOS',
              style: textTheme.displayMedium?.copyWith(
                color: FitColors.ink,
                letterSpacing: size * 0.06,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The same proportions as `tool/brand.py`, in a 100-unit box.
class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    final ink = Paint()..color = FitColors.ink;
    Rect box(double x0, double y0, double x1, double y1) =>
        Rect.fromLTRB(x0 * u, y0 * u, x1 * u, y1 * u);
    canvas
      ..drawRect(box(14, 8, 32, 92), ink) // stem
      ..drawRect(box(14, 8, 86, 26), ink) // top bar
      ..drawRect(box(14, 44, 68, 58), ink) // middle bar
      ..drawRect(box(68, 49, 100, 53), ink); // …the rule
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
