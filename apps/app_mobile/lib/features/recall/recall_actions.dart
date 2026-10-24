import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'incomplete_treatment.dart';
import 'patient_messenger.dart';
import 'recall_model.dart';

/// Write-side actions of the recall feature, kept out of the widgets so they
/// can be unit tested against an in-memory database.
class RecallActions {
  /// Creates the actions.
  const RecallActions({
    required this.recalls,
    required this.messenger,
    required this.ctx,
    required this.clock,
  });

  /// Recall repository.
  final RecallRepository recalls;

  /// Sends patient messages.
  final PatientMessenger messenger;

  /// Actor for writes.
  final ActorContext ctx;

  /// Current time.
  final DateTime Function() clock;

  /// Sends RECALL_DUE (or RECALL_OVERDUE when past due) to [patient] and,
  /// when the message left the device, marks the recall notified.
  Future<PatientMessageResult> sendReminder({
    required Recall recall,
    required Patient patient,
    required Clinic clinic,
  }) async {
    final now = clock();
    final template = templateByCode(
      recallTemplateCode(recallGroupFor(recall, now)),
    )!;
    final result = await messenger.send(
      patient: patient,
      clinic: clinic,
      template: template,
      variables: {
        'recall_type': recallTypeLabel(recall.type).toLowerCase(),
        'due_date': AppFormat.date(recall.dueAt),
      },
    );
    if (result.sent) await recalls.markNotified(ctx, recall.id, at: now);
    return result;
  }

  /// Sends TREATMENT_INCOMPLETE for [item].
  Future<PatientMessageResult> sendIncompleteNudge({
    required IncompleteTreatment item,
    required Patient patient,
    required Clinic clinic,
    required ToothNotation notation,
  }) => messenger.send(
    patient: patient,
    clinic: clinic,
    template: templateByCode('TREATMENT_INCOMPLETE')!,
    variables: {
      'procedure_name': item.procedure.name.toLowerCase(),
      'started_date': AppFormat.date(item.procedure.startedAt ?? item.since),
      'next_step': item.nextStep(notation),
    },
  );

  /// Dismisses [recallId]; [reason] is mandatory.
  Future<Recall> dismiss(String recallId, String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A reason is required');
    }
    return recalls.dismiss(ctx, recallId, trimmed);
  }
}

/// Actions bound to the current actor and repositories.
final Provider<RecallActions> recallActionsProvider = Provider<RecallActions>(
  (ref) => RecallActions(
    recalls: ref.watch(recallRepositoryProvider),
    messenger: ref.watch(patientMessengerProvider),
    ctx: ref.watch(actorContextProvider),
    clock: ref.watch(clockProvider),
  ),
);
