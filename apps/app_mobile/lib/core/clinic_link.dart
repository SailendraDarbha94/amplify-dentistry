/// Links this device to a clinic on the server after sign-in, following the
/// `RemoteClinicLinker` rules (packages/data/README.md, "Linking a device"):
///
/// * local clinic, no remote membership -> push the local clinic;
/// * remote membership(s), empty device -> adopt (full pull, skip onboarding);
/// * both present for the same clinic -> just record the link;
/// * both present for different clinics -> ask: keep local (sign out) or
///   replace the local store with the server clinic.
///
/// Afterwards the device is registered in `public.devices`, primary when the
/// data layer's `device.primary` setting names it.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'cloud_config.dart';
import 'local_store_wipe.dart';
import 'providers.dart';
import 'remote_devices.dart' show devicePlatformName;
import 'session.dart' show listLocalClinics;

/// Where the link flow is.
enum LinkPhase {
  /// Nothing running; signed out or not started.
  idle,

  /// Listing memberships and local clinics.
  checking,

  /// The user must pick a clinic or resolve a conflict.
  choosing,

  /// Adopting: the first full pull is running.
  pulling,

  /// Linked; the sync engine may run.
  linked,

  /// Signed in, no clinic anywhere yet: onboarding creates one.
  unlinked,

  /// Something failed; [ClinicLinkState.error] says what.
  failed,
}

/// Link flow state for the sign-in and account pages.
@immutable
class ClinicLinkState {
  /// Creates a state.
  const ClinicLinkState({
    this.phase = LinkPhase.idle,
    this.memberships = const [],
    this.hasLocalClinic = false,
    this.link,
    this.error,
    this.pulledRows = 0,
  });

  /// Current phase.
  final LinkPhase phase;

  /// The signed-in user's clinics on the server (for the chooser).
  final List<RemoteMembership> memberships;

  /// Whether the device holds a clinic that is not among [memberships].
  final bool hasLocalClinic;

  /// The recorded link, once [phase] is [LinkPhase.linked].
  final ClinicLink? link;

  /// Error text (error class and table, never row contents).
  final String? error;

  /// Rows applied by the adopt pull, for the progress copy.
  final int pulledRows;

  /// Whether a step is running.
  bool get isBusy => phase == LinkPhase.checking || phase == LinkPhase.pulling;

  /// Whether the device is linked to [clinicId].
  bool isLinkedTo(String clinicId) =>
      phase == LinkPhase.linked && link?.clinicId == clinicId;

  /// Returns a copy with the given fields replaced.
  ClinicLinkState copyWith({
    LinkPhase? phase,
    List<RemoteMembership>? memberships,
    bool? hasLocalClinic,
    ClinicLink? link,
    String? error,
    bool clearError = false,
    int? pulledRows,
  }) => ClinicLinkState(
    phase: phase ?? this.phase,
    memberships: memberships ?? this.memberships,
    hasLocalClinic: hasLocalClinic ?? this.hasLocalClinic,
    link: link ?? this.link,
    error: clearError ? null : (error ?? this.error),
    pulledRows: pulledRows ?? this.pulledRows,
  );
}

/// Builds the linker; tests may swap it.
typedef LinkerFactory = RemoteClinicLinker Function(
  SupabaseClient client,
  AppDatabase db,
);

/// Default linker factory.
final Provider<LinkerFactory> clinicLinkerFactoryProvider =
    Provider<LinkerFactory>(
      (ref) =>
          (client, db) => RemoteClinicLinker(client: client, db: db),
    );

/// Runs the link rules and keeps the result for the UI and the sync engine.
class ClinicLinkController extends Notifier<ClinicLinkState> {
  static const Logger _log = Logger('clinic-link');

  /// A link step may finish after the container is gone (a test ending, a
  /// sign-out mid-pull); writes after disposal are dropped.
  @override
  set state(ClinicLinkState value) {
    if (ref.mounted) super.state = value;
  }

  @override
  ClinicLinkState build() {
    ref.listen(cloudAuthProvider, (previous, next) {
      final was = previous?.isSignedIn ?? false;
      if (next.isSignedIn && !was) unawaited(run());
      if (!next.isSignedIn && was) state = const ClinicLinkState();
    });
    return const ClinicLinkState();
  }

  SupabaseClient? get _client => ref.read(cloudClientProvider);
  AppDatabase get _db => ref.read(databaseProvider);
  AuthUser? get _user => ref.read(cloudAuthProvider).user;
  ClinicRepository get _clinics => ref.read(clinicRepositoryProvider);

  RemoteClinicLinker _linker(SupabaseClient client) =>
      ref.read(clinicLinkerFactoryProvider)(client, _db);

  /// Runs [run] once when the app starts already signed in.
  Future<void> ensureStarted() async {
    if (state.phase == LinkPhase.idle && _user != null) await run();
  }

  /// Applies the rules from the current local and remote state.
  Future<void> run() async {
    final client = _client;
    final user = _user;
    if (client == null || user == null) {
      state = const ClinicLinkState();
      return;
    }
    state = state.copyWith(phase: LinkPhase.checking, clearError: true);
    try {
      final linker = _linker(client);
      final session = ref.read(appSessionProvider);
      final existing = await linker.currentLink();
      if (existing != null &&
          session.hasClinic &&
          existing.clinicId == session.clinicId) {
        await _finishLinked(client, existing, user);
        return;
      }
      final memberships = await linker.listMemberships(user.id);
      final local = await listLocalClinics(_db);
      if (local.isNotEmpty) {
        final clinic = local.first;
        final mine = memberships.where((m) => m.clinicId == clinic.id);
        if (memberships.isEmpty || mine.isNotEmpty) {
          await _pushLocal(client, linker, clinic.id, user);
          return;
        }
        state = state.copyWith(
          phase: LinkPhase.choosing,
          memberships: memberships,
          hasLocalClinic: true,
        );
        return;
      }
      if (memberships.isEmpty) {
        state = state.copyWith(
          phase: LinkPhase.unlinked,
          memberships: const [],
          hasLocalClinic: false,
        );
        return;
      }
      if (memberships.length == 1) {
        await adopt(memberships.single);
        return;
      }
      state = state.copyWith(
        phase: LinkPhase.choosing,
        memberships: memberships,
        hasLocalClinic: false,
      );
    } on Object catch (e, st) {
      _fail('link check', e, st);
    }
  }

  Future<void> _pushLocal(
    SupabaseClient client,
    RemoteClinicLinker linker,
    String clinicId,
    AuthUser user,
  ) async {
    final members = await _clinics.members(clinicId, includeInactive: true);
    final owner = members.where((m) => m.role == ClinicRole.ownerDentist);
    final ownerId = owner.isNotEmpty
        ? owner.first.id
        : ref.read(appSessionProvider).memberId;
    if (ownerId == null) throw StateError('no owner member on this device');
    final link = await linker.pushLocalClinic(
      localClinicId: clinicId,
      ownerMemberId: ownerId,
      userId: user.id,
    );
    await _finishLinked(client, link, user);
  }

  /// Second device: records [membership], pulls everything and activates the
  /// session with the remote clinic and member. The device must be empty.
  Future<void> adopt(RemoteMembership membership) async {
    final client = _client;
    final user = _user;
    if (client == null || user == null) return;
    state = state.copyWith(
      phase: LinkPhase.pulling,
      clearError: true,
      pulledRows: 0,
    );
    try {
      final linker = _linker(client);
      final link = await linker.adoptRemoteClinic(membership);
      final engine = SupabaseSyncEngine(
        client: client,
        db: _db,
        clinicId: membership.clinicId,
        accessTokenProvider: ref.read(accessTokenProvider),
      );
      try {
        await engine.pullSince(null);
        if (engine.current.status != SyncStatus.idle) {
          throw SyncFailure(
            SyncFailureKind.transient,
            engine.current.error ?? 'first pull did not complete',
          );
        }
        state = state.copyWith(pulledRows: engine.lastPullReport?.applied ?? 0);
      } finally {
        await engine.dispose();
      }
      if (await _clinics.getClinic(membership.clinicId) == null) {
        throw StateError('clinic row did not arrive in the first pull');
      }
      await ref
          .read(appSessionProvider.notifier)
          .activate(
            clinics: _clinics,
            clinicId: membership.clinicId,
            memberId: membership.memberId,
          );
      await _finishLinked(client, link, user);
    } on Object catch (e, st) {
      _fail('adopt', e, st);
    }
  }

  /// Conflict resolution: discard this device's unsynced local store and
  /// adopt [membership]. The caller must have confirmed with the user.
  Future<void> replaceLocalWith(RemoteMembership membership) async {
    state = state.copyWith(phase: LinkPhase.pulling, clearError: true);
    try {
      await wipeLocalStore(_db);
      ref.read(appSessionProvider.notifier).reset();
      _log.warning('local store wiped to adopt a server clinic');
    } on Object catch (e, st) {
      _fail('wipe', e, st);
      return;
    }
    await adopt(membership);
  }

  /// Conflict resolution: keep the local clinic and sign out.
  Future<void> keepLocalAndSignOut() async {
    await ref.read(cloudAuthProvider.notifier).signOut();
    state = const ClinicLinkState();
  }

  /// Called when onboarding has created a clinic while signed in.
  Future<void> afterOnboarding() async {
    if (_user != null) await run();
  }

  Future<void> _finishLinked(
    SupabaseClient client,
    ClinicLink link,
    AuthUser user,
  ) async {
    final syncState = DriftSyncStateRepository(_db);
    final session = ref.read(appSessionProvider);
    if (await syncState.read(SyncStateKeys.deviceId) == null) {
      await syncState.write(SyncStateKeys.deviceId, session.deviceId);
    }
    unawaited(ref.read(continueOfflineProvider.notifier).clear());
    state = state.copyWith(
      phase: LinkPhase.linked,
      link: link,
      memberships: const [],
      hasLocalClinic: false,
      clearError: true,
    );
    _log.info('linked (${link.mode.name})');
    await registerDevice(client, link.clinicId, user.id);
  }

  /// Upserts this device into `public.devices`; primary when the clinic's
  /// `device.primary` setting names it. Failures are logged, never thrown.
  Future<void> registerDevice(
    SupabaseClient client,
    String clinicId,
    String userId,
  ) async {
    final deviceId = ref.read(appSessionProvider).deviceId;
    String? primary;
    try {
      primary = await _clinics.primaryDeviceId(clinicId);
    } on Object catch (e) {
      // A malformed `device.primary` setting (for example a pulled jsonb
      // string stored without its quotes) must not block the link; the
      // device is then simply not primary.
      _log.warning('primary device setting unreadable: ${e.runtimeType}');
    }
    final row = <String, Object?>{
      'id': deviceId,
      'clinic_id': clinicId,
      'user_id': userId,
      'platform': devicePlatformName(),
      'app_version': appBuildVersion,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      'is_primary': primary == deviceId,
    };
    for (final claimPrimary in [row['is_primary'] == true, false]) {
      try {
        await client.from('devices').upsert({
          ...row,
          'is_primary': claimPrimary,
        }, onConflict: 'id');
        return;
      } on Object catch (e) {
        _log.warning(
          'device registration failed (${e.runtimeType}, '
          'primary=$claimPrimary)',
        );
        if (!claimPrimary) return;
      }
    }
  }

  void _fail(String step, Object e, StackTrace st) {
    final text = e is SyncFailure
        ? e.message
        : e is StateError
        ? e.message
        : e is PostgrestException
        ? 'PostgrestException ${e.code ?? ''}'.trim()
        : '${e.runtimeType}';
    _log.error('$step failed: $text', stackTrace: st);
    state = state.copyWith(phase: LinkPhase.failed, error: text);
  }
}

/// Link flow state and actions.
final NotifierProvider<ClinicLinkController, ClinicLinkState>
clinicLinkProvider = NotifierProvider<ClinicLinkController, ClinicLinkState>(
  ClinicLinkController.new,
);
