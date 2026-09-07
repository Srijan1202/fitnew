import 'package:flutter/material.dart';

import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';

/// Root widget. Owns the router and the theme, nothing else.
class FitOSApp extends StatefulWidget {
  const FitOSApp({super.key});

  @override
  State<FitOSApp> createState() => _FitOSAppState();
}

class _FitOSAppState extends State<FitOSApp> {
  late final router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FitOS',
      debugShowCheckedModeBanner: false,
      theme: FitTheme.build(),
      routerConfig: router,
      builder: (context, child) {
        // Text scaling is supported to 200% (§6.8). Large metrics cap their
        // scale factor so they never truncate; body text scales freely.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 2.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
