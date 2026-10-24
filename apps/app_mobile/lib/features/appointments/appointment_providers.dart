import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'appointment_form_model.dart';
import 'appointment_messaging.dart';

/// The local calendar day shown in the book.
final NotifierProvider<SelectedDayNotifier, DateTime> selectedDayProvider =
    NotifierProvider<SelectedDayNotifier, DateTime>(SelectedDayNotifier.new);

/// Holds the selected day (local midnight).
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dayStart(ref.watch(clockProvider)());

  /// Shows [day].
  void select(DateTime day) => state = dayStart(day);

  /// Moves by whole weeks.
  void shiftWeeks(int weeks) => state = state.add(Duration(days: 7 * weeks));

  /// Moves by whole days.
  void shiftDays(int days) => state = state.add(Duration(days: days));

  /// Jumps back to today.
  void today() => state = dayStart(ref.read(clockProvider)());
}

/// Live appointments starting on the day identified by [dayKey].
final dayAppointmentsProvider =
    StreamProvider.family<List<Appointment>, String>((ref, key) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final start = DateTime.parse(key);
      final end = start.add(const Duration(days: 1));
      return ref
          .watch(appointmentRepositoryProvider)
          .watchRange(clinicId, start.toUtc(), end.toUtc());
    });

/// Number of appointments per day key in the week starting [weekKey]
/// (Monday), for the dots on the week strip.
final weekCountsProvider = StreamProvider.family<Map<String, int>, String>((
  ref,
  weekKey,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(const {});
  final start = DateTime.parse(weekKey);
  final end = start.add(const Duration(days: 7));
  return ref
      .watch(appointmentRepositoryProvider)
      .watchRange(clinicId, start.toUtc(), end.toUtc())
      .map((list) {
        final counts = <String, int>{};
        for (final a in list) {
          if (!a.status.occupiesChair) continue;
          final k = dayKey(a.startsAt.toLocal());
          counts[k] = (counts[k] ?? 0) + 1;
        }
        return counts;
      });
});

/// One appointment, live. Resolves the patient first and then follows the
/// patient's appointment stream so status changes show immediately.
final appointmentProvider = StreamProvider.family<Appointment?, String>((
  ref,
  id,
) async* {
  final repo = ref.watch(appointmentRepositoryProvider);
  final first = await repo.getById(id);
  if (first == null) {
    yield null;
    return;
  }
  yield first;
  yield* repo
      .watchForPatient(first.patientId)
      .map((list) => list.firstWhereOrNull((a) => a.id == id));
});

/// Patients by id for a comma-joined, sorted id list (stable family key).
final patientsByIdsProvider =
    StreamProvider.family<Map<String, Patient>, String>((ref, joined) {
      if (joined.isEmpty) return Stream.value(const {});
      final ids = joined.split(',');
      return ref
          .watch(patientRepositoryProvider)
          .watchByIds(ids)
          .map((list) => {for (final p in list) p.id: p});
    });

/// Builds the key for [patientsByIdsProvider].
String patientIdsKey(Iterable<String> ids) =>
    (ids.toSet().toList()..sort()).join(',');

/// Full data-consent ledger of a patient, live.
final patientDataConsentsProvider =
    StreamProvider.family<List<DataConsent>, String>(
      (ref, patientId) =>
          ref.watch(consentRepositoryProvider).watchDataConsents(patientId),
    );

/// The patient's open visit, if any (re-read on demand).
final openVisitProvider = FutureProvider.family<Visit?, String>(
  (ref, patientId) =>
      ref.watch(appointmentRepositoryProvider).openVisit(patientId),
);

/// Planned or accepted procedures of a patient, for the procedure picker.
final plannedProceduresProvider =
    FutureProvider.family<List<ProcedureRecord>, String>(
      (ref, patientId) => ref
          .watch(chartRepositoryProvider)
          .proceduresForPatient(
            patientId,
            statuses: const [
              ProcedureStatus.planned,
              ProcedureStatus.accepted,
              ProcedureStatus.inProgress,
            ],
          ),
    );

/// Catalogue items visible to the clinic, keyed by id.
final catalogByIdProvider = FutureProvider<Map<String, CatalogItem>>((
  ref,
) async {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return const {};
  final items = await ref
      .watch(catalogRepositoryProvider)
      .itemsForClinic(clinicId);
  return {for (final i in items) i.id: i};
});

/// Catalogue search for the procedure picker.
final catalogSearchProvider = FutureProvider.family<List<CatalogItem>, String>((
  ref,
  query,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Future.value(const []);
  return ref
      .watch(catalogRepositoryProvider)
      .search(clinicId, query, limit: 40);
});

/// Clinicians (members whose role can treat), for the provider picker.
final Provider<List<ClinicMember>> cliniciansProvider =
    Provider<List<ClinicMember>>((ref) {
      final members = ref.watch(clinicMembersProvider).value ?? const [];
      return members.where((m) => m.role.isClinician).toList();
    });

/// Opens a URI outside the app. Tests override this to capture the link.
final Provider<UriLauncher> uriLauncherProvider = Provider<UriLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Messenger wired to the app's providers and current actor.
final Provider<AppointmentMessenger> appointmentMessengerProvider =
    Provider<AppointmentMessenger>(
      (ref) => AppointmentMessenger(
        messaging: ref.watch(messagingProvider),
        logs: ref.watch(messageLogRepositoryProvider),
        appointments: ref.watch(appointmentRepositoryProvider),
        ctx: ref.watch(actorContextProvider),
        launch: ref.watch(uriLauncherProvider),
        clock: ref.watch(clockProvider),
      ),
    );

/// Booker wired to the current actor.
final Provider<AppointmentBooker> appointmentBookerProvider =
    Provider<AppointmentBooker>(
      (ref) => AppointmentBooker(
        appointments: ref.watch(appointmentRepositoryProvider),
        ctx: ref.watch(actorContextProvider),
      ),
    );

/// Distinct colours for providers, by position in the member list.
const List<Color> providerPalette = [
  Color(0xFF0E7C86),
  Color(0xFF7B4FBF),
  Color(0xFFD9822B),
  Color(0xFF2E7D32),
  Color(0xFFC2185B),
  Color(0xFF1565C0),
  Color(0xFF6D4C41),
  Color(0xFF00838F),
];

/// Colour for [providerId] given the ordered member list.
Color providerColour(String providerId, List<ClinicMember> members) {
  final index = members.indexWhere((m) => m.id == providerId);
  return providerPalette[(index < 0 ? members.length : index) %
      providerPalette.length];
}
