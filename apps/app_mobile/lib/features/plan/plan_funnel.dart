import 'package:ampdent_core/ampdent_core.dart';

/// Funnel of a plan: presented, accepted, scheduled (any active line booked
/// or started), completed (every active line done).
class PlanFunnel {
  /// Creates a funnel.
  const PlanFunnel({
    required this.presented,
    required this.accepted,
    required this.scheduledCount,
    required this.completedCount,
    required this.totalCount,
  });

  /// Computes the funnel from the plan, its live lines, their chart
  /// procedures and the patient's appointments.
  factory PlanFunnel.of({
    required TreatmentPlan plan,
    required Iterable<TreatmentPlanLine> lines,
    required Iterable<ProcedureRecord> procedures,
    Iterable<Appointment> appointments = const [],
  }) {
    final ids = {
      for (final l in lines)
        if (!l.isAlternative && l.procedureId != null) l.procedureId!,
    };
    final procs = procedures.where((p) => ids.contains(p.id)).toList();
    final booked = <String>{};
    for (final a in appointments) {
      if (a.status == AppointmentStatus.cancelled ||
          a.status == AppointmentStatus.noShow) {
        continue;
      }
      booked.addAll(a.plannedProcedureIds);
    }
    var scheduled = 0;
    var completed = 0;
    for (final p in procs) {
      if (p.status.isDone) {
        completed++;
        scheduled++;
      } else if (p.status == ProcedureStatus.inProgress ||
          booked.contains(p.id)) {
        scheduled++;
      }
    }
    return PlanFunnel(
      presented: plan.presentedAt != null,
      accepted: plan.isAccepted,
      scheduledCount: scheduled,
      completedCount: completed,
      totalCount: ids.length,
    );
  }

  /// Whether the plan was presented to the patient.
  final bool presented;

  /// Whether the plan was accepted.
  final bool accepted;

  /// Active lines booked, started or done.
  final int scheduledCount;

  /// Active lines done.
  final int completedCount;

  /// Active lines with a chart procedure.
  final int totalCount;

  /// At least one active line is booked or under way.
  bool get scheduled => scheduledCount > 0;

  /// Every active line is done.
  bool get completed => totalCount > 0 && completedCount == totalCount;
}
