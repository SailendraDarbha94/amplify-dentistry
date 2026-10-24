import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patient_header.dart';
import 'patient_providers.dart';
import 'patient_timeline.dart';

/// Patient detail: header, quick actions into every clinical feature, a
/// details card and a chronological timeline.
class PatientDetailPage extends ConsumerWidget {
  /// Creates the page for [patientId].
  const PatientDetailPage({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final patient = ref.watch(patientProvider(patientId));
    return patient.when(
      loading: () => LoadingScaffold(message: s.loading),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(patientProvider(patientId)),
        ),
      ),
      data: (p) => p == null
          ? Scaffold(
              appBar: AppBar(),
              body: const ErrorView(message: 'Patient not found'),
            )
          : _PatientDetailBody(patient: p),
    );
  }
}

class _PatientDetailBody extends StatelessWidget {
  const _PatientDetailBody({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final base = '/patients/${patient.id}';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patient.displayName),
          actions: [
            IconButton(
              key: const ValueKey('patient-edit'),
              tooltip: s.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('$base/edit'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Timeline'),
            ],
          ),
        ),
        body: Column(
          children: [
            PatientHeader(patient: patient),
            Expanded(
              child: TabBarView(
                children: [
                  _Overview(patient: patient, base: base),
                  PatientTimeline(patientId: patient.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.patient, required this.base});

  final Patient patient;
  final String base;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final actions = <(IconData, String, String, Key)>[
      (Icons.grid_on, s.chart, '$base/chart', const ValueKey('qa-chart')),
      (
        Icons.assignment_outlined,
        s.plan,
        '$base/plan',
        const ValueKey('qa-plan'),
      ),
      (
        Icons.draw_outlined,
        s.consent,
        '$base/consent/new',
        const ValueKey('qa-consent'),
      ),
      (
        Icons.notes_outlined,
        s.notes,
        '$base/notes',
        const ValueKey('qa-notes'),
      ),
      (
        Icons.medication_outlined,
        'Rx',
        '$base/prescriptions',
        const ValueKey('qa-prescriptions'),
      ),
      (
        Icons.receipt_long_outlined,
        s.bill,
        '$base/billing',
        const ValueKey('qa-billing'),
      ),
      (
        Icons.event_available_outlined,
        s.appointment,
        '/schedule/new?patientId=${patient.id}',
        const ValueKey('qa-appointment'),
      ),
    ];
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.9,
          children: [
            for (final (icon, label, route, key) in actions)
              QuickActionTile(
                key: key,
                icon: icon,
                label: label,
                onTap: () => context.push(route),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledValue(
                label: s.phone,
                value: AppFormat.phone(patient.phone),
              ),
              if (patient.altPhone != null)
                LabeledValue(
                  label: 'Alternate phone',
                  value: AppFormat.phone(patient.altPhone!),
                ),
              if (patient.email != null)
                LabeledValue(label: 'Email', value: patient.email!),
              LabeledValue(
                label: s.dateOfBirth,
                value: patient.dateOfBirth == null
                    ? (patient.approxAgeYears == null
                          ? '-'
                          : 'approx. ${patient.approxAgeYears} y')
                    : AppFormat.date(patient.dateOfBirth!),
              ),
              if (patient.addressLines.isNotEmpty || patient.city != null)
                LabeledValue(
                  label: s.address,
                  value: [
                    ...patient.addressLines,
                    if (patient.city != null) patient.city!,
                    if (patient.pincode != null) patient.pincode!,
                  ].join(', '),
                ),
              if (patient.abhaNumber != null)
                LabeledValue(label: 'ABHA', value: patient.abhaNumber!),
              if (patient.guardianName != null)
                LabeledValue(
                  label: s.guardian,
                  value: [
                    patient.guardianName!,
                    if (patient.guardianRelation != null)
                      '(${patient.guardianRelation})',
                    if (patient.guardianPhone != null)
                      AppFormat.phone(patient.guardianPhone!),
                  ].join(' '),
                ),
              LabeledValue(
                label: 'Language',
                value: patient.preferredLanguage.toUpperCase(),
              ),
              if (patient.notes != null)
                LabeledValue(label: s.notes, value: patient.notes!),
              LabeledValue(
                label: 'Registered',
                value: AppFormat.date(patient.createdAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
