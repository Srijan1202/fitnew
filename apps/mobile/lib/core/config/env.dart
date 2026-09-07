/// Build-time configuration.
///
/// The app holds the Firebase config and an API base URL and nothing else
/// (§24): no API keys, no service accounts. Values come from `--dart-define`
/// so they are per-flavour rather than compiled-in constants.
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'local',
  );
}
