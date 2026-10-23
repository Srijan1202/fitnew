import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../notifications/presentation/notification_coordinator.dart';
import '../../profile/domain/entities/vocabulary.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../data/privacy_api.dart';
import '../domain/privacy.dart';
import 'ai_consent_sheet.dart';
import '../../progress/presentation/photos/progress_photos_providers.dart';

final privacyApiProvider =
    Provider<PrivacyApi>((ref) => DioPrivacyApi(ref.watch(dioProvider)));

/// My consents (Phase 17). Refetched after every change.
final consentsProvider = FutureProvider<Consents>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(privacyApiProvider).consents();
    return r.when(ok: (c) => c, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Phase 17 (ADR-023 D1): before FITOS AI is used, the user's
/// `ai-processing` consent. Asked once, with what is sent and to whom;
/// true when it is given (now or before). When it cannot be checked
/// (offline), the server decides.
Future<bool> ensureAiConsent(BuildContext context, WidgetRef ref) async {
  final Consents consents;
  try {
    consents = await ref.read(consentsProvider.future);
  } on Object {
    return true;
  }
  if (consents.granted(ConsentType.aiProcessing)) return true;
  if (!context.mounted) return false;
  final yes = await showAiConsentSheet(context);
  if (yes != true) return false;
  final r = await ref
      .read(privacyApiProvider)
      .setConsent(ConsentType.aiProcessing, granted: true);
  ref.invalidate(consentsProvider);
  return r is Ok;
}

/// Hands the export file to the system share sheet (save to Files, Drive…).
abstract class ExportSharer {
  Future<void> share(String json, String fileName);
}

class SystemExportSharer implements ExportSharer {
  @override
  Future<void> share(String json, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'My FITOS data',
      ),
    );
  }
}

final exportSharerProvider =
    Provider<ExportSharer>((_) => SystemExportSharer());

/// After the server deleted the account: nothing of it stays on the phone —
/// reminders cancelled, the local database and preferences wiped — then
/// signed out (the sign-in itself is gone server-side).
class AccountEraser {
  AccountEraser(this._ref);

  final Ref _ref;

  Future<void> eraseLocal() async {
    await _ref.read(notificationCoordinatorProvider.notifier).forgetAll();
    // Beta 3.4 (ADR-035): this account's progress photos on this phone.
    final account = _ref.read(sessionUserIdProvider);
    if (account != null) {
      try {
        await _ref.read(accountPhotoEraserProvider)(account);
      } on Object {
        // Nothing more to delete.
      }
    }
    await _ref.read(appDatabaseProvider).clearAll();
    try {
      await (await SharedPreferences.getInstance()).clear();
    } on Object {
      // Nothing more to wipe.
    }
    await _ref.read(authControllerProvider.notifier).signOut();
  }
}

final accountEraserProvider = Provider<AccountEraser>(AccountEraser.new);
