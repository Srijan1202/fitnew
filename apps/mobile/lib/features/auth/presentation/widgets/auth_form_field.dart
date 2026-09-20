import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// A text field in the §6 language: hairline underline, no filled box, label
/// as an eyebrow above. Errors render in oxide beneath, never as a red border
/// around the whole field.
class AuthFormField extends StatelessWidget {
  const AuthFormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.fieldKey,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final bool enabled;

  /// Key on the inner [TextFormField], so tests can target one field without
  /// ambiguity.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.xs),
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          enabled: enabled,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: textTheme.bodyLarge,
          cursorColor: FitColors.ink,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: FitColors.rule),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: FitColors.ink, width: 1.5),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: FitColors.oxide),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: FitColors.oxide, width: 1.5),
            ),
            errorStyle: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
          ),
        ),
      ],
    );
  }
}

/// A single line of feedback beneath a form. Oxide for failures, pine for
/// confirmations. States what happened and what to do (§6.6), no more.
class AuthFeedback extends StatelessWidget {
  const AuthFeedback.error(this.text, {super.key}) : _color = FitColors.oxide;
  const AuthFeedback.success(this.text, {super.key}) : _color = FitColors.pine;

  final String text;
  final Color _color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _color),
      ),
    );
  }
}

/// Email and password rules. Mirrors the server (§7.3 permits form
/// validation that mirrors server validation); Firebase remains authoritative.
abstract final class AuthValidators {
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email.';
    if (!v.contains('@') || v.startsWith('@') || v.endsWith('@')) {
      return 'That email address does not look right.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password.';
    if (v.length < 8) return 'At least 8 characters.';
    return null;
  }
}
