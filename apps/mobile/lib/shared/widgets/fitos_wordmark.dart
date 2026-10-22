import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The FITOS logo (ADR-028, brand/README.md): the F of two italic blades
/// beside the FITOS capitals, both the brand kit's own geometry
/// (brand/build_kit.py) drawn as paths, so it is crisp at any size and
/// needs no asset or font. The brand themes draw the mark in the lime
/// gradient; the others in ink, like the kit's minimal logo.
class FitosWordmark extends StatelessWidget {
  const FitosWordmark({this.size = 40, this.withName = true, super.key});

  /// Height of the mark in logical pixels.
  final double size;
  final bool withName;

  @override
  Widget build(BuildContext context) {
    final palette = FitPalette.current;
    // Cap height of the name, and the gap, as in the horizontal logo.
    final cap = size * 0.36;
    return Semantics(
      label: 'FITOS',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(size * FitosMarkPainter.aspect, size),
            painter: FitosMarkPainter(
              gradient: palette.brandMark,
              ink: FitColors.ink,
            ),
          ),
          if (withName) ...<Widget>[
            SizedBox(width: size * 0.22),
            CustomPaint(
              size: Size(cap * FitosNamePainter.aspect, cap),
              painter: FitosNamePainter(FitColors.ink),
            ),
          ],
        ],
      ),
    );
  }
}

/// The F mark, drawn in its visible box (x 16–98, y 6–94 of the kit's 100).
class FitosMarkPainter extends CustomPainter {
  FitosMarkPainter({required this.gradient, required this.ink});

  final bool gradient;
  final Color ink;

  static const double _x0 = 16;
  static const double _y0 = 6;
  static const double _w = 82;
  static const double _h = 88;
  static const double aspect = _w / _h;

  /// The two blades in the kit's 100-unit box.
  static Path blades() {
    final upper = Path()
      ..moveTo(34, 6)
      ..lineTo(98, 6)
      ..cubicTo(95, 13, 90, 19, 82, 22)
      ..lineTo(47, 22)
      ..cubicTo(41, 22, 37, 26, 34, 31)
      ..lineTo(24, 52)
      ..cubicTo(21, 44, 22, 34, 26, 24)
      ..close();
    final lower = Path()
      ..moveTo(44, 36)
      ..lineTo(80, 36)
      ..cubicTo(77, 43, 72, 48, 65, 50)
      ..lineTo(50, 50)
      ..cubicTo(44, 50, 40, 54, 37, 59)
      ..lineTo(20, 94)
      ..cubicTo(16, 84, 17, 72, 22, 62)
      ..lineTo(33, 42)
      ..cubicTo(36, 38, 40, 36, 44, 36)
      ..close();
    return Path()
      ..addPath(upper, Offset.zero)
      ..addPath(lower, Offset.zero);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / _h;
    canvas
      ..save()
      ..scale(s)
      ..translate(-_x0, -_y0);
    final paint = Paint()..isAntiAlias = true;
    if (gradient) {
      // The kit's gradient: electric lime top right to green bottom left.
      paint.shader = const LinearGradient(
        begin: Alignment(0.7, -0.9),
        end: Alignment(-0.7, 0.9),
        colors: <Color>[FitBrand.limeHi, FitBrand.lime, FitBrand.green],
        stops: <double>[0, 0.45, 1],
      ).createShader(const Rect.fromLTWH(_x0, _y0, _w, _h));
    } else {
      paint.color = ink;
    }
    canvas
      ..drawPath(blades(), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(FitosMarkPainter old) =>
      old.gradient != gradient || old.ink != ink;
}

/// FITOS in the kit's geometric capitals: 40-unit cap height, stroke 8.5,
/// letter gap 13.
class FitosNamePainter extends CustomPainter {
  FitosNamePainter(this.color);

  final Color color;

  static const double _cap = 40;
  static const double _st = 8.5;
  static const double _gap = 13;
  static const double _width = 50 + 8.5 + 54 + 62 + 56 + 4 * _gap;
  static const double aspect = _width / _cap;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / _cap;
    canvas
      ..save()
      ..scale(s);
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    final solid = Path();
    var x = 0.0;
    // F
    solid
      ..addRect(Rect.fromLTWH(x, 0, _st, _cap))
      ..addRect(Rect.fromLTWH(x, 0, 50, _st))
      ..addRect(Rect.fromLTWH(x, _cap / 2 - _st / 2 + 1, 50 * 0.78, _st));
    x += 50 + _gap;
    // I
    solid.addRect(Rect.fromLTWH(x, 0, _st, _cap));
    x += _st + _gap;
    // T
    solid
      ..addRect(Rect.fromLTWH(x, 0, 54, _st))
      ..addRect(Rect.fromLTWH(x + 27 - _st / 2, 0, _st, _cap));
    x += 54 + _gap;
    canvas.drawPath(solid, fill);
    // O: a rounded ring.
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, 62, _cap),
          const Radius.circular(13),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + _st, _st, 62 - 2 * _st, _cap - 2 * _st),
          const Radius.circular(13 - _st),
        ),
      );
    canvas.drawPath(ring, fill);
    x += 62 + _gap;
    // S: a stroked centre line.
    const w = 56.0;
    const r = (_cap / 2 + _st / 2) / 2;
    const o = _st / 2;
    const m = _cap / 2;
    final sPath = Path()
      ..moveTo(x + w, o)
      ..lineTo(x + r, o)
      ..arcToPoint(
        Offset(x + r, m),
        radius: const Radius.circular(r - o),
        clockwise: false,
      )
      ..lineTo(x + w - r, m)
      ..arcToPoint(
        Offset(x + w - r, _cap - o),
        radius: const Radius.circular(r - o),
      )
      ..lineTo(x, _cap - o);
    canvas
      ..drawPath(
        sPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _st
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(FitosNamePainter old) => old.color != color;
}
