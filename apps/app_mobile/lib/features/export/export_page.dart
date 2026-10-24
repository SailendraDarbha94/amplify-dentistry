import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'export_providers.dart';

/// Export hub: one patient's record copy (PDF + JSON + images), the whole
/// clinic as JSON, and the data-ownership statement.
class ExportPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String _query = '';
  bool _busy = false;

  Future<void> _run(Future<String> Function() job) async {
    setState(() => _busy = true);
    try {
      final summary = await job();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Exported: $summary')));
    } on Object catch (e) {
      const Logger('export').warning('export failed', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPatient(Patient patient) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Export ${patient.displayName}?',
      message:
          'Creates the record copy PDF, a JSON bundle of every record and '
          'the patient\'s images, then opens the share sheet. The export is '
          'written to the audit log.',
      confirmLabel: 'Export',
      icon: Icons.download_outlined,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final outcome = await ref
          .read(exportServiceProvider)
          .exportPatient(ref.read(actorContextProvider), patient.id);
      return outcome.summary;
    });
  }

  Future<void> _exportClinic() async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Export the whole clinic?',
      message:
          'Every patient, invoice, consent, register and audit event as one '
          'JSON file. Keep it somewhere safe; it contains health records.',
      confirmLabel: 'Export',
      icon: Icons.business_outlined,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final outcome = await ref
          .read(exportServiceProvider)
          .exportClinic(ref.read(actorContextProvider));
      return outcome.summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final now = ref.watch(clockProvider)();
    final results = _query.trim().isEmpty
        ? const <Patient>[]
        : (ref.watch(patientSearchProvider(_query)).value ?? const [])
              .take(8)
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  key: ValueKey('export-progress'),
                ),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            SectionCard(
              title: 'Patient record copy',
              subtitle: 'PDF record, JSON bundle and images, shared together',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchField(
                    key: const ValueKey('export-patient-search'),
                    hintText: s.searchPatientsHint,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  if (_query.trim().isNotEmpty && results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(s.noResults),
                    ),
                  for (final p in results)
                    ListTile(
                      key: ValueKey('export-patient-${p.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(p.displayName),
                      subtitle: Text(
                        '${p.patientNumber}  ·  ${AppFormat.ageSex(p, now)}',
                      ),
                      trailing: const Icon(Icons.download_outlined),
                      onTap: () => _exportPatient(p),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'Clinic export',
              subtitle: 'Everything, as one JSON file',
              child: BigActionButton(
                key: const ValueKey('export-clinic'),
                label: 'Export clinic data',
                icon: Icons.business_outlined,
                tonal: true,
                loading: _busy,
                onPressed: _exportClinic,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('export-ownership'),
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Data ownership statement'),
                    subtitle: const Text('Your clinic owns its data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/export/data-ownership'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('export-audit'),
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Audit log'),
                    subtitle: const Text('Who changed what, when'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/audit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
