// Phase 6.7 — used by tool/hosted.ps1 before a hosted build: exits 0 when the
// address may be a hosted API base URL, 1 (with the reason) when it may not.
// The rules live in lib/core/config/hosted_api_url.dart, shared with the app.
//
//   dart run tool/check_hosted_api_url.dart https://…run.app
import 'dart:io';

import 'package:fitos/core/config/hosted_api_url.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/check_hosted_api_url.dart <url>');
    exit(2);
  }
  final problem = hostedApiUrlProblem(args.single);
  if (problem == null) {
    stdout.writeln('ok');
    return;
  }
  stderr.writeln('API_BASE_URL $problem');
  exit(1);
}
