import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// One half of a [FitModeSwitch].
class FitModeHalf<T> {
  const FitModeHalf(this.value, this.label, this.icon, {required this.key});

  final T value;
  final String label;
  final IconData icon;

  /// On the half's label.
  final Key key;
}

/// Owner 2026-10-30: the thin segmented bar became a bold switch like the tab
/// bar: a 52 px track (the bar's canvas, edge and glow), the chosen half a
/// solid block in the accent, with the buttons' corners, that slides across.
/// Training's Gym | Running (beta 4.0); Progress | Recovery (beta 5.7, owner:
/// "same as we did in gym and running").
class FitModeSwitch<T> extends StatelessWidget {
  const FitModeSwitch({
    required this.value,
    required this.left,
    required this.right,
    required this.onChanged,
    required this.thumbKey,
    super.key,
  });

  final T value;
  final FitModeHalf<T> left;
  final FitModeHalf<T> right;
  final ValueChanged<T> onChanged;
  final Key thumbKey;

  static const _height = 52.0;
  static const _inset = 4.0;
  static const duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final glass = FitPalette.current.glass;
    // The chosen half has the app's button corners (FitRadius.small, owner
    // 2026-10-30: a full pill was too round); the track follows it out.
    final radius = FitRadius.small.x + _inset;
    return Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: FitColors.paper.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: FitColors.rule),
        boxShadow: glass
            ? <BoxShadow>[
                BoxShadow(
                  color: FitPalette.current.glow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            alignment: value == left.value
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                key: thumbKey,
                decoration: BoxDecoration(
                  color: FitColors.accent,
                  borderRadius: BorderRadius.circular(radius - _inset),
                ),
              ),
            ),
          ),
          // The full height of the track, so each label sits in its middle.
          Positioned.fill(
            child: Row(
              children: <Widget>[
                for (final half in [left, right])
                  _Segment(
                    label: half.label,
                    icon: half.icon,
                    on: value == half.value,
                    radius: radius - _inset,
                    onTap: () => onChanged(half.value),
                    textKey: half.key,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.on,
    required this.radius,
    required this.onTap,
    required this.textKey,
  });

  final String label;
  final IconData icon;
  final bool on;
  final double radius;
  final VoidCallback onTap;
  final Key textKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: on ? null : onTap,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: on ? FitColors.onAccent : FitColors.ink60,
              ),
              duration: FitModeSwitch.duration,
              builder: (_, colour, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 20, color: colour),
                  const SizedBox(width: FitSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      key: textKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style?.copyWith(
                        color: colour,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
