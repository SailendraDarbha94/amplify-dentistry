import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'consent_model.dart';
import 'consent_providers.dart';
import 'document_preview_page.dart';

/// A signed consent: who signed, what was explained, the signature image,
/// the exact text and the sealed PDF (print / share).
class ConsentDetailPage extends ConsumerWidget {
  /// Creates the page.
  const ConsentDetailPage({
    super.key,
    required this.patientId,
    required this.consentId,
  });

  /// The patient.
  final String patientId;

  /// The consent record.
  final String consentId;

  Future<void> _openPdf(
    BuildContext context,
    WidgetRef ref, {
    required ConsentRecord consent,
    required Patient patient,
    required Clinic clinic,
    required ClinicMember dentist,
  }) async {
    final path = consent.signatureImagePath;
    final signature = path == null
        ? null
        : await ref.read(signatureBytesProvider(path).future);
    if (!context.mounted) return;
    await DocumentPreviewPage.show(
      context,
      title: 'Consent PDF',
      fileName: 'Consent_${consent.templateCode}_${patient.patientNumber}.pdf',
      render: (fonts) => ConsentPdf(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        consent: consent,
        signatureImageBytes: signature,
        theme: DocumentTheme(fonts: fonts),
      ).build(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final consent = ref.watch(consentRecordProvider(consentId));
    final patient = ref.watch(patientProvider(patientId)).value;
    final clinic = ref.watch(currentClinicProvider).value;
    final notation = ref.watch(notationProvider);
    return consent.when(
      loading: () => LoadingScaffold(message: s.loading),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: e.toString()),
      ),
      data: (c) {
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorView(message: 'Consent not found'),
          );
        }
        final dentist = ref.watch(consentDentistProvider(c.dentistId)).value;
        final template = consentTemplateByCode(c.templateCode);
        final canPdf = patient != null && clinic != null && dentist != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(template?.title ?? c.templateCode),
            actions: [
              IconButton(
                key: const ValueKey('consent-pdf'),
                tooltip: 'PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: canPdf
                    ? () => _openPdf(
                        context,
                        ref,
                        consent: c,
                        patient: patient,
                        clinic: clinic,
                        dentist: dentist,
                      )
                    : null,
              ),
            ],
          ),
          body: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              SectionCard(
                title: 'Signature',
                trailing: const StatusBadge(
                  label: 'Signed',
                  tone: BadgeTone.success,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledValue(label: 'Signer', value: c.signerName),
                    LabeledValue(
                      label: 'Capacity',
                      value: signerRelationLabel(c.signerRelation),
                    ),
                    if (c.signerPhone != null)
                      LabeledValue(
                        label: s.phone,
                        value: AppFormat.phone(c.signerPhone!),
                      ),
                    LabeledValue(
                      label: 'Signed on',
                      value: AppFormat.dateTime(c.signedAt),
                    ),
                    if (c.witnessName != null)
                      LabeledValue(label: 'Witness', value: c.witnessName!),
                    if (c.signatureImagePath != null)
                      _SignatureImage(path: c.signatureImagePath!),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Procedure',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledValue(
                      label: 'Template',
                      value: '${c.templateCode} (${c.languageCode})',
                    ),
                    LabeledValue(
                      label: s.teeth,
                      value: c.teeth.isEmpty
                          ? '-'
                          : notation.formatAll(c.teeth),
                    ),
                    LabeledValue(
                      label: s.procedures,
                      value: '${c.procedureIds.length}',
                    ),
                    LabeledValue(
                      label: 'Dentist',
                      value:
                          '${dentist?.displayName ?? c.dentistId}  |  '
                          'Reg. No. ${c.dentistRegistrationNumber}',
                    ),
                    if (c.discussionNote != null)
                      LabeledValue(
                        label: 'Discussion note',
                        value: c.discussionNote!,
                      ),
                    LabeledValue(
                      label: 'Document hash',
                      value: shortHash(c.documentHash, length: 24),
                    ),
                    LabeledValue(label: 'Device', value: c.deviceId),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Text as signed',
                child: Text(
                  c.renderedText,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SignatureImage extends ConsumerWidget {
  const _SignatureImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(signatureBytesProvider(path)).value;
    if (bytes == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: AppRadii.smAll,
        ),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Text('Signature image could not be displayed'),
          ),
        ),
      ),
    );
  }
}
