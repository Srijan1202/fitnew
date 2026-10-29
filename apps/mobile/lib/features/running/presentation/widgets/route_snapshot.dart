import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import 'run_map.dart';

/// Beta 4.1.1 (owner: "the path covered is disappointing on sharing"): the
/// share picture's map as a PNG, with the route drawn into it and the
/// picture framed on the route (RouteSnapshot.kt). maplibre_gl's own
/// snapshot left the route out and came out zoomed out.
abstract interface class RouteSnapshotter {
  /// Null when it cannot be made (offline, not Android): the share card then
  /// keeps FITOS's own drawn route.
  Future<Uint8List?> take(List<List<(double, double)>> segments);
}

class DeviceRouteSnapshotter implements RouteSnapshotter {
  const DeviceRouteSnapshotter();

  static const _channel = MethodChannel('fitos/device');

  @override
  Future<Uint8List?> take(List<List<(double, double)>> segments) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final dark = FitPalette.current.brightness == Brightness.dark;
    try {
      return await _channel.invokeMethod<Uint8List>('routeSnapshot', {
        'style': dark ? mapStyleDark : mapStyleLight,
        'segments': [
          for (final s in segments)
            [
              for (final p in s) [p.$1, p.$2],
            ],
        ],
        // 360 × 360 at 3× is a 1080 px picture with the map's labels at the
        // size they have on the phone.
        'size': 360,
        'pixelRatio': 3,
        'colour': mapLineColour(),
        'ring': dark ? '#0A0D0B' : '#FFFFFF',
      });
    } on Object {
      return null;
    }
  }
}

final routeSnapshotterProvider =
    Provider<RouteSnapshotter>((_) => const DeviceRouteSnapshotter());
