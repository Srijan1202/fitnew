/// Phase 6.7 — the rules a HOSTED build's API address must meet.
///
/// A hosted build talks to FITOS on the internet (Cloud Run today,
/// `https://api.tryfitos.me` later), never to a PC on a LAN. So its address
/// must be HTTPS to a real DNS name on the default port. An `http://`, a
/// LAN IP, the emulator alias or a port would mean the build points somewhere
/// it must not, and Android would either refuse the cleartext or silently talk
/// to the wrong machine.
///
/// Pure Dart (no Flutter import): the app checks it at start-up, the build
/// script runs it through `tool/check_hosted_api_url.dart`, and
/// `android/app/build.gradle.kts` applies the same rules before a hosted APK
/// can be built. The LAN alpha profile is not subject to any of this.
library;

/// Why [url] cannot be a hosted API base URL, or null when it can.
String? hostedApiUrlProblem(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return 'is empty';
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return 'is not a URL';
  if (uri.scheme != 'https') {
    return 'must use https:// (got ${uri.scheme.isEmpty ? 'no scheme' : '${uri.scheme}://'})';
  }
  if (uri.userInfo.isNotEmpty) return 'must not contain credentials';
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return 'has no host';
  if (host.contains(':')) return 'must not be an IP address ($host)';
  if (host == 'localhost' || host.endsWith('.localhost')) {
    return 'must not be localhost';
  }
  // An explicit port — even :443 — means someone typed a LAN-style address.
  // Read from the text: Uri drops a port equal to the scheme's default.
  final afterScheme = trimmed.substring(trimmed.indexOf('://') + 3);
  final authority = afterScheme.split(RegExp('[/?#]')).first;
  if (uri.hasPort || authority.contains(':')) {
    return 'must not name a port (got :${authority.split(':').last})';
  }
  final labels = host.split('.');
  if (labels.length < 2 || labels.any((l) => l.isEmpty)) {
    return 'must be a DNS name such as fitos-api-alpha-….asia-south1.run.app';
  }
  // The last label of a real DNS name is letters; any IPv4 literal
  // (10.0.2.2, 127.0.0.1, 192.168.1.20, 0x7f.0.0.1) fails here.
  if (!RegExp(r'^[a-z]{2,63}$').hasMatch(labels.last)) {
    return 'must not be an IP address ($host)';
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    return 'must be the server root, without a path (got ${uri.path})';
  }
  if (uri.hasQuery || uri.hasFragment) {
    return 'must not have a query or fragment';
  }
  return null;
}
