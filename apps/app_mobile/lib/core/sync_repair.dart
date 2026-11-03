/// Rows the server rejected for good (quarantined) and the outbox entries
/// held behind them (blocked), for the repair screen (Settings > Account &
/// sync > Changes needing attention) and the shell banner. The listing,
/// retry and discard logic is `SyncRepairService` in `ampdent_data`,
/// reached through the running `SupabaseSyncEngine`; the held-row count
/// comes straight from the outbox so it is known even while signed out.
library;

import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// The repair service of the running engine, or null while the phone is
/// signed out or not linked (nothing can be retried or discarded then).
final Provider<SyncRepairService?> syncRepairServiceProvider =
    Provider<SyncRepairService?>((ref) {
      final engine = ref.watch(syncEngineProvider);
      return engine is SupabaseSyncEngine ? engine.repair : null;
    });

/// Live number of held outbox rows (quarantined or blocked) of the current
/// clinic; 0 before onboarding.
final StreamProvider<int> syncProblemCountProvider = StreamProvider<int>((ref) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(0);
  return ref.watch(outboxRepositoryProvider).watchHeldCount(clinicId);
});

/// The held rows with their descriptions, reloaded whenever the held count
/// changes; empty without a repair service.
final FutureProvider<List<SyncProblem>> syncProblemsProvider =
    FutureProvider<List<SyncProblem>>((ref) async {
      final service = ref.watch(syncRepairServiceProvider);
      // Re-run when rows are quarantined, re-queued or discarded.
      ref.watch(syncProblemCountProvider);
      if (service == null) return const [];
      return service.listProblems();
    });
