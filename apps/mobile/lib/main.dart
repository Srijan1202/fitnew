import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Riverpod is the only DI container (§7.1) — a second one would be redundant.
  runApp(const ProviderScope(child: FitOSApp()));
}
