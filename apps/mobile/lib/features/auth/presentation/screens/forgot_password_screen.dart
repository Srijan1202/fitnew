import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/navigation.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fitos_wordmark.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  Failure? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email: _email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Do not reveal whether the address exists: Firebase's "user-not-found"
      // becomes the same confirmation as success. Account enumeration is not
      // something a fitness app should make easy.
      _sent = failure == null ||
          (failure is Credential && failure.code == 'user-not-found');
      _failure = _sent ? null : failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading:
            BackButton(onPressed: _busy ? null : () => context.popOrHome()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.md,
          ),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const FitosWordmark(size: 22),
                const SizedBox(height: FitSpacing.xs),
                Text('Reset password', style: textTheme.displayMedium),
                const SizedBox(height: FitSpacing.sm),
                Text(
                  'Enter your email and we will send a link to choose a new one.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: FitSpacing.xl),
                AuthFormField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  validator: AuthValidators.email,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !_busy && !_sent,
                ),
                const SizedBox(height: FitSpacing.md),
                if (_sent)
                  const AuthFeedback.success(
                    'If an account exists for that email, a reset link is on its way.',
                  )
                else if (_failure != null)
                  AuthFeedback.error(_failure!.message),
                const SizedBox(height: FitSpacing.xl),
                FilledButton(
                  onPressed: _busy || _sent ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FitColors.paper,
                          ),
                        )
                      : Text(_sent ? 'Sent' : 'Send reset link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
