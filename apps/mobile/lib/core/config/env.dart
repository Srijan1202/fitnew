/// Build-time configuration.
///
/// The app holds the public Firebase config and an API base URL and nothing
/// else (§24): no API keys with write power, no service accounts. Values come
/// from `--dart-define` so they are per-flavour rather than compiled-in
/// constants, and so nothing project-specific lives in source.
///
/// Firebase's client config (apiKey, appId, sender id, project id) is public by
/// design — it identifies the project, it does not authorise anything. It is
/// still supplied at build time rather than committed, so a fork or a second
/// environment does not inherit the dev project.
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator -> host loopback
  );

  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'local',
  );

  // --- Firebase (public client config) -----------------------------------
  static const String firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// OAuth 2.0 *web* client id from the Firebase project. google_sign_in on
  /// Android needs it as `serverClientId` to mint an ID token Firebase will
  /// accept. Also public.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// True when every Firebase define is present. The gate screen uses this to
  /// show a real error instead of a crash when the app is run without them.
  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
