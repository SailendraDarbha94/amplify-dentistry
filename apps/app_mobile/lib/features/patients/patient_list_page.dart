import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patient_providers.dart';

/// Patient list: search by name, phone or patient number; recently seen
/// patients when the search box is empty.
class PatientListPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const PatientListPage({super.key});

  @override
  ConsumerState<PatientListPage> createState() => _PatientListPageState();
}

class _PatientListPageState extends ConsumerState<PatientListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final searching = _query.trim().isNotEmpty;
    final results = searching
        ? ref.watch(patientSearchProvider(_query))
        : ref.watch(recentPatientsProvider);
    final count = ref.watch(patientCountProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(count == null ? s.patients : '${s.patients} ($count)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('patients-new'),
        onPressed: () => context.push('/patients/new'),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(s.newPatient),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: SearchField(
              key: const ValueKey('patients-search'),
              hintText: s.searchPatientsHint,
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          if (!searching)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Row(
                children: [
                  Text(
                    'Recently seen',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(
                  searching
                      ? patientSearchProvider(_query)
                      : recentPatientsProvider,
                ),
              ),
              data: (patients) => patients.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: searching ? s.noResults : s.nothingHere,
                      message: searching
                          ? 'No patient matches "$_query"'
                          : 'Add your first patient to get started',
                      action: searching
                          ? null
                          : FilledButton.icon(
                              onPressed: () => context.push('/patients/new'),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(s.newPatient),
                            ),
                    )
                  : _PatientList(patients: patients),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientList extends ConsumerWidget {
  const _PatientList({required this.patients});

  final List<Patient> patients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: patients.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = patients[index];
        final minor = p.isMinor(now);
        return ListTile(
          key: ValueKey('patient-row-${p.id}'),
          leading: CircleAvatar(
            child: Text(p.firstName.isEmpty ? '?' : p.firstName[0]),
          ),
          title: Text(p.displayName),
          subtitle: Text(
            '${p.patientNumber}  ·  ${AppFormat.ageSex(p, now)}  ·  '
            '${AppFormat.phone(p.phone)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: minor
              ? const StatusBadge(
                  label: 'Minor',
                  tone: BadgeTone.info,
                  dense: true,
                )
              : null,
          onTap: () => context.push('/patients/${p.id}'),
        );
      },
    );
  }
}
