/// Links this device to a clinic on the server before the first sync.
///
/// Rules (documented in packages/data/README.md, "Linking a device"):
/// 1. The signed-in user's memberships are listed from `clinic_members`
///    (`user_id = auth user`, active).
/// 2. First device: the user has no membership and the device holds a local
///    clinic. [pushLocalClinic] inserts the clinic (RLS stamps `created_by`)
///    and the owner member with `user_id` set, which is the only insert the
///    bootstrap policy allows; then the outbox drains normally.
/// 3. Second device: the user already belongs to a clinic and the device
///    holds no clinic data. [adoptRemoteClinic] records the remote clinic and
///    member ids; the app builds its `ActorContext` from them and runs a full
///    pull. Adopting with local data present is refused.
/// 4. A device whose local clinic differs from the user's membership cannot
///    be merged automatically; the app must ask (keep local and sign in with
///    the clinic's account, or wipe and adopt).
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';
import 'package:supabase/supabase.dart';

import '../db/app_database.dart';
import 'row_codec.dart';
import 'sync_errors.dart';
import 'sync_state_repository.dart';
import 'sync_tables.dart';

/// One row of `clinic_members` for the signed-in user.
class RemoteMembership {
  /// Creates a membership.
  const RemoteMembership({
    required this.clinicId,
    required this.memberId,
    required this.role,
    required this.displayName,
  });

  /// Clinic id.
  final String clinicId;

  /// `clinic_members.id` of the user in that clinic (the local actor id).
  final String memberId;

  /// `ClinicRole.name`.
  final String role;

  /// Member display name.
  final String displayName;

  /// Parses a PostgREST row.
  factory RemoteMembership.fromJson(Map<String, Object?> json) =>
      RemoteMembership(
        clinicId: '${json['clinic_id']}',
        memberId: '${json['id']}',
        role: '${json['role']}',
        displayName: '${json['display_name'] ?? ''}',
      );
}

/// How a device got linked.
enum ClinicLinkMode {
  /// This device created the clinic on the server.
  pushedLocal,

  /// This device adopted a clinic that already existed on the server.
  adoptedRemote,
}

/// The recorded link.
class ClinicLink {
  /// Creates a link.
  const ClinicLink({
    required this.clinicId,
    required this.memberId,
    required this.mode,
    required this.linkedAt,
  });

  /// Clinic replicated by this device.
  final String clinicId;

  /// Member id of the signed-in user (the app's actor id).
  final String memberId;

  /// How the link was made.
  final ClinicLinkMode mode;

  /// When.
  final DateTime linkedAt;
}

/// Lists memberships and records the clinic link.
class RemoteClinicLinker {
  /// Creates the linker.
  RemoteClinicLinker({
    required this.client,
    required this.db,
    SyncStateRepository? syncState,
  }) : syncState = syncState ?? DriftSyncStateRepository(db);

  static const Logger _log = Logger('RemoteClinicLinker');

  /// Supabase client (REST only).
  final SupabaseClient client;

  /// Local database.
  final AppDatabase db;

  /// Link store.
  final SyncStateRepository syncState;

  /// Active memberships of [userId].
  Future<List<RemoteMembership>> listMemberships(String userId) async {
    try {
      final rows = await client
          .from('clinic_members')
          .select('id,clinic_id,role,display_name')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          RemoteMembership.fromJson(r.cast<String, Object?>()),
      ];
    } catch (e) {
      throw classifySyncError(e, table: 'clinic_members');
    }
  }

  /// The link recorded on this device, or null.
  Future<ClinicLink?> currentLink() async {
    final clinicId = await syncState.read(SyncStateKeys.linkedClinicId);
    if (clinicId == null) return null;
    final mode = await syncState.read(SyncStateKeys.linkMode);
    return ClinicLink(
      clinicId: clinicId,
      memberId: await syncState.read(SyncStateKeys.linkedMemberId) ?? '',
      mode: ClinicLinkMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ClinicLinkMode.pushedLocal,
      ),
      linkedAt:
          await syncState.readInstant(SyncStateKeys.linkedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// First device: creates the local clinic and its owner member on the
  /// server and records the link. Idempotent: if [userId] is already a
  /// member of [localClinicId] only the link is (re)written. Throws
  /// [StateError] when the user belongs to a different clinic.
  Future<ClinicLink> pushLocalClinic({
    required String localClinicId,
    required String ownerMemberId,
    required String userId,
  }) async {
    final memberships = await listMemberships(userId);
    final mine = memberships.where((m) => m.clinicId == localClinicId);
    if (mine.isNotEmpty) {
      return _record(
        localClinicId,
        mine.first.memberId,
        ClinicLinkMode.pushedLocal,
      );
    }
    if (memberships.isNotEmpty) {
      throw StateError(
        'user already belongs to another clinic; adopt it on an empty device '
        'or sign in with this clinic\'s account',
      );
    }
    final clinic = await _localRow('clinics', localClinicId);
    final member = await _localRow('clinic_members', ownerMemberId);
    if (clinic == null || member == null) {
      throw StateError('local clinic or owner member not found');
    }
    if (member['clinic_id'] != localClinicId) {
      throw ArgumentError.value(
        ownerMemberId,
        'ownerMemberId',
        'belongs to another clinic',
      );
    }
    try {
      await client
          .from('clinics')
          .upsert(_codec('clinics').toServer(clinic), onConflict: 'id');
      await client.from('clinic_members').upsert({
        ..._codec('clinic_members').toServer(member),
        'user_id': userId,
      }, onConflict: 'id');
    } catch (e) {
      throw classifySyncError(e, table: 'clinics');
    }
    _log.info('clinic pushed; owner member linked');
    return _record(localClinicId, ownerMemberId, ClinicLinkMode.pushedLocal);
  }

  /// Second device: records [membership] as this device's clinic. Refused
  /// when the device already holds a clinic or pending writes.
  Future<ClinicLink> adoptRemoteClinic(RemoteMembership membership) async {
    final clinics = await db
        .customSelect('SELECT COUNT(*) AS n FROM clinics')
        .getSingle();
    final pending = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_outbox WHERE acked_at IS NULL',
        )
        .getSingle();
    if (clinics.read<int>('n') > 0 || pending.read<int>('n') > 0) {
      throw StateError(
        'device already holds clinic data; adopt only on an empty install',
      );
    }
    return _record(
      membership.clinicId,
      membership.memberId,
      ClinicLinkMode.adoptedRemote,
    );
  }

  Future<ClinicLink> _record(
    String clinicId,
    String memberId,
    ClinicLinkMode mode,
  ) async {
    final at = DateTime.now().toUtc();
    await syncState.write(SyncStateKeys.linkedClinicId, clinicId);
    await syncState.write(SyncStateKeys.linkedMemberId, memberId);
    await syncState.write(SyncStateKeys.linkMode, mode.name);
    await syncState.writeInstant(SyncStateKeys.linkedAt, at);
    return ClinicLink(
      clinicId: clinicId,
      memberId: memberId,
      mode: mode,
      linkedAt: at,
    );
  }

  SyncRowCodec _codec(String table) => SyncRowCodec(
    db.allTables.firstWhere((t) => t.actualTableName == table),
    jsonTextColumns: syncTablesByName[table]!.jsonTextColumns,
  );

  Future<Map<String, Object?>?> _localRow(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.data;
  }
}
