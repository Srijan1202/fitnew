import 'package:firebase_core/firebase_core.dart';

import 'env.dart';

/// Firebase options assembled from `--dart-define` (see [Env]).
///
/// This replaces the `flutterfire configure` output on purpose: that file
/// hard-codes one project's ids into source, and we run three projects
/// (dev/staging/prod, §25) from one codebase. Android only in V1 (ADR-003).
abstract final class FirebaseConfig {
  static FirebaseOptions get android => const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
      );
}
