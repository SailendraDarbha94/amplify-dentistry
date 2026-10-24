import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/consent/document_preview_page.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'plan_dialogs.dart';
import 'plan_model.dart';
import 'plan_providers.dart';

/// Copy shown next to the WhatsApp button until the patient portal exists.
const String estimateLinkPendingCopy =
    'Patient links are not live yet: the WhatsApp message carries a '
    'placeholder link, so share the PDF itself.';

/// Issues the next estimate version for [editor]'s plan, asking for a
/// justification from version 2 on. Returns null when cancelled or refused.
Future<Estimate?> runEstimateFlow(
  BuildContext context,
  WidgetRef ref, {
  required PlanEditor editor,
}) async {
  final service = ref.read(planServiceProvider);
  final version = await service.nextEstimateVersion(editor.plan.id);
  String? justification;
  if (!context.mounted) return null;
  if (version > 1) {
    justification = await EstimateJustificationSheet.show(
      context,
      version: version,
    );
    if (justification == null) return null;
    if (justification.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A revised estimate needs a justification'),
          ),
        );
      }
      return null;
    }
  }
  try {
    final estimate = await service.issueEstimate(
      editor.plan.id,
      justification: justification,
      now: ref.read(clockProvider)(),
    );
    ref.invalidate(planEstimatesProvider(editor.plan.id));
    return estimate;
  } on ArgumentError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? e.toString())),
      );
    }
    return null;
  }
}

/// Opens the estimate PDF with print/share and a WhatsApp send button.
Future<void> showEstimatePreview(
  BuildContext context,
  WidgetRef ref, {
  required Patient patient,
  required Clinic clinic,
  required ClinicMember dentist,
  required Estimate estimate,
  TreatmentPlan? plan,
  List<TreatmentPlanLine> planLines = const [],
}) {
  return DocumentPreviewPage.show(
    context,
    title: 'Estimate ${estimate.number} v${estimate.version}',
    fileName: 'Estimate_${estimate.number}_v${estimate.version}.pdf',
    render: (fonts) => EstimatePdf(
      clinic: clinic,
      dentist: dentist,
      patient: patient,
      estimate: estimate,
      plan: plan,
      planLines: planLines,
      theme: DocumentTheme(fonts: fonts),
    ).build(),
    footer: _EstimateSendBar(
      patient: patient,
      clinic: clinic,
      estimate: estimate,
    ),
  );
}

class _EstimateSendBar extends ConsumerWidget {
  const _EstimateSendBar({
    required this.patient,
    required this.clinic,
    required this.estimate,
  });

  final Patient patient;
  final Clinic clinic;
  final Estimate estimate;

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final template = templateByCode('ESTIMATE_LINK');
    if (template == null) return;
    final now = ref.read(clockProvider)();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final log = await ref
          .read(messagingProvider)
          .send(
            MessageRequest(
              clinicId: clinic.id,
              patientId: patient.id,
              toPhone: patient.messagingPhone(now),
              template: template,
              variables: {
                'patient_name': patient.firstName,
                'document_number': '${estimate.number} v${estimate.version}',
                'clinic_name': clinic.name,
                'link': pendingPortalLink,
                'clinic_phone': clinic.whatsappPhone ?? clinic.phone,
              },
            ),
          );
      final uri = whatsappDeepLink(log.toPhone, log.renderedPreview);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('WhatsApp could not be opened')),
        );
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                estimateLinkPendingCopy,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('estimate-whatsapp'),
              onPressed: () => _send(context, ref),
              icon: const Icon(Icons.send_outlined),
              label: const Text('WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists the estimates issued for a plan; tapping one opens its PDF.
Future<void> showEstimatesSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Estimate> estimates,
  required ValueChanged<Estimate> onOpen,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (ctx) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    children: [
      Padding(
        padding: AppSpacing.horizontalGutter,
        child: Text(
          '${ctx.strings.estimate}s',
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
      ),
      if (estimates.isEmpty)
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text(ctx.strings.nothingHere),
        ),
      for (final e in estimates.reversed)
        ListTile(
          key: ValueKey('estimate-row-${e.id}'),
          leading: const Icon(Icons.request_quote_outlined),
          title: Text('v${e.version}  ${e.number}'),
          subtitle: Text(
            '${AppFormat.date(e.issuedAt)}  |  ${AppFormat.enumLabel(e.status)}'
            '${e.justification == null ? '' : '\n${e.justification}'}',
          ),
          isThreeLine: e.justification != null,
          trailing: MoneyText(AppFormat.money(e.grandTotal, showPaise: false)),
          onTap: () {
            Navigator.of(ctx).pop();
            onOpen(e);
          },
        ),
    ],
  ),
);
