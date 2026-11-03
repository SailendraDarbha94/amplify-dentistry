import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'link_progress_view.dart';
import 'sign_in_form.dart';

/// Sign in (email and password, or phone and a one-time code) or continue
/// offline. Once signed in the page shows the clinic-link progress and then
/// leaves: back to where it was pushed from, else to the Today tab (clinic
/// linked or adopted) or to onboarding (nothing on the server yet).
class SignInPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  bool _left = false;

  void _leave({String? fallback}) {
    if (_left || !mounted) return;
    _left = true;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    final hasClinic = ref.read(appSessionProvider).hasClinic;
    router.go(fallback ?? (hasClinic ? homeLocation : onboardingLocation));
  }

  Future<void> _continueOffline() async {
    await ref.read(continueOfflineProvider.notifier).choose();
    _leave();
  }

  /// Signed in with no clinic anywhere (or the check failed): the user chose
  /// to set a clinic up on this phone. The choice lifts the sign-in gate for
  /// onboarding; it is never taken on the user's behalf.
  void _createClinic() {
    ref.read(createClinicChoiceProvider.notifier).choose();
    _leave(fallback: onboardingLocation);
  }

  void _onLink(ClinicLinkState? previous, ClinicLinkState next) {
    if (!ref.read(cloudAuthProvider).isSignedIn) return;
    switch (next.phase) {
      case LinkPhase.linked:
        // The session is activated before the phase flips, so the redirect
        // sees the clinic.
        _leave();
      case LinkPhase.unlinked:
        // Nothing on the server: a phone that already holds a clinic simply
        // goes back; an empty phone stays here and shows the choice (join
        // with an invite code or create a new clinic).
        if (ref.read(appSessionProvider).hasClinic) _leave();
      case LinkPhase.idle:
      case LinkPhase.checking:
      case LinkPhase.choosing:
      case LinkPhase.pulling:
      case LinkPhase.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clinicLinkProvider, _onLink);
    final configured = ref.watch(cloudActiveProvider);
    final auth = ref.watch(cloudAuthProvider);
    final hasClinic = ref.watch(appSessionProvider).hasClinic;
    final title = hasClinic ? 'Sign in' : MobileStrings.signInOrContinueOffline;
    final Widget body;
    if (!configured) {
      body = _NotConfigured(onContinue: _leave);
    } else if (auth.isSignedIn) {
      body = LinkProgressView(onCreateClinic: _createClinic);
    } else {
      body = SignInForm(onContinueOffline: hasClinic ? null : _continueOffline);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: hasClinic),
      body: SafeArea(child: body),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        SectionCard(
          title: MobileStrings.cloudNotConfigured,
          child: const Text(MobileStrings.cloudNotConfiguredHelp),
        ),
        const SizedBox(height: AppSpacing.lg),
        BigActionButton(
          key: const ValueKey('sign-in-continue-offline'),
          label: MobileStrings.continueOffline,
          icon: Icons.arrow_forward,
          onPressed: onContinue,
        ),
      ],
    );
  }
}
