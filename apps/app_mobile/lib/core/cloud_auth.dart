/// Supabase Auth on the phone: who is signed in, sign-in and sign-out, the
/// access token the sync engine needs, and the "continue offline" choice a
/// fresh install can make instead of signing in.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart' show PhoneNumbers;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'providers.dart';

/// The signed-in user, reduced to what the app shows and stores.
@immutable
class AuthUser {
  /// Creates a user.
  const AuthUser({required this.id, this.email, this.phone});

  /// Supabase `auth.users.id`.
  final String id;

  /// Email, when the account has one.
  final String? email;

  /// Phone (E.164 without `+` as Supabase reports it), when present.
  final String? phone;

  /// Email, else phone, else the id.
  String get label {
    final e = email;
    if (e != null && e.isNotEmpty) return e;
    final p = phone;
    if (p != null && p.isNotEmpty) return p.startsWith('+') ? p : '+$p';
    return id;
  }

  /// From a Supabase [User].
  factory AuthUser.fromSupabase(User user) =>
      AuthUser(id: user.id, email: user.email, phone: user.phone);
}

/// Auth state for the UI.
@immutable
class CloudAuthState {
  /// Creates a state.
  const CloudAuthState({this.user, this.pendingOtpPhone});

  /// The signed-in user, or null.
  final AuthUser? user;

  /// Phone a one-time code was sent to and not yet verified.
  final String? pendingOtpPhone;

  /// Whether someone is signed in.
  bool get isSignedIn => user != null;

  /// Returns a copy with the given fields replaced.
  CloudAuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    String? pendingOtpPhone,
    bool clearPendingOtp = false,
  }) => CloudAuthState(
    user: clearUser ? null : (user ?? this.user),
    pendingOtpPhone: clearPendingOtp
        ? null
        : (pendingOtpPhone ?? this.pendingOtpPhone),
  );
}

/// Mirrors the Supabase session into [CloudAuthState] and exposes the
/// sign-in flows. Everything is a no-op when the cloud is not configured.
class CloudAuthController extends Notifier<CloudAuthState> {
  static const Logger _log = Logger('auth');

  @override
  CloudAuthState build() {
    final client = ref.watch(cloudClientProvider);
    if (client == null) return const CloudAuthState();
    final sub = client.auth.onAuthStateChange.listen(
      (change) => _apply(change.session),
      onError: (Object e) => _log.warning('auth stream: ${e.runtimeType}'),
    );
    ref.onDispose(sub.cancel);
    final current = client.auth.currentSession;
    return CloudAuthState(
      user: current == null ? null : AuthUser.fromSupabase(current.user),
    );
  }

  /// Mirrors [session] into the state right away; the auth stream repeats
  /// it a moment later, which changes nothing.
  void _apply(Session? session) {
    if (!ref.mounted) return;
    state = session == null
        ? state.copyWith(clearUser: true)
        : state.copyWith(
            user: AuthUser.fromSupabase(session.user),
            clearPendingOtp: true,
          );
  }

  SupabaseClient get _client {
    final client = ref.read(cloudClientProvider);
    if (client == null) throw StateError('Cloud not configured');
    return client;
  }

  /// Email and password sign-in. Throws [AuthException] on failure.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    _apply(response.session);
    _log.info('signed in with password');
  }

  /// Sends a one-time code to [phone] (any Indian form; normalised to
  /// E.164). Throws [FormatException] for a bad number, [AuthException] when
  /// the server refuses.
  Future<void> sendPhoneOtp(String phone) async {
    final e164 = PhoneNumbers.normaliseIndian(phone);
    await _client.auth.signInWithOtp(phone: e164);
    state = state.copyWith(pendingOtpPhone: e164);
    _log.info('otp sent');
  }

  /// Verifies the code sent by [sendPhoneOtp]. Throws [AuthException].
  Future<void> verifyPhoneOtp(String code) async {
    final phone = state.pendingOtpPhone;
    if (phone == null) throw StateError('No code was requested');
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: code.trim(),
      type: OtpType.sms,
    );
    _apply(response.session);
    _log.info('otp verified');
  }

  /// Forgets a pending code request.
  void cancelOtp() => state = state.copyWith(clearPendingOtp: true);

  /// Signs out on this device only. Local data is kept.
  Future<void> signOut() async {
    final client = ref.read(cloudClientProvider);
    if (client == null) return;
    await client.auth.signOut();
    state = const CloudAuthState();
    _log.info('signed out');
  }
}

/// Auth state and actions.
final NotifierProvider<CloudAuthController, CloudAuthState> cloudAuthProvider =
    NotifierProvider<CloudAuthController, CloudAuthState>(
      CloudAuthController.new,
    );

/// Token supplier for the sync engine and scheduler; null when signed out
/// or unconfigured.
final Provider<AccessTokenProvider> accessTokenProvider =
    Provider<AccessTokenProvider>((ref) {
      final client = ref.watch(cloudClientProvider);
      return () async => client?.auth.currentSession?.accessToken;
    });

/// `sync_state` key under which the "continue offline" choice is kept.
const String continueOfflineKey = 'app.continue_offline';

/// Reads the persisted choice; `main` passes it to
/// [initialContinueOfflineProvider].
Future<bool> readContinueOffline(AppDatabase db) async =>
    await DriftSyncStateRepository(db).read(continueOfflineKey) == '1';

/// Choice resolved before the widget tree is built (false by default).
final Provider<bool> initialContinueOfflineProvider = Provider<bool>(
  (ref) => false,
);

/// Whether the user chose to run without an account on this install.
class ContinueOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(initialContinueOfflineProvider);

  /// Records the choice.
  Future<void> choose() async {
    state = true;
    await DriftSyncStateRepository(ref.read(databaseProvider))
        .write(continueOfflineKey, '1');
  }

  /// Clears it (the user signed in after all).
  Future<void> clear() async {
    state = false;
    await DriftSyncStateRepository(ref.read(databaseProvider))
        .write(continueOfflineKey, null);
  }
}

/// The "continue offline" choice.
final NotifierProvider<ContinueOfflineNotifier, bool> continueOfflineProvider =
    NotifierProvider<ContinueOfflineNotifier, bool>(
      ContinueOfflineNotifier.new,
    );

/// Whether a fresh install must pass the sign-in page first: the cloud is
/// configured, nobody is signed in, no clinic exists yet and the user has
/// not chosen to continue offline.
final Provider<bool> signInGateProvider = Provider<bool>((ref) {
  if (!ref.watch(cloudActiveProvider)) return false;
  if (ref.watch(cloudAuthProvider.select((s) => s.isSignedIn))) return false;
  if (ref.watch(continueOfflineProvider)) return false;
  return !ref.watch(appSessionProvider.select((s) => s.hasClinic));
});
