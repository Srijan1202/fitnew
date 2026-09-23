import 'hosted_api_url.dart';

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

  /// `local` (emulator, developer PC), `alpha` (a physical phone on the
  /// owner's Wi-Fi against the PC's Docker API — Phase 6.6 Gate 6; built by
  /// `tool/alpha.ps1` / `tool/alpha.sh` from the gitignored `alpha.env`) or
  /// `hosted` (the internet API on Cloud Run over HTTPS — Phase 6.7; built by
  /// `tool/hosted.ps1` from the gitignored `hosted.env`).
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'local',
  );

  static bool get isAlpha => flavor == 'alpha';
  static bool get isHosted => flavor == 'hosted';

  /// The sign-in screen names the backend a build talks to on real phones:
  /// the LAN alpha (its address changes with the Wi-Fi) and hosted builds.
  static bool get showsBackend => showsBackendFor(flavor);
  static bool showsBackendFor(String flavor) =>
      flavor == 'alpha' || flavor == 'hosted';

  /// Why this build's API address cannot be used, or null. Only a hosted
  /// build is checked (HTTPS, a DNS name, no port); the LAN alpha and local
  /// profiles keep their `http://<LAN IP>:8080` / emulator addresses.
  static String? get configurationProblem =>
      configurationProblemFor(flavor: flavor, apiBaseUrl: apiBaseUrl);
  static String? configurationProblemFor({
    required String flavor,
    required String apiBaseUrl,
  }) {
    if (flavor != 'hosted') return null;
    final problem = hostedApiUrlProblem(apiBaseUrl);
    return problem == null ? null : 'API_BASE_URL $problem';
  }

  /// The API host as the phone sees it, for the build line in Profile.
  static String get apiHost => Uri.tryParse(apiBaseUrl)?.host ?? apiBaseUrl;

  /// `host:port` of the API, as the sign-in screen shows it in alpha builds.
  /// The address is compiled in by `--dart-define`, so it is the fastest way
  /// to see that a build predates a change of the server's LAN address.
  static String get apiAuthority {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) return apiBaseUrl;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  /// Shown in Profile so a tester can tell which build and backend this is.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0-alpha.1',
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

  /// The build can start: Firebase is configured and the API address is
  /// allowed for this flavour. Otherwise the splash screen says why and the
  /// app goes no further (Firebase is not even initialised).
  static bool get ready => firebaseConfigured && configurationProblem == null;
}
