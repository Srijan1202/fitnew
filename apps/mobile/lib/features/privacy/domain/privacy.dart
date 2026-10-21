/// Wire shapes of `@fitos/contracts` privacy.ts (Phase 17, ADR-023).
/// Hand-written (ADR-004); the conformance test keeps them in step.
library;

import '../../profile/domain/entities/vocabulary.dart';

class ConsentState {
  const ConsentState({
    required this.type,
    required this.granted,
    required this.policyVersion,
    required this.at,
    required this.required,
  });

  factory ConsentState.fromJson(Map<String, dynamic> json) => ConsentState(
        type: json['type'] as String,
        granted: json['granted'] as bool,
        policyVersion: json['policyVersion'] as String?,
        at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
        required: json['required'] as bool,
      );

  /// A contracts consent type (wire text, so a future purpose still parses).
  final String type;
  final bool granted;
  final String? policyVersion;
  final DateTime? at;
  final bool required;

  ConsentType? get consentType => ConsentType.of(type);

  Map<String, dynamic> toJson() => {
        'type': type,
        'granted': granted,
        'policyVersion': policyVersion,
        'at': at?.toUtc().toIso8601String(),
        'required': required,
      };
}

class Consents {
  const Consents({
    required this.currentPolicyVersion,
    required this.needsReconsent,
    required this.items,
  });

  factory Consents.fromJson(Map<String, dynamic> json) => Consents(
        currentPolicyVersion: json['currentPolicyVersion'] as String,
        needsReconsent: json['needsReconsent'] as bool,
        items: [
          for (final i in json['items'] as List<dynamic>)
            ConsentState.fromJson(i as Map<String, dynamic>),
        ],
      );

  final String currentPolicyVersion;

  /// A required consent was given to an older policy version.
  final bool needsReconsent;
  final List<ConsentState> items;

  bool granted(ConsentType type) =>
      items.any((i) => i.type == type.wire && i.granted);

  Map<String, dynamic> toJson() => {
        'currentPolicyVersion': currentPolicyVersion,
        'needsReconsent': needsReconsent,
        'items': [for (final i in items) i.toJson()],
      };
}
