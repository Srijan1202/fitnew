import 'dart:math' as math;
import 'dart:ui' show Brightness, Color;

import 'package:fitos/core/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2 contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final x = lum(a), y = lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Beta 5.3 (owner): Cobalt and Cobalt Light are the defaults, Violet and
/// Violet Light premium. Text and the actions' labels must read (AA, 4.5:1).
void main() {
  const themes = [
    FitPalette.cobalt,
    FitPalette.cobaltLight,
    FitPalette.violet,
    FitPalette.violetLight,
  ];

  for (final p in themes) {
    test('${p.label}: text and button labels pass AA', () {
      expect(contrast(p.ink, p.paper), greaterThanOrEqualTo(7), reason: 'ink');
      expect(
        contrast(p.ink60, p.paper),
        greaterThanOrEqualTo(4.5),
        reason: 'ink60',
      );
      expect(
        contrast(p.ink60, p.paper2),
        greaterThanOrEqualTo(4.5),
        reason: 'ink60 on blocks',
      );
      expect(
        contrast(p.onAccent, p.accent),
        greaterThanOrEqualTo(4.5),
        reason: 'buttons',
      );
    });
  }

  test('Automatic is Cobalt in dark mode and Cobalt Light in light mode', () {
    expect(FitPalette.forMode(Brightness.dark), FitPalette.cobalt);
    expect(FitPalette.forMode(Brightness.light), FitPalette.cobaltLight);
    expect(FitPalette.cobalt.mark, FitBrand.cobaltMark);
    expect(FitPalette.violetLight.mark, FitBrand.violetMark);
    expect(FitPalette.dark.mark, isNull);
  });
}
