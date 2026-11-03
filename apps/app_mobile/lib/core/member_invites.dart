/// Staff invite codes. The owner mints one per member row from Settings >
/// Members (`create_member_invite`, migration 0010); the staff member types
/// it on the sign-in page, or opens the `ampdent://app/invite/<code>` link
/// from the share text, and `claim_member_invite` binds their account to
/// that member row, after which the clinic-link rules adopt the clinic. The
/// owner can undo the binding (`unlink_member`, migration 0012) when a
/// phone or number is lost, so the member can be invited again. The code
/// is a capability: it is shown and shared, never logged or stored.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'cloud_config.dart';

/// Shape and normalisation of a code, shared with the sign-in form.
abstract final class InviteCodes {
  /// Characters in a code.
  static const int length = 8;

  /// Validity window the server applies.
  static const Duration validity = Duration(hours: 72);

  static final RegExp _wellFormed = RegExp(r'^[A-HJKMNP-Z2-9]{8}$');

  /// Upper case, spaces and hyphens removed (codes are read out over the
  /// phone and typed back as `ABCD-EFGH`).
  static String normalise(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// Whether [raw] normalises to eight characters of the server's alphabet.
  static bool isWellFormed(String raw) => _wellFormed.hasMatch(normalise(raw));

  /// `ABCD-EFGH` for display.
  static String display(String code) {
    final c = normalise(code);
    return c.length == length ? '${c.substring(0, 4)}-${c.substring(4)}' : c;
  }

  /// Validator for a text field; null when acceptable.
  static String? validate(String? value) {
    final v = value ?? '';
    if (v.trim().isEmpty) return 'Enter the invite code';
    return isWellFormed(v) ? null : 'A code is 8 letters or digits';
  }

  /// URL scheme the app registers on both platforms.
  static const String linkScheme = 'ampdent';

  /// Host of every app link; the platforms hand the app only the path, so
  /// the route is `/invite/<code>` whatever the host.
  static const String linkHost = 'app';

  /// Route prefix of an invite link (`/invite/<code>`).
  static const String linkPathPrefix = '/invite/';

  /// `ampdent://app/invite/<code>`: opens the app with the code prefilled.
  static Uri linkFor(String code) => Uri(
    scheme: linkScheme,
    host: linkHost,
    path: '$linkPathPrefix${normalise(code)}',
  );

  /// The normalised code carried by an invite link, or null when [uri] is
  /// not one (wrong scheme, other path, malformed code).
  static String? codeFromLink(Uri uri) {
    if (uri.scheme.isNotEmpty && uri.scheme != linkScheme) return null;
    final segments = uri.pathSegments;
    if (segments.length != 2 || segments.first != 'invite') return null;
    return isWellFormed(segments.last) ? normalise(segments.last) : null;
  }
}

/// A minted invite.
@immutable
class MemberInvite {
  /// Creates an invite.
  const MemberInvite({
    required this.code,
    required this.memberId,
    required this.clinicId,
    required this.expiresAt,
  });

  /// The eight-character code.
  final String code;

  /// Member row the code binds.
  final String memberId;

  /// Clinic the member belongs to.
  final String clinicId;

  /// When the code stops working (72 hours after minting).
  final DateTime expiresAt;

  /// `ABCD-EFGH`.
  String get displayCode => InviteCodes.display(code);

  /// `ampdent://app/invite/<code>`.
  Uri get link => InviteCodes.linkFor(code);

  /// Text for the share sheet: the code, the app link that prefills it, and
  /// the expiry; no clinical content.
  String shareText({required String clinicName, required String memberName}) =>
      '$memberName, you are invited to join $clinicName on AmpDent. '
      'Install the app, sign in with your own email or mobile number, tap '
      '"I have an invite code" and enter $displayCode, or open this link on '
      'the phone once the app is installed: $link . The code works until '
      '${expiresAt.toLocal()}.';
}

/// RPC wrapper over `create_member_invite` and `claim_member_invite`.
class MemberInviteService {
  /// Creates the service.
  MemberInviteService(this.client, {DateTime Function()? clock})
    : _clock = clock ?? _utcNow;

  static const Logger _log = Logger('member-invites');

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Supabase client (RPC and one select).
  final SupabaseClient client;

  final DateTime Function() _clock;

  /// Mints a code for [memberId] of [clinicId] (owner only). Throws
  /// [PostgrestException] when the server refuses.
  Future<MemberInvite> create({
    required String clinicId,
    required String memberId,
  }) async {
    final result = await client.rpc<Object?>(
      'create_member_invite',
      params: {'p_member': memberId},
    );
    final code = InviteCodes.normalise('$result');
    var expiresAt = _clock().add(InviteCodes.validity);
    try {
      final rows = await client
          .from('member_invites')
          .select('expires_at')
          .eq('code', code)
          .limit(1);
      if (rows.isNotEmpty) {
        expiresAt =
            DateTime.tryParse('${rows.first['expires_at']}')?.toUtc() ??
            expiresAt;
      }
    } on Object catch (e) {
      _log.debug('expiry lookup failed (${e.runtimeType}); using 72 h');
    }
    _log.info('invite minted for member');
    return MemberInvite(
      code: code,
      memberId: memberId,
      clinicId: clinicId,
      expiresAt: expiresAt,
    );
  }

  /// Redeems [code] for the signed-in user and returns the clinic id.
  /// Throws [PostgrestException] for an unknown, expired, used or
  /// mismatched code (its message is safe to show).
  Future<String> claim(String code) async {
    final result = await client.rpc<Object?>(
      'claim_member_invite',
      params: {'p_code': InviteCodes.normalise(code)},
    );
    _log.info('invite claimed');
    return '$result';
  }

  /// Clears the account bound to [memberId] (owner only; never the caller's
  /// own row), retiring any live code, so the member can be invited again
  /// after a lost phone or number. Throws [PostgrestException] when the
  /// server refuses (its message is safe to show).
  Future<void> unlink({required String memberId}) async {
    await client.rpc<Object?>('unlink_member', params: {'p_member': memberId});
    _log.info('member account unlinked');
  }
}

/// The service, or null without a client.
final Provider<MemberInviteService?> memberInviteServiceProvider =
    Provider<MemberInviteService?>((ref) {
      final client = ref.watch(cloudClientProvider);
      return client == null ? null : MemberInviteService(client);
    });

/// A code waiting to be claimed and the outcome of the last attempt.
@immutable
class InviteClaimState {
  /// Creates a state.
  const InviteClaimState({
    this.pendingCode,
    this.busy = false,
    this.error,
    this.claimedClinicId,
  });

  /// Normalised code to claim right after sign-in (or now, when signed in).
  final String? pendingCode;

  /// Whether a claim is in flight.
  final bool busy;

  /// Why the last claim failed (server message or error class).
  final String? error;

  /// Clinic id returned by the last successful claim.
  final String? claimedClinicId;

  /// Whether a code is waiting.
  bool get hasPendingCode => pendingCode != null;

  /// Returns a copy with the given fields replaced.
  InviteClaimState copyWith({
    String? pendingCode,
    bool clearPendingCode = false,
    bool? busy,
    String? error,
    bool clearError = false,
    String? claimedClinicId,
  }) => InviteClaimState(
    pendingCode: clearPendingCode ? null : (pendingCode ?? this.pendingCode),
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    claimedClinicId: claimedClinicId ?? this.claimedClinicId,
  );
}

/// Holds the invite code typed on the sign-in page and claims it. The
/// clinic-link controller calls [claimPending] at the start of every link
/// check, so a code typed before sign-in is redeemed as soon as the session
/// exists and the membership it creates is adopted by the normal rules.
class InviteClaimController extends Notifier<InviteClaimState> {
  static const Logger _log = Logger('invite-claim');

  /// A claim may finish after the container is gone; writes after disposal
  /// are dropped.
  @override
  set state(InviteClaimState value) {
    if (ref.mounted) super.state = value;
  }

  @override
  InviteClaimState build() => const InviteClaimState();

  /// Records (or clears, with null or blank) the code to claim.
  void setPendingCode(String? raw) {
    final code = raw == null ? '' : InviteCodes.normalise(raw);
    state = code.isEmpty
        ? state.copyWith(clearPendingCode: true, clearError: true)
        : state.copyWith(pendingCode: code, clearError: true);
  }

  /// Forgets the code and any error.
  void clear() => state = const InviteClaimState();

  /// Claims the pending code, if any, with [client]. Returns true when a
  /// code was redeemed. Never throws: a refusal lands in
  /// [InviteClaimState.error] and the code stays pending for correction.
  Future<bool> claimPending(SupabaseClient client) async {
    final code = state.pendingCode;
    if (code == null || state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final clinicId = await MemberInviteService(client).claim(code);
      state = state.copyWith(
        busy: false,
        clearPendingCode: true,
        claimedClinicId: clinicId,
      );
      return true;
    } on Object catch (e, st) {
      final text = e is PostgrestException
          ? e.message
          : e is AuthException
          ? e.message
          : 'Could not reach the server (${e.runtimeType})';
      _log.warning('invite claim refused: ${e.runtimeType}');
      _log.debug('$st');
      state = state.copyWith(busy: false, error: text);
      return false;
    }
  }
}

/// Invite claim state and actions.
final NotifierProvider<InviteClaimController, InviteClaimState>
inviteClaimProvider = NotifierProvider<InviteClaimController, InviteClaimState>(
  InviteClaimController.new,
);
