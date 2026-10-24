import 'package:flutter/widgets.dart';

/// Below this speed (logical pixels a second) a list that is still settling
/// after a fling lets taps through to what is under the finger.
const double kTapThroughBelow = 400;

/// Beta 3.6 (owner: "+ Add set sometimes needs two taps"). Flutter ignores
/// taps on a list's children until a fling has fully stopped, and the end of
/// a fling can crawl on for a second while barely moving: the first tap only
/// stops it. With this controller, once the list moves slower than
/// [kTapThroughBelow], a tap reaches the button (and still stops the list).
class TapThroughScrollController extends ScrollController {
  TapThroughScrollController({super.debugLabel});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) =>
      _TapThroughPosition(
        physics: physics,
        context: context,
        initialPixels: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );
}

class _TapThroughPosition extends ScrollPositionWithSingleContext {
  _TapThroughPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  /// Taps were let through during the current fling.
  bool _lifted = false;

  @override
  void beginActivity(ScrollActivity? newActivity) {
    _lifted = false;
    super.beginActivity(newActivity);
  }

  @override
  double setPixels(double newPixels) {
    final overscroll = super.setPixels(newPixels);
    final a = activity;
    if (!_lifted &&
        a is BallisticScrollActivity &&
        a.velocity.abs() < kTapThroughBelow) {
      _lifted = true;
      context.setIgnorePointer(false);
    }
    return overscroll;
  }
}

/// A [ListView] that owns a [TapThroughScrollController], for stateless
/// screens. [listKey] goes on the list itself.
class TapThroughListView extends StatefulWidget {
  const TapThroughListView({
    required this.children,
    this.listKey,
    this.padding,
    super.key,
  });

  final List<Widget> children;
  final Key? listKey;
  final EdgeInsetsGeometry? padding;

  @override
  State<TapThroughListView> createState() => _TapThroughListViewState();
}

class _TapThroughListViewState extends State<TapThroughListView> {
  final _controller = TapThroughScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        key: widget.listKey,
        controller: _controller,
        padding: widget.padding,
        children: widget.children,
      );
}
