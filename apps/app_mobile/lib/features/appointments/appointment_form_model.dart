import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';

/// Grid resolution of the appointment book, in minutes.
const int scheduleSlotMinutes = 10;

/// First hour drawn in the day view (local time).
const int scheduleDayStartHour = 8;

/// Hour at which the day view ends (exclusive, local time).
const int scheduleDayEndHour = 21;

/// Duration used when no procedure gives one.
const int defaultAppointmentMinutes = 30;

/// Duration choices offered as chips on the form.
const List<int> appointmentDurationChoices = [10, 20, 30, 45, 60, 90, 120];

/// Rounds [time] down to the nearest grid slot (seconds dropped).
DateTime roundToSlot(DateTime time) => DateTime(
  time.year,
  time.month,
  time.day,
  time.hour,
  time.minute - time.minute % scheduleSlotMinutes,
);

/// Midnight (local) of the day containing [time].
DateTime dayStart(DateTime time) => DateTime(time.year, time.month, time.day);

/// Monday (local midnight) of the week containing [time].
DateTime weekStart(DateTime time) =>
    dayStart(time).subtract(Duration(days: time.weekday - DateTime.monday));

/// Whether two instants fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `yyyy-mm-dd` key for widget keys and provider families.
String dayKey(DateTime day) {
  final local = day.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// Sum of the chosen procedures' durations rounded up to the grid, or
/// [defaultAppointmentMinutes] when nothing is chosen.
int defaultDurationFor(Iterable<PlannedWork> work) {
  final total = work.fold<int>(0, (sum, w) => sum + w.durationMinutes);
  if (total <= 0) return defaultAppointmentMinutes;
  final remainder = total % scheduleSlotMinutes;
  return remainder == 0 ? total : total + scheduleSlotMinutes - remainder;
}

/// A procedure chosen for the slot: either an existing planned
/// [ProcedureRecord] (carries [procedureId]) or a catalogue item picked for
/// the reason line (no clinical row is created from the book).
class PlannedWork {
  /// Creates a chosen piece of work.
  const PlannedWork({
    this.procedureId,
    required this.code,
    required this.name,
    required this.durationMinutes,
    this.teethLabel,
  });

  /// From a planned procedure record; duration from its catalogue item.
  factory PlannedWork.fromProcedure(
    ProcedureRecord record, {
    required ToothNotation notation,
    CatalogItem? catalogItem,
  }) {
    final teeth = record.tooth != null ? [record.tooth!] : record.teeth;
    return PlannedWork(
      procedureId: record.id,
      code: record.code,
      name: record.name,
      durationMinutes:
          catalogItem?.durationMinutes ?? defaultAppointmentMinutes,
      teethLabel: teeth.isEmpty
          ? null
          : teeth.map(notation.formatPlain).join(', '),
    );
  }

  /// From a catalogue item.
  factory PlannedWork.fromCatalog(CatalogItem item) => PlannedWork(
    code: item.code,
    name: item.name,
    durationMinutes: item.durationMinutes,
  );

  /// Planned [ProcedureRecord] id, when this came from the chart.
  final String? procedureId;

  /// Catalogue code.
  final String code;

  /// Procedure name.
  final String name;

  /// Expected chair time.
  final int durationMinutes;

  /// Teeth in the clinic's notation, when the record names any.
  final String? teethLabel;

  /// `RCT molar (16)` or just the name.
  String get label => teethLabel == null ? name : '$name ($teethLabel)';
}

/// Everything the booking form collects; immutable so the page can rebuild
/// freely. Times are local.
class AppointmentDraft {
  /// Creates a draft.
  const AppointmentDraft({
    this.patient,
    this.providerId,
    this.chairId,
    required this.startsAt,
    this.durationMinutes = defaultAppointmentMinutes,
    this.work = const [],
    this.reason = '',
    this.source = AppointmentSource.phone,
    this.notes = '',
  });

  /// Draft prefilled from an existing appointment (edit / move).
  factory AppointmentDraft.fromAppointment(
    Appointment a, {
    Patient? patient,
    List<PlannedWork> work = const [],
  }) => AppointmentDraft(
    patient: patient,
    providerId: a.providerId,
    chairId: a.chairId,
    startsAt: a.startsAt.toLocal(),
    durationMinutes: a.duration.inMinutes,
    work: work,
    reason: a.reason,
    source: a.source,
    notes: a.notes ?? '',
  );

  /// Patient being booked (required to save).
  final Patient? patient;

  /// Clinician id (required to save).
  final String? providerId;

  /// Chair id, or null for an unassigned slot.
  final String? chairId;

  /// Slot start, local.
  final DateTime startsAt;

  /// Slot length.
  final int durationMinutes;

  /// Procedures planned for the slot.
  final List<PlannedWork> work;

  /// Free-text reason.
  final String reason;

  /// Booking channel.
  final AppointmentSource source;

  /// Front-desk notes.
  final String notes;

  /// Slot end, local.
  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  /// Planned procedure ids (catalogue-only picks carry none).
  List<String> get plannedProcedureIds =>
      work.map((w) => w.procedureId).whereType<String>().toList();

  /// Reason to store: the typed reason, else the procedure names.
  String get effectiveReason => reason.trim().isNotEmpty
      ? reason.trim()
      : work.map((w) => w.label).join(', ');

  /// Validation message, or null when the draft can be saved.
  String? validate() {
    if (patient == null) return 'Choose a patient';
    if (providerId == null || providerId!.isEmpty) return 'Choose a dentist';
    if (durationMinutes < scheduleSlotMinutes) {
      return 'Duration must be at least $scheduleSlotMinutes minutes';
    }
    return null;
  }

  /// Returns a copy with the given fields replaced. Nullable fields use
  /// sentinel wrappers so they can be cleared.
  AppointmentDraft copyWith({
    Patient? patient,
    String? providerId,
    Object? chairId = _keep,
    DateTime? startsAt,
    int? durationMinutes,
    List<PlannedWork>? work,
    String? reason,
    AppointmentSource? source,
    String? notes,
  }) => AppointmentDraft(
    patient: patient ?? this.patient,
    providerId: providerId ?? this.providerId,
    chairId: chairId == _keep ? this.chairId : chairId as String?,
    startsAt: startsAt ?? this.startsAt,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    work: work ?? this.work,
    reason: reason ?? this.reason,
    source: source ?? this.source,
    notes: notes ?? this.notes,
  );

  /// Builds the entity. [existing] keeps id, status and stamps on an edit.
  Appointment toAppointment({
    required String clinicId,
    required DateTime now,
    Appointment? existing,
  }) {
    final p = patient;
    if (p == null) throw StateError('patient is required');
    final provider = providerId;
    if (provider == null) throw StateError('providerId is required');
    final utcNow = now.toUtc();
    final note = notes.trim();
    if (existing == null) {
      return Appointment(
        id: newId(),
        clinicId: clinicId,
        patientId: p.id,
        providerId: provider,
        chairId: chairId,
        startsAt: startsAt.toUtc(),
        endsAt: endsAt.toUtc(),
        reason: effectiveReason,
        plannedProcedureIds: plannedProcedureIds,
        source: source,
        notes: note.isEmpty ? null : note,
        createdAt: utcNow,
        updatedAt: utcNow,
      );
    }
    final moved =
        !existing.startsAt.isAtSameMomentAs(startsAt.toUtc()) ||
        !existing.endsAt.isAtSameMomentAs(endsAt.toUtc());
    return Appointment(
      id: existing.id,
      clinicId: existing.clinicId,
      patientId: p.id,
      providerId: provider,
      chairId: chairId,
      startsAt: startsAt.toUtc(),
      endsAt: endsAt.toUtc(),
      // A confirmed slot that moves needs confirming again.
      status: moved && existing.status == AppointmentStatus.confirmed
          ? AppointmentStatus.scheduled
          : existing.status,
      reason: effectiveReason,
      plannedProcedureIds: plannedProcedureIds,
      source: source,
      notes: note.isEmpty ? null : note,
      confirmedAt: existing.confirmedAt,
      reminder24hSentAt: moved ? null : existing.reminder24hSentAt,
      reminderMorningSentAt: moved ? null : existing.reminderMorningSentAt,
      arrivedAt: existing.arrivedAt,
      cancelledReason: existing.cancelledReason,
      createdAt: existing.createdAt,
      updatedAt: utcNow,
    );
  }
}

const Object _keep = Object();

/// Books and moves appointments: conflict lookup plus the audited write.
class AppointmentBooker {
  /// Creates a booker.
  const AppointmentBooker({required this.appointments, required this.ctx});

  /// Appointment repository.
  final AppointmentRepository appointments;

  /// Actor for writes.
  final ActorContext ctx;

  /// Chair-occupying appointments clashing with [draft] on its chair or with
  /// its provider; [excludeId] skips the appointment being edited.
  Future<List<Appointment>> conflictsFor(
    AppointmentDraft draft, {
    String? excludeId,
  }) => appointments.conflicts(
    clinicId: ctx.clinicId,
    chairId: draft.chairId,
    providerId: draft.providerId,
    start: draft.startsAt.toUtc(),
    end: draft.endsAt.toUtc(),
    excludeId: excludeId,
  );

  /// Validates and writes [draft]; throws [ArgumentError] on an invalid draft.
  Future<Appointment> save(
    AppointmentDraft draft, {
    Appointment? existing,
    DateTime? now,
  }) {
    final problem = draft.validate();
    if (problem != null) throw ArgumentError(problem);
    return appointments.upsert(
      ctx,
      draft.toAppointment(
        clinicId: ctx.clinicId,
        now: now ?? DateTime.now(),
        existing: existing,
      ),
    );
  }
}

/// Validators for the quick-add patient form inside the picker.
abstract final class QuickAddValidators {
  /// Name is required.
  static String? name(String? value) =>
      (value ?? '').trim().isEmpty ? 'Name is required' : null;

  /// Phone must be an Indian mobile.
  static String? phone(String? value) =>
      PhoneNumbers.isValidIndianMobile(value ?? '')
      ? null
      : 'Enter a 10-digit Indian mobile number';
}

/// Builds a quick-add [Patient] (adult, no DOB) from name and phone; the
/// repository mints the patient number because [Patient.patientNumber] is
/// left empty.
Patient quickAddPatient({
  required String clinicId,
  required String name,
  required String phone,
  required DateTime now,
}) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final first = parts.first;
  final last = parts.length > 1 ? parts.sublist(1).join(' ') : null;
  final utcNow = now.toUtc();
  return Patient(
    id: newId(),
    clinicId: clinicId,
    patientNumber: '',
    firstName: first,
    lastName: last,
    phone: PhoneNumbers.normaliseIndian(phone),
    createdAt: utcNow,
    updatedAt: utcNow,
  );
}
