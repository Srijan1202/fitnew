import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fitos_wordmark.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_field.dart';

/// Email + Google sign-in (§11). Apple is out of V1 (ADR-003).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).signInWithEmail(
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.xl,
          ),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const FitosWordmark(size: 22),
                  const SizedBox(height: FitSpacing.xs),
                  Text('Sign in', style: textTheme.displayMedium),
                  const SizedBox(height: FitSpacing.xl),
                  AuthFormField(
                    fieldKey: const ValueKey('sign-in.email'),
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
                    fieldKey: const ValueKey('sign-in.password'),
                    label: 'Password',
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    validator: AuthValidators.password,
                    onFieldSubmitted: (_) => _submit(),
                    enabled: !busy,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () => context.push(Routes.forgotPassword),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (failure is Failure) ...<Widget>[
                    const SizedBox(height: FitSpacing.sm),
                    AuthFeedback.error(failure.message),
                  ],
                  const SizedBox(height: FitSpacing.lg),
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
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  const Divider(color: FitColors.rule, height: 1),
                  const SizedBox(height: FitSpacing.afterRule),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FitColors.ink,
                      side: const BorderSide(color: FitColors.ink),
                      minimumSize: const Size(88, 48),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(FitRadius.small),
                      ),
                    ),
                    child: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: FitSpacing.xl),
                  Row(
                    children: <Widget>[
                      Text('New here?', style: textTheme.bodyMedium),
                      TextButton(
                        onPressed:
                            busy ? null : () => context.push(Routes.signUp),
                        child: const Text('Create an account'),
                      ),
                    ],
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
