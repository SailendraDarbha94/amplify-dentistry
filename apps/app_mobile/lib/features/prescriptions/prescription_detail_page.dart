import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'prescription_providers.dart';
import 'rx_document_service.dart';
import 'rx_line_tile.dart';
import 'rx_model.dart';

/// Issued prescription: lines with Schedule H1 and caution tags, the
/// verification code, and actions to preview/print, share the PDF, send the
/// PRESCRIPTION_LINK on WhatsApp and repeat into a new draft.
class PrescriptionDetailPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const PrescriptionDetailPage({
    super.key,
    required this.patientId,
    required this.prescriptionId,
  });

  /// Patient.
  final String patientId;

  /// Prescription.
  final String prescriptionId;

  @override
  ConsumerState<PrescriptionDetailPage> createState() =>
      _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState
    extends ConsumerState<PrescriptionDetailPage> {
  bool _busy = false;

  ClinicMember? _prescriber(Prescription rx) {
    final members = ref.read(clinicMembersProvider).value ?? const [];
    return members.where((m) => m.id == rx.prescriberId).firstOrNull ??
        ref.read(currentMemberProvider).value;
  }

  Future<Uint8List?> _pdf(Prescription rx) async {
    final clinic = ref.read(currentClinicProvider).value;
    final patient = ref.read(rxPatientProvider(widget.patientId)).value;
    final dentist = _prescriber(rx);
    if (clinic == null || patient == null || dentist == null) return null;
    final fonts = await ref.read(documentFontsProvider.future);
    return buildPrescriptionPdf(
      clinic: clinic,
      dentist: dentist,
      patient: patient,
      prescription: rx,
      fonts: fonts,
      generatedAt: ref.read(clockProvider)(),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) _toast('${context.strings.somethingWentWrong}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(Prescription rx) => _run(() async {
    final bytes = await _pdf(rx);
    if (bytes == null || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewPage(
          title: 'Prescription ${rx.verificationCode}',
          bytes: bytes,
          fileName: 'prescription-${rx.verificationCode}.pdf',
        ),
      ),
    );
  });

  Future<void> _share(Prescription rx) => _run(() async {
    final bytes = await _pdf(rx);
    if (bytes == null) return;
    await sharePdf(
      bytes,
      filename: 'prescription-${rx.verificationCode}.pdf',
      subject: 'Prescription ${rx.verificationCode}',
    );
  });

  Future<void> _sendLink(Prescription rx) => _run(() async {
    final clinic = ref.read(currentClinicProvider).value;
    final patient = ref.read(rxPatientProvider(widget.patientId)).value;
    final dentist = _prescriber(rx);
    if (clinic == null || patient == null || dentist == null) return;
    final uri = await sendPrescriptionLink(
      messaging: ref.read(messagingProvider),
      request: prescriptionLinkRequest(
        clinic: clinic,
        dentist: dentist,
        patient: patient,
        prescription: rx,
        now: ref.read(clockProvider)(),
      ),
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) _toast('WhatsApp is not available on this phone');
  });

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final rxAsync = ref.watch(prescriptionProvider(widget.prescriptionId));
    final history = ref.watch(rxMedicalHistoryProvider(widget.patientId)).value;
    final patient = ref.watch(rxPatientProvider(widget.patientId)).value;
    final minor = patient?.isMinor(ref.watch(clockProvider)()) ?? false;
    final drugs = ref.watch(drugsByIdProvider);
    return rxAsync.when(
      loading: () =>
          LoadingScaffold(appBar: AppBar(title: Text(s.prescription))),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(s.prescription)),
        body: ErrorView(message: '$e'),
      ),
      data: (rx) {
        if (rx == null) {
          return Scaffold(
            appBar: AppBar(title: Text(s.prescription)),
            body: const EmptyState(
              icon: Icons.medication_outlined,
              title: 'Prescription not found',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(s.prescription),
            actions: [
              IconButton(
                key: const ValueKey('rx-repeat'),
                tooltip: 'Repeat',
                icon: const Icon(Icons.repeat),
                onPressed: () => context.push(
                  '/patients/${widget.patientId}/prescriptions/new'
                  '?repeatOf=${rx.id}',
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppFormat.dateTime(rx.issuedAt),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        StatusBadge(
                          key: const ValueKey('rx-verification-code'),
                          label: rx.verificationCode,
                          tone: BadgeTone.info,
                          icon: Icons.qr_code_2,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${rx.prescriberName}'
                      '${rx.prescriberQualifications.isEmpty ? '' : ', ${rx.prescriberQualifications.join(', ')}'}'
                      '  ·  Reg. No. ${rx.prescriberRegistrationNumber}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (rx.diagnosis != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      LabeledValue(label: 'Diagnosis', value: rx.diagnosis!),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (rx.hasScheduleH1)
                          const StatusBadge(
                            key: ValueKey('rx-detail-h1'),
                            label: 'Contains Schedule H1',
                            tone: BadgeTone.warning,
                            icon: Icons.verified_user_outlined,
                          ),
                        if (rx.isRepeatable)
                          const StatusBadge(label: 'Repeatable'),
                        if (rx.dispensedByClinic)
                          const StatusBadge(label: 'Dispensed by clinic'),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (var i = 0; i < rx.lines.length; i++)
                RxLineTile(
                  index: i + 1,
                  line: RxLineDraft.fromLine(
                    rx.lines[i],
                    drug: rx.lines[i].drugId == null
                        ? null
                        : drugs[rx.lines[i].drugId!],
                  ),
                  cautions: [
                    if ((drugs[rx.lines[i].drugId]?.pregnancyCaution ??
                            false) &&
                        (history?.pregnant ?? false))
                      'Pregnancy caution',
                    if ((drugs[rx.lines[i].drugId]?.pediatricCaution ??
                            false) &&
                        minor)
                      'Paediatric caution',
                  ],
                ),
              const Divider(height: 1),
              Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BigActionButton(
                      key: const ValueKey('rx-preview'),
                      label: 'Preview and print',
                      icon: Icons.print_outlined,
                      loading: _busy,
                      onPressed: _busy ? null : () => _preview(rx),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BigActionButton(
                      key: const ValueKey('rx-share'),
                      label: 'Share PDF',
                      icon: Icons.share_outlined,
                      tonal: true,
                      onPressed: _busy ? null : () => _share(rx),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BigActionButton(
                      key: const ValueKey('rx-whatsapp'),
                      label: 'Send link on WhatsApp',
                      icon: Icons.chat_outlined,
                      tonal: true,
                      onPressed: _busy ? null : () => _sendLink(rx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
