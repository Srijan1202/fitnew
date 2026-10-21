import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/privacy/data/privacy_api.dart';
import 'package:fitos/features/privacy/domain/privacy.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';

/// A scripted privacy server (Phase 17): consents as set, an export body,
/// a delete that answers as scripted; every call recorded.
class FakePrivacyApi implements PrivacyApi {
  FakePrivacyApi({this.aiGranted = true, this.needsReconsent = false});

  bool aiGranted;
  bool needsReconsent;
  String exportBody = '{"format":"fitos-export","version":1,"tables":{}}';
  Failure? exportFailure;
  Failure? deleteFailure;
  final calls = <String>[];

  Consents _consents() => Consents(
        currentPolicyVersion: '2026-10-22',
        needsReconsent: needsReconsent,
        items: [
          for (final t in ConsentType.values)
            ConsentState(
              type: t.wire,
              granted: t == ConsentType.aiProcessing ? aiGranted : true,
              policyVersion: '2026-10-22',
              at: DateTime.utc(2026, 10, 22),
              required: ConsentType.required.contains(t),
            ),
        ],
      );

  @override
  Future<Result<Consents>> consents() async {
    calls.add('consents');
    return Ok(_consents());
  }

  @override
  Future<Result<Consents>> setConsent(
    ConsentType type, {
    required bool granted,
  }) async {
    calls.add('set ${type.wire} $granted');
    if (type == ConsentType.aiProcessing) aiGranted = granted;
    if (ConsentType.required.contains(type) && granted) needsReconsent = false;
    return Ok(_consents());
  }

  @override
  Future<Result<String>> exportJson() async {
    calls.add('export');
    final f = exportFailure;
    return f == null ? Ok(exportBody) : Err(f);
  }

  @override
  Future<Result<bool>> deleteAccount() async {
    calls.add('delete');
    final f = deleteFailure;
    return f == null ? const Ok(true) : Err(f);
  }
}
