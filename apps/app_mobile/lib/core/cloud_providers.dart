/// Providers that switch between the offline and the cloud implementations:
/// the sync engine (Supabase when configured, signed in and linked; no-op
/// otherwise), its scheduler, and the messaging provider (Cloud API queue
/// when the clinic's WhatsApp is enabled, deep link otherwise). Re-exported
/// from `providers.dart`; features import that file.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clinic_link.dart';
import 'cloud_messaging.dart';
import 'providers.dart';
import 'whatsapp_cloud.dart';

/// Sync engine: `SupabaseSyncEngine` when the cloud is configured, a user is
/// signed in and this device is linked to the current clinic; otherwise a
/// `NoopSyncEngine` that only mirrors the outbox count.
final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>((ref) {
  final clinicId = ref.watch(currentClinicIdProvider);
  final client = ref.watch(cloudClientProvider);
  final signedIn = ref.watch(cloudAuthProvider.select((s) => s.isSignedIn));
  final linked =
      clinicId != null &&
      ref.watch(clinicLinkProvider.select((s) => s.isLinkedTo(clinicId)));
  final outbox = ref.watch(outboxRepositoryProvider);
  if (client == null || !signedIn || clinicId == null || !linked) {
    final engine = NoopSyncEngine(
      pendingCount: clinicId == null
          ? null
          : outbox.watchPendingCount(clinicId),
    );
    ref.onDispose(engine.dispose);
    return engine;
  }
  final engine = SupabaseSyncEngine(
    client: client,
    db: ref.watch(databaseProvider),
    clinicId: clinicId,
    accessTokenProvider: ref.watch(accessTokenProvider),
    outbox: outbox,
  );
  unawaited(engine.restoreLastSyncTimes());
  ref.onDispose(engine.dispose);
  return engine;
});

/// Live sync state for banners and the account page.
final StreamProvider<SyncState> syncStateProvider = StreamProvider<SyncState>(
  (ref) => ref.watch(syncEngineProvider).state,
);

/// Scheduler for a real engine; null for the no-op engine. Started by
/// `CloudLifecycle` when [schedulerEnabledProvider] allows.
final Provider<SyncScheduler?> syncSchedulerProvider = Provider<SyncScheduler?>(
  (ref) {
    final engine = ref.watch(syncEngineProvider);
    if (engine is! SupabaseSyncEngine) return null;
    final scheduler = SyncScheduler(
      engine: engine,
      pendingCount: engine.outbox.watchPendingCount(engine.clinicId),
      accessTokenProvider: ref.watch(accessTokenProvider),
    );
    ref.onDispose(() => unawaited(scheduler.dispose()));
    return scheduler;
  },
);

/// Runs a sync now: through the scheduler when one exists, else directly on
/// the engine. Safe to call with the no-op engine. Read it and call:
/// `ref.read(syncNowProvider)()`.
final Provider<Future<void> Function()> syncNowProvider =
    Provider<Future<void> Function()>(
      (ref) => () async {
        final scheduler = ref.read(syncSchedulerProvider);
        if (scheduler != null) return scheduler.syncNow();
        final engine = ref.read(syncEngineProvider);
        if (engine is SupabaseSyncEngine) return engine.syncNow();
        await engine.pushPending();
        await engine.pullSince(null);
      },
    );

/// Which messaging backend is in use: Cloud API when the clinic's WhatsApp
/// status is configured and enabled, deep link otherwise (and always while
/// the status is still loading or unavailable).
final Provider<MessagingMode> messagingModeProvider = Provider<MessagingMode>((
  ref,
) {
  final status = ref.watch(whatsappStatusProvider).value;
  return status?.isActive == true
      ? MessagingMode.cloudApi
      : MessagingMode.deepLink;
});

/// Outbound messaging. Every send is persisted through the
/// `MessageLogRepository` under the current actor: the deep-link provider is
/// wrapped in [LoggedMessagingProvider]; the cloud queue provider writes
/// through its sink after its own opt-in check.
final Provider<MessagingProvider> messagingProvider =
    Provider<MessagingProvider>((ref) {
      final logs = ref.watch(messageLogRepositoryProvider);
      final clock = ref.watch(clockProvider);
      if (ref.watch(messagingModeProvider) == MessagingMode.cloudApi) {
        return CloudQueueMessagingProvider(
          (log) async {
            await logs.enqueue(ref.read(actorContextProvider), log);
          },
          decide: buildCloudOptInDecider(
            patients: ref.watch(patientRepositoryProvider),
            consents: ref.watch(consentRepositoryProvider),
            clock: clock,
          ),
          statusLookup: (id) async => (await logs.getById(id))?.status,
          clock: clock,
        );
      }
      return LoggedMessagingProvider(
        DeepLinkMessagingProvider(clock: clock),
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
