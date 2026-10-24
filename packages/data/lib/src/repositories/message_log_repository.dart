import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Outbound message log. Bodies are templates plus variables; no clinical
/// text is ever stored here.
abstract class MessageLogRepository {
  /// Queues a message.
  Future<MessageLog> enqueue(ActorContext ctx, MessageLog message);

  /// Updates delivery status (and provider id, error, cost, timestamps).
  Future<MessageLog> updateStatus(
    ActorContext ctx,
    String id,
    MessageStatus status, {
    String? providerMessageId,
    String? error,
    int? costPaise,
    DateTime? at,
  });

  /// Message by id.
  Future<MessageLog?> getById(String id);

  /// Queued messages, oldest first.
  Future<List<MessageLog>> queued(String clinicId, {int limit = 100});

  /// Messages for a patient, newest first.
  Future<List<MessageLog>> forPatient(String patientId);

  /// Stream of a patient's messages, newest first.
  Stream<List<MessageLog>> watchForPatient(String patientId);
}
