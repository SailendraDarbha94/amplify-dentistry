/// App-wide providers: database, repositories, actor context, current clinic
/// and member, messaging, fonts and notation. Features import this file and
/// never edit it; everything here is overridable in tests.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

export 'session.dart' show AppSession, AppSessionNotifier, appSessionProvider;

/// The open local database. Overridden in `main` and in tests.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Every Drift repository wired to [databaseProvider].
final Provider<DriftRepositories> repositoriesProvider =
    Provider<DriftRepositories>(
      (ref) => DriftRepositories(ref.watch(databaseProvider)),
    );

/// Actor for every repository write: current clinic, member and device.
/// Throws [StateError] before onboarding has created a clinic.
final Provider<ActorContext> actorContextProvider = Provider<ActorContext>(
  (ref) => ref.watch(appSessionProvider).actor,
);

/// Current clinic id, or null on a fresh install.
final Provider<String?> currentClinicIdProvider = Provider<String?>(
  (ref) => ref.watch(appSessionProvider).clinicId,
);

/// Live view of the current clinic row.
final StreamProvider<Clinic> currentClinicProvider = StreamProvider<Clinic>((
  ref,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return const Stream<Clinic>.empty();
  return ref
      .watch(clinicRepositoryProvider)
      .watchClinic(clinicId)
      .where((c) => c != null)
      .cast<Clinic>();
});

/// Live list of active members of the current clinic.
final StreamProvider<List<ClinicMember>> clinicMembersProvider =
    StreamProvider<List<ClinicMember>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref.watch(clinicRepositoryProvider).watchMembers(clinicId);
    });

/// Live view of the member the device is acting as.
final StreamProvider<ClinicMember> currentMemberProvider =
    StreamProvider<ClinicMember>((ref) {
      final session = ref.watch(appSessionProvider);
      final clinicId = session.clinicId;
      final memberId = session.memberId;
      if (clinicId == null || memberId == null) {
        return const Stream<ClinicMember>.empty();
      }
      return ref
          .watch(clinicRepositoryProvider)
          .watchMembers(clinicId, includeInactive: true)
          .map((list) => list.where((m) => m.id == memberId))
          .where((it) => it.isNotEmpty)
          .map((it) => it.first);
    });

/// Live list of active chairs of the current clinic.
final StreamProvider<List<Chair>> chairsProvider = StreamProvider<List<Chair>>((
  ref,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(const []);
  return ref.watch(clinicRepositoryProvider).watchChairs(clinicId);
});

/// Clinic repository.
final Provider<ClinicRepository> clinicRepositoryProvider =
    Provider<ClinicRepository>(
      (ref) => ref.watch(repositoriesProvider).clinics,
    );

/// Patient repository.
final Provider<PatientRepository> patientRepositoryProvider =
    Provider<PatientRepository>(
      (ref) => ref.watch(repositoriesProvider).patients,
    );

/// Appointment and visit repository.
final Provider<AppointmentRepository> appointmentRepositoryProvider =
    Provider<AppointmentRepository>(
      (ref) => ref.watch(repositoriesProvider).appointments,
    );

/// Odontogram, findings and procedures repository.
final Provider<ChartRepository> chartRepositoryProvider =
    Provider<ChartRepository>((ref) => ref.watch(repositoriesProvider).chart);

/// Procedure catalogue repository.
final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (ref) => ref.watch(repositoriesProvider).catalog,
    );

/// Treatment plan and estimate repository.
final Provider<TreatmentPlanRepository> treatmentPlanRepositoryProvider =
    Provider<TreatmentPlanRepository>(
      (ref) => ref.watch(repositoriesProvider).treatmentPlans,
    );

/// Procedure and data consent repository.
final Provider<ConsentRepository> consentRepositoryProvider =
    Provider<ConsentRepository>(
      (ref) => ref.watch(repositoriesProvider).consents,
    );

/// Clinical notes, medical history and images repository.
final Provider<ClinicalRepository> clinicalRepositoryProvider =
    Provider<ClinicalRepository>(
      (ref) => ref.watch(repositoriesProvider).clinical,
    );

/// Periodontal exam repository.
final Provider<PerioRepository> perioRepositoryProvider =
    Provider<PerioRepository>((ref) => ref.watch(repositoriesProvider).perio);

/// Drug master and prescription repository.
final Provider<PrescriptionRepository> prescriptionRepositoryProvider =
    Provider<PrescriptionRepository>(
      (ref) => ref.watch(repositoriesProvider).prescriptions,
    );

/// Invoices, payments and ledger repository.
final Provider<BillingRepository> billingRepositoryProvider =
    Provider<BillingRepository>(
      (ref) => ref.watch(repositoriesProvider).billing,
    );

/// Recall repository.
final Provider<RecallRepository> recallRepositoryProvider =
    Provider<RecallRepository>(
      (ref) => ref.watch(repositoriesProvider).recalls,
    );

/// Labs and lab cases repository.
final Provider<LabRepository> labRepositoryProvider = Provider<LabRepository>(
  (ref) => ref.watch(repositoriesProvider).labs,
);

/// Sterilisation and licence repository.
final Provider<ComplianceRepository> complianceRepositoryProvider =
    Provider<ComplianceRepository>(
      (ref) => ref.watch(repositoriesProvider).compliance,
    );

/// Audit log repository.
final Provider<AuditRepository> auditRepositoryProvider =
    Provider<AuditRepository>((ref) => ref.watch(repositoriesProvider).audit);

/// Message log repository.
final Provider<MessageLogRepository> messageLogRepositoryProvider =
    Provider<MessageLogRepository>(
      (ref) => ref.watch(repositoriesProvider).messages,
    );

/// Export repository.
final Provider<ExportRepository> exportRepositoryProvider =
    Provider<ExportRepository>((ref) => ref.watch(repositoriesProvider).export);

/// Sync outbox repository.
final Provider<OutboxRepository> outboxRepositoryProvider =
    Provider<OutboxRepository>((ref) => ref.watch(repositoriesProvider).outbox);

/// Sync engine; a no-op mirror of the outbox count until a backend exists.
final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>((ref) {
  final clinicId = ref.watch(currentClinicIdProvider);
  final engine = NoopSyncEngine(
    pendingCount: clinicId == null
        ? null
        : ref.watch(outboxRepositoryProvider).watchPendingCount(clinicId),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Live sync state for banners.
final StreamProvider<SyncState> syncStateProvider = StreamProvider<SyncState>(
  (ref) => ref.watch(syncEngineProvider).state,
);

/// Outbound messaging: WhatsApp/SMS deep links, every send logged to the
/// message log so the audit trail is complete even without a provider.
final Provider<MessagingProvider> messagingProvider =
    Provider<MessagingProvider>((ref) {
      final inner = DeepLinkMessagingProvider();
      final logs = ref.watch(messageLogRepositoryProvider);
      return LoggedMessagingProvider(
        inner,
        logs: logs,
        actor: () => ref.read(actorContextProvider),
      );
    });

/// Wraps a [MessagingProvider] so every queued message is persisted through
/// the [MessageLogRepository] under the current actor.
class LoggedMessagingProvider implements MessagingProvider {
  /// Creates the wrapper.
  const LoggedMessagingProvider(
    this._inner, {
    required this.logs,
    required this.actor,
  });

  final MessagingProvider _inner;

  /// Where queued messages are persisted.
  final MessageLogRepository logs;

  /// Supplies the actor at send time.
  final ActorContext Function() actor;

  @override
  Future<MessageLog> send(MessageRequest request) async {
    final log = await _inner.send(request);
    return logs.enqueue(actor(), log);
  }

  @override
  Future<MessageStatus> status(String providerMessageId) =>
      _inner.status(providerMessageId);
}

/// Embedded PDF fonts, loaded once.
final FutureProvider<DocumentFonts> documentFontsProvider =
    FutureProvider<DocumentFonts>((ref) => DocumentFonts.load());

/// Tooth notation chosen in clinic settings, as a live stream.
final StreamProvider<ToothNotation> notationSettingProvider =
    StreamProvider<ToothNotation>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(ToothNotation.fdi);
      return ref
          .watch(clinicRepositoryProvider)
          .watchSetting(clinicId, SettingKeys.notation)
          .map(
            (json) => enumSettingFromJson(
              ToothNotation.values,
              json,
              ToothNotation.fdi,
            ),
          );
    });

/// Tooth notation for display; FDI until the setting has loaded.
final Provider<ToothNotation> notationProvider = Provider<ToothNotation>(
  (ref) => ref.watch(notationSettingProvider).value ?? ToothNotation.fdi,
);

/// `DateTime.now()` behind a provider so tests can pin the clock.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
