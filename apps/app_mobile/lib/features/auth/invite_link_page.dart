import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/member_invites.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Target of the `ampdent://app/invite/<code>` deep link (the share text of
/// Settings > Members > Invite to sign in). Records the code as the pending
/// invite and hands over to the sign-in page, whose code field is prefilled
/// from it; a phone that is already signed in runs the link check at once,
/// which claims the code first. A malformed code is ignored (the sign-in
/// page is shown without one, or the home tab when a clinic exists).
class InviteLinkPage extends ConsumerStatefulWidget {
  /// Creates the page for the raw path segment [code].
  const InviteLinkPage({super.key, required this.code});

  /// Code as it appeared in the link (any case, hyphen allowed).
  final String code;

  @override
  ConsumerState<InviteLinkPage> createState() => _InviteLinkPageState();
}

class _InviteLinkPageState extends ConsumerState<InviteLinkPage> {
  static const Logger _log = Logger('invite-link');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    if (!mounted) return;
    final wellFormed = InviteCodes.isWellFormed(widget.code);
    if (wellFormed) {
      ref.read(inviteClaimProvider.notifier).setPendingCode(widget.code);
      _log.info('invite link opened');
      if (ref.read(cloudAuthProvider).isSignedIn) {
        unawaited(ref.read(clinicLinkProvider.notifier).run());
      }
      context.go(signInLocation);
      return;
    }
    _log.warning('invite link ignored: malformed code');
    final hasClinic = ref.read(appSessionProvider).hasClinic;
    context.go(hasClinic ? homeLocation : signInLocation);
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
