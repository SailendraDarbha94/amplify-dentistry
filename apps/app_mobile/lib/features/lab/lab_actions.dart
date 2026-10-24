import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lab_model.dart';

/// Write-side actions of the lab feature: case creation linked to its
/// procedure, the timestamped status transitions, remakes and the
/// lab-ready message. Widgets call these; tests drive them directly.
class LabCaseActions {
  /// Creates the actions.
  const LabCaseActions({
    required this.labs,
    required this.chart,
    required this.messenger,
    required this.ctx,
    required this.clock,
  });

  /// Lab repository.
  final LabRepository labs;

  /// Procedure repository, to link `labCaseId`.
  final ChartRepository chart;

  /// Sends patient messages.
  final PatientMessenger messenger;

  /// Actor for writes.
  final ActorContext ctx;

  /// Current time.
  final DateTime Function() clock;

  /// Creates [labCase] and, when it comes from a procedure, stamps the
  /// procedure's `labCaseId`.
  Future<LabCase> create(LabCase labCase) async {
    final created = await labs.createCase(ctx, labCase);
    final procedureId = labCase.procedureId;
    if (procedureId != null) {
      final procedure = await chart.getProcedure(procedureId);
      if (procedure != null && procedure.labCaseId != created.id) {
        await chart.updateProcedure(
          ctx,
          procedure.copyWith(labCaseId: created.id, updatedAt: clock().toUtc()),
        );
      }
    }
    return created;
  }

  /// Marks sent now; `dueAt` comes from the lab's turnaround via
  /// `computeDueDate` (Sundays and [holidays] skipped).
  Future<LabCase> markSent(String id, {Set<DateTime> holidays = const {}}) =>
      labs.markSent(ctx, id, at: clock().toUtc(), holidays: holidays);

  /// Marks received now.
  Future<LabCase> markReceived(String id) =>
      labs.markReceived(ctx, id, at: clock().toUtc());

  /// Marks quality checked now.
  Future<LabCase> markQualityChecked(String id) =>
      labs.markQualityChecked(ctx, id, at: clock().toUtc());

  /// Marks fitted now.
  Future<LabCase> markFitted(String id) =>
      labs.markFitted(ctx, id, at: clock().toUtc());

  /// Requests a remake; returns the new linked case. [reason] is mandatory.
  Future<LabCase> requestRemake(String id, String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A reason is required');
    }
    return labs.requestRemake(ctx, id, reason: trimmed, at: clock().toUtc());
  }

  /// Cancels a case with a mandatory [reason].
  Future<LabCase> cancel(String id, String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A reason is required');
    }
    return labs.cancelCase(ctx, id, trimmed);
  }

  /// Sends LAB_READY_SEAT_APPT to the patient for [labCase].
  Future<PatientMessageResult> notifyReady({
    required LabCase labCase,
    required Patient patient,
    required Clinic clinic,
  }) => messenger.send(
    patient: patient,
    clinic: clinic,
    template: templateByCode('LAB_READY_SEAT_APPT')!,
    variables: {'lab_item': labItemLabel(labCase)},
  );

  /// Next transition offered for [labCase], or null when closed.
  static LabCaseStatus? nextStatus(LabCase labCase) => switch (labCase.status) {
    LabCaseStatus.created => LabCaseStatus.sent,
    LabCaseStatus.sent => LabCaseStatus.received,
    LabCaseStatus.received => LabCaseStatus.qualityChecked,
    LabCaseStatus.qualityChecked => LabCaseStatus.fitted,
    LabCaseStatus.remakeRequested ||
    LabCaseStatus.fitted ||
    LabCaseStatus.cancelled => null,
  };
}

/// Actions bound to the current actor and repositories.
final Provider<LabCaseActions> labCaseActionsProvider =
    Provider<LabCaseActions>(
      (ref) => LabCaseActions(
        labs: ref.watch(labRepositoryProvider),
        chart: ref.watch(chartRepositoryProvider),
        messenger: ref.watch(patientMessengerProvider),
        ctx: ref.watch(actorContextProvider),
        clock: ref.watch(clockProvider),
      ),
    );
