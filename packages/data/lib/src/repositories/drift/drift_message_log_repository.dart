import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../message_log_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [MessageLogRepository].
class DriftMessageLogRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements MessageLogRepository {
  /// Creates the repository over [db].
  DriftMessageLogRepository(super.db);

  $MessageLogsTable get _t => attachedDatabase.messageLogs;

  @override
  Future<MessageLog> enqueue(ActorContext ctx, MessageLog message) {
    checkTenant(ctx, message.clinicId, 'message.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _t,
        entityType: 'MessageLog',
        entityId: message.id,
        before: await getById(message.id),
        after: message,
        insertable: message.toInsertable(),
        toJson: (m) => m.toJson(),
      ),
    );
  }

  @override
  Future<MessageLog> updateStatus(
    ActorContext ctx,
    String id,
    MessageStatus status, {
    String? providerMessageId,
    String? error,
    int? costPaise,
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getById(id);
    if (before == null) throw StateError('Message $id not found');
    checkTenant(ctx, before.clinicId, 'message.clinicId');
    final now = nowUtc(at);
    final after = before.copyWith(
      status: status,
      providerMessageId: providerMessageId,
      error: error,
      costPaise: costPaise,
      sentAt: status == MessageStatus.sent ? now : null,
      deliveredAt:
          status == MessageStatus.delivered || status == MessageStatus.read
          ? now
          : null,
    );
    return audited(
      ctx: ctx,
      table: _t,
      entityType: 'MessageLog',
      entityId: id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (m) => m.toJson(),
      action: AuditAction.statusChange,
    );
  });

  @override
  Future<MessageLog?> getById(String id) =>
      (select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<MessageLog>> queued(String clinicId, {int limit = 100}) =>
      (select(_t)
            ..where(
              (t) =>
                  t.clinicId.equals(clinicId) &
                  t.status.equalsValue(MessageStatus.queued),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(limit))
          .get();

  SimpleSelectStatement<$MessageLogsTable, MessageLog> _forPatient(
    String patientId,
  ) => select(_t)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

  @override
  Future<List<MessageLog>> forPatient(String patientId) =>
      _forPatient(patientId).get();

  @override
  Stream<List<MessageLog>> watchForPatient(String patientId) =>
      _forPatient(patientId).watch();
}
