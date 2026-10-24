import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compliance_rules.dart';

/// Most recent sterilisation cycles of the clinic, newest first.
final StreamProvider<List<SterilisationCycle>> recentCyclesProvider =
    StreamProvider<List<SterilisationCycle>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref
          .watch(complianceRepositoryProvider)
          .watchRecentCycles(clinicId, limit: 200);
    });

/// Cycles in one local calendar month, oldest first (for the printable log).
final monthCyclesProvider =
    FutureProvider.family<List<SterilisationCycle>, (int, int)>((
      ref,
      yearMonth,
    ) async {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return const [];
      final (year, month) = yearMonth;
      final from = DateTime(year, month);
      final to = DateTime(year, month + 1);
      final cycles = await ref
          .watch(complianceRepositoryProvider)
          .cycles(clinicId, from: from.toUtc(), to: to.toUtc());
      return cyclesInMonth(cycles, year, month);
    });

/// Every licence of the clinic.
final StreamProvider<List<Licence>> licencesProvider =
    StreamProvider<List<Licence>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref.watch(complianceRepositoryProvider).watchLicences(clinicId);
    });

/// Whether the weekly spore test is overdue (true until cycles have loaded
/// and one is found within the interval).
final Provider<bool> sporeTestOverdueProvider = Provider<bool>((ref) {
  final cycles = ref.watch(recentCyclesProvider).value;
  if (cycles == null) return false;
  return sporeTestOverdue(cycles, ref.watch(clockProvider)());
});

/// Whether the latest spore test failed.
final Provider<bool> sporeTestFailedProvider = Provider<bool>((ref) {
  final cycles = ref.watch(recentCyclesProvider).value;
  if (cycles == null) return false;
  return lastSporeTestFailed(cycles);
});

/// Licences expired or expiring within [licenceWarningDays].
final Provider<List<Licence>> attentionLicencesProvider =
    Provider<List<Licence>>((ref) {
      final licences = ref.watch(licencesProvider).value;
      if (licences == null) return const [];
      return licencesNeedingAttention(licences, ref.watch(clockProvider)());
    });

/// Badge count for the Today quick action; 0 while loading.
final Provider<int> complianceAlertCountProvider = Provider<int>((ref) {
  final cycles = ref.watch(recentCyclesProvider).value;
  final licences = ref.watch(licencesProvider).value;
  if (cycles == null || licences == null) return 0;
  return complianceAlertCount(
    cycles: cycles,
    licences: licences,
    now: ref.watch(clockProvider)(),
  );
});
