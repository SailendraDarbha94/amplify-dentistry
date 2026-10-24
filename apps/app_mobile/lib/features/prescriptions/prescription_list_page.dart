import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'prescription_providers.dart';

/// Prescriptions of a patient, newest first, with a repeat shortcut per row
/// and a FAB for a new one.
class PrescriptionListPage extends ConsumerWidget {
  /// Creates the list for [patientId].
  const PrescriptionListPage({super.key, required this.patientId});

  /// Patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final patient = ref.watch(rxPatientProvider(patientId)).value;
    final list = ref.watch(patientPrescriptionsProvider(patientId));
    final base = '/patients/$patientId/prescriptions';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          patient == null
              ? s.prescription
              : '${s.prescription} · ${patient.displayName}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('rx-new'),
        onPressed: () => context.push('$base/new'),
        icon: const Icon(Icons.medication_outlined),
        label: const Text('New Rx'),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.medication_outlined,
              title: 'No prescriptions yet',
              message:
                  'Issue one from the drug master; it prints with your '
                  'registration number and a verification code.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final rx = items[i];
              final names = rx.lines
                  .map((l) => l.genericName.toUpperCase())
                  .join(', ');
              return ListTile(
                key: ValueKey('rx-row-${rx.id}'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${AppFormat.dateTime(rx.issuedAt)} · ${rx.prescriberName}'
                  '${rx.hasScheduleH1 ? ' · Schedule H1' : ''}',
                ),
                trailing: IconButton(
                  key: ValueKey('rx-row-repeat-${rx.id}'),
                  tooltip: 'Repeat',
                  icon: const Icon(Icons.repeat),
                  onPressed: () => context.push('$base/new?repeatOf=${rx.id}'),
                ),
                onTap: () => context.push('$base/${rx.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
