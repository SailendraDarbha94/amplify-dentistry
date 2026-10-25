import 'package:ampdent_data/ampdent_data.dart';
import 'package:drift/drift.dart' show Insertable, Variable;
import 'package:supabase/supabase.dart';

import '../helpers.dart';
import 'fake_postgrest.dart';

export '../helpers.dart';
export 'fake_postgrest.dart';

/// A [TestEnv] plus a fake PostgREST, a [SupabaseClient] over it and the
/// device-side sync state.
class SyncTestEnv {
  SyncTestEnv._(this.env, this.fake, this.client)
    : state = DriftSyncStateRepository(env.db);

  final TestEnv env;
  final FakePostgrest fake;
  final SupabaseClient client;
  final DriftSyncStateRepository state;
  final List<Duration> sleeps = [];
  String? token = 'test-access-token';

  AppDatabase get db => env.db;
  DriftRepositories get repos => env.repos;

  static Future<SyncTestEnv> open({
    bool link = true,
    bool withPatient = true,
  }) async {
    final env = await TestEnv.open(withPatient: withPatient);
    final fake = FakePostgrest();
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: fake.client,
      accessToken: () async => 'test-access-token',
    );
    final s = SyncTestEnv._(env, fake, client);
    if (link) await s.state.write(SyncStateKeys.linkedClinicId, clinicId);
    return s;
  }

  SupabaseSyncEngine engine({
    int batchSize = 200,
    int pageSize = 1000,
    BackoffPolicy backoff = const BackoffPolicy(maxAttempts: 3),
    bool requireLink = true,
    String clinic = clinicId,
  }) => SupabaseSyncEngine(
    client: client,
    db: db,
    clinicId: clinic,
    accessTokenProvider: () async => token,
    backoff: backoff,
    pushBatchSize: batchSize,
    pullPageSize: pageSize,
    requireLink: requireLink,
    sleep: (d) async => sleeps.add(d),
  );

  Future<void> close() async {
    await client.dispose();
    await env.close();
  }

  /// SQL-level row (snake_case, storage values) of an entity insertable.
  Map<String, Object?> sqlRow(Insertable<Object?> row) => {
    for (final e in row.toColumns(false).entries)
      e.key: switch ((e.value as Variable).value) {
        final bool b => b ? 1 : 0,
        final v => v,
      },
  };

  /// Server-shaped row of an entity, as PostgREST would return it.
  Map<String, Object?> serverRow(String table, Insertable<Object?> row) {
    final info = db.allTables.firstWhere((t) => t.actualTableName == table);
    return SyncRowCodec(
      info,
      jsonTextColumns: syncTablesByName[table]!.jsonTextColumns,
    ).toServer(sqlRow(row));
  }

  /// Local SQL row by id.
  Future<Map<String, Object?>?> localRow(String table, String id) async {
    final r = await db
        .customSelect(
          'SELECT * FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return r?.data;
  }

  Future<int> pendingCount() => repos.outbox.pendingCount(clinicId);
}
