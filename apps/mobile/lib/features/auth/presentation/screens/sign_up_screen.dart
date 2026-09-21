import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/navigation.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _matches(String? value) =>
      value == _password.text ? null : 'Passwords do not match.';

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;
    final failure = auth.error;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: busy ? null : () => context.popOrHome()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.md,
          ),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('FITOS', style: textTheme.labelSmall),
                  const SizedBox(height: FitSpacing.xs),
                  Text('Create account', style: textTheme.displayMedium),
                  const SizedBox(height: FitSpacing.sm),
                  Text(
                    'Your password stays with Firebase. It never reaches our servers.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: FitSpacing.xl),
                  AuthFormField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.email,
                    enabled: !busy,
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  AuthFormField(
                    label: 'Password',
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.password,
                    enabled: !busy,
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  AuthFormField(
                    label: 'Confirm password',
                    controller: _confirm,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: _matches,
                    onFieldSubmitted: (_) => _submit(),
                    enabled: !busy,
                  ),
                  if (failure is Failure) ...<Widget>[
                    const SizedBox(height: FitSpacing.md),
                    AuthFeedback.error(failure.message),
                  ],
                  const SizedBox(height: FitSpacing.xl),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FitColors.paper,
                            ),
                          )
                        : const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
