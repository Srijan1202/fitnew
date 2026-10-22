import 'package:fitos/features/home/presentation/widgets/home_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Home greeting shrinks to fit two lines instead of cutting a word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const base = TextStyle(fontSize: 56);
  const scaler = TextScaler.noScaling;

  test('a short greeting keeps the full display size', () {
    expect(HomeSections.greetingSize('Hi', base, 300, scaler), 56);
  });

  test('a long one steps down until every word fits and it takes two lines',
      () {
    // The test font is square: a glyph is as wide as the font is tall.
    final size =
        HomeSections.greetingSize('Good evening, Asha', base, 300, scaler);
    expect(size, lessThan(56));
    expect(size, greaterThanOrEqualTo(30));
    // "evening," (8 glyphs) must fit 300 on its own line.
    expect(8 * size, lessThanOrEqualTo(300));
  });

  test('nothing fits: the smallest size (then the ellipsis)', () {
    expect(
      HomeSections.greetingSize('Supercalifragilistic', base, 200, scaler),
      30,
    );
  });

  test('unbounded width or no style: the full size', () {
    expect(HomeSections.greetingSize('Hi', null, 300, scaler), 56);
    expect(
      HomeSections.greetingSize('Hi', base, double.infinity, scaler),
      56,
    );
  });
}
