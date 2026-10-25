import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_draft.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Email/password and phone/OTP sign-in forms with a "continue offline"
/// link. Errors are shown inline; the page above reacts to the auth state.
class SignInForm extends ConsumerStatefulWidget {
  /// Creates the form. [onContinueOffline] null hides the link.
  const SignInForm({super.key, this.onContinueOffline});

  /// Skips sign-in on a fresh install.
  final VoidCallback? onContinueOffline;

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

enum _Method { email, phone }

class _SignInFormState extends ConsumerState<SignInForm> {
  static const Logger _log = Logger('sign-in');

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  _Method _method = _Method.email;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      _log.info('auth refused (${e.statusCode ?? '-'})');
      if (mounted) setState(() => _error = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e, st) {
      _log.error('sign-in failed: ${e.runtimeType}', stackTrace: st);
      if (mounted) setState(() => _error = context.strings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_form.currentState!.validate()) return;
    await _run(
      () => ref
          .read(cloudAuthProvider.notifier)
          .signInWithPassword(email: _email.text, password: _password.text),
    );
  }

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    await _run(
      () => ref.read(cloudAuthProvider.notifier).sendPhoneOtp(_phone.text),
    );
  }

  Future<void> _verifyCode() async {
    if (_code.text.trim().length < 4) {
      setState(() => _error = 'Enter the code from the SMS');
      return;
    }
    await _run(
      () => ref.read(cloudAuthProvider.notifier).verifyPhoneOtp(_code.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final pendingPhone = ref.watch(
      cloudAuthProvider.select((a) => a.pendingOtpPhone),
    );
    return Form(
      key: _form,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Your account links this phone to the clinic on the server so '
            'records sync and WhatsApp messages are sent for you.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<_Method>(
            segments: const [
              ButtonSegment(
                value: _Method.email,
                label: Text('Email'),
                icon: Icon(Icons.alternate_email),
              ),
              ButtonSegment(
                value: _Method.phone,
                label: Text('Phone'),
                icon: Icon(Icons.sms_outlined),
              ),
            ],
            selected: {_method},
            onSelectionChanged: _busy
                ? null
                : (v) => setState(() {
                    _method = v.first;
                    _error = null;
                  }),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_method == _Method.email) ...[
            TextFormField(
              key: const ValueKey('sign-in-email'),
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Enter your email',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('sign-in-password'),
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (v) =>
                  (v ?? '').isNotEmpty ? null : 'Enter your password',
              onFieldSubmitted: (_) => _submitEmail(),
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('sign-in-submit'),
              label: 'Sign in',
              icon: Icons.login,
              loading: _busy,
              onPressed: _busy ? null : _submitEmail,
            ),
          ] else if (pendingPhone == null) ...[
            TextFormField(
              key: const ValueKey('sign-in-phone'),
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91 ',
              ),
              keyboardType: TextInputType.phone,
              validator: OnboardingValidators.indianMobile,
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('sign-in-send-code'),
              label: 'Send code',
              icon: Icons.sms_outlined,
              loading: _busy,
              onPressed: _busy ? null : _sendCode,
            ),
          ] else ...[
            Text(
              'Code sent to $pendingPhone',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('sign-in-code'),
              controller: _code,
              decoration: const InputDecoration(labelText: 'One-time code'),
              keyboardType: TextInputType.number,
              onFieldSubmitted: (_) => _verifyCode(),
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('sign-in-verify'),
              label: 'Verify',
              icon: Icons.check,
              loading: _busy,
              onPressed: _busy ? null : _verifyCode,
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(cloudAuthProvider.notifier).cancelOtp(),
              child: const Text('Use a different number'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              key: const ValueKey('sign-in-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (widget.onContinueOffline != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'No account yet? Set the clinic up on this phone now and sign '
              'in later from Settings > Account.',
              style: theme.textTheme.bodySmall,
            ),
            TextButton(
              key: const ValueKey('sign-in-continue-offline'),
              onPressed: _busy ? null : widget.onContinueOffline,
              child: Text(MobileStrings.continueOffline),
            ),
          ],
          Text(
            s.appName,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
