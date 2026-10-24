import 'package:fitos/shared/widgets/tap_through_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 3.6 (owner: "+ Add set sometimes needs two taps"): right after a
/// fling, while the list still crawls, one tap must reach the button.
void main() {
  Future<int> tapWhileSettling(WidgetTester tester, ScrollController c) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: c,
            children: <Widget>[
              for (var i = 0; i < 60; i++)
                SizedBox(
                  height: 80,
                  child: TextButton(
                    key: ValueKey('b$i'),
                    onPressed: () => taps++,
                    child: Text('Add set $i'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, -400), 2500);
    // Wait for the slow end of the fling: still moving, but barely.
    var last = c.offset;
    for (var frame = 0; frame < 300; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final speed = (c.offset - last).abs() / 0.016;
      last = c.offset;
      if (speed > 0 && speed < 250) break;
    }
    expect(
      c.position.isScrollingNotifier.value,
      isTrue,
      reason: 'still settling',
    );
    // Tap the middle of the screen, whatever button is there now.
    await tester.tapAt(tester.getCenter(find.byType(ListView)));
    await tester.pumpAndSettle();
    return taps;
  }

  testWidgets('a plain list loses the tap while it settles (the bug)',
      (tester) async {
    expect(await tapWhileSettling(tester, ScrollController()), 0);
  });

  testWidgets('the tap-through list takes it the first time', (tester) async {
    final c = TapThroughScrollController();
    addTearDown(c.dispose);
    expect(await tapWhileSettling(tester, c), 1);
  });

  testWidgets('a fast fling still only stops on a tap (no accidental press)',
      (tester) async {
    var taps = 0;
    final c = TapThroughScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: c,
            children: <Widget>[
              for (var i = 0; i < 60; i++)
                SizedBox(
                  height: 80,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: Text('$i'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, -400), 4000);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(tester.getCenter(find.byType(ListView)));
    await tester.pumpAndSettle();
    expect(taps, 0);
  });
}
