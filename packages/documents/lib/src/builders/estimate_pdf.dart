import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hash/document_hash.dart';
import '../text/formatters.dart';
import '../text/indian_number_words.dart';
import '../theme/document_widgets.dart';
import 'document_builder.dart';

/// Written treatment estimate (DCI Code 5.7.1: issued before treatment,
/// versioned, with a justification on any revision).
///
/// When the treatment [plan] and its [planLines] are supplied the lines are
/// grouped by phase with alternatives shown separately; otherwise the
/// estimate's own lines are listed flat.
class EstimatePdf extends DocumentBuilder {
  /// Creates the builder.
  EstimatePdf({
    required super.clinic,
    required ClinicMember super.dentist,
    required this.patient,
    required this.estimate,
    this.plan,
    this.planLines = const [],
    required super.theme,
  });

  /// The patient.
  final Patient patient;

  /// The estimate being printed.
  final Estimate estimate;

  /// The treatment plan the estimate was produced from, when available.
  final TreatmentPlan? plan;

  /// Lines of [plan] (used for phase and alternative grouping).
  final List<TreatmentPlanLine> planLines;

  @override
  String get title => 'TREATMENT ESTIMATE';

  @override
  String? get subtitle =>
      'No. ${estimate.number}  |  v${estimate.version}  |  '
      '${formatDate(estimate.issuedAt)}';

  @override
  String get documentHash => documentContentHash(estimate.toJson());

  @override
  String? get watermark => estimate.status == EstimateStatus.superseded
      ? 'SUPERSEDED'
      : estimate.status == EstimateStatus.draft
      ? 'DRAFT'
      : null;

  @override
  String? get footerNote =>
      'Estimate issued before treatment under DCI Code of Ethics 5.7.1; fees '
      'are indicative and may change with clinical findings.';

  @override
  String get suggestedFileName =>
      'Estimate_${estimate.number}_v${estimate.version}.pdf';

  @override
  List<pw.Widget> buildBody(pw.Context context) {
    final asOf = estimate.issuedAt;
    return [
      DocumentWidgets.infoColumns(
        theme,
        left: [
          MapEntry('Patient', patient.displayName),
          MapEntry('Patient No.', patient.patientNumber),
          MapEntry('Age / Sex', formatAgeSex(patient, asOf)),
          MapEntry('Phone', patient.phone),
        ],
        right: [
          MapEntry('Estimate No.', estimate.number),
          MapEntry('Version', '${estimate.version}'),
          MapEntry('Issued', formatDate(estimate.issuedAt)),
          MapEntry(
            'Valid until',
            estimate.validUntil == null
                ? 'Until the next review'
                : formatDate(estimate.validUntil!),
          ),
          MapEntry('Status', humanizeEnumName(estimate.status.name)),
          if (plan != null) MapEntry('Treatment plan', plan!.title),
        ],
      ),
      if (estimate.version > 1 && estimate.justification != null)
        DocumentWidgets.noteBox(
          theme,
          'Revision ${estimate.version}: ${estimate.justification}',
        ),
      pw.SizedBox(height: 6),
      ..._lineSections(),
      pw.SizedBox(height: 8),
      _totals(),
      pw.SizedBox(height: 4),
      pw.Text(
        'Amount in words: ${rupeesInWords(estimate.grandTotal)}',
        style: theme.boldStyle,
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        'This estimate covers the procedures listed. Laboratory charges, '
        'medicines and any additional procedures found necessary during '
        'treatment are not included unless stated. Multi-sitting procedures '
        'are billed per completed stage.',
        style: theme.mutedStyle,
      ),
      pw.SizedBox(height: 22),
      _acceptanceBlock(),
    ];
  }

  List<pw.Widget> _lineSections() {
    final currentPlan = plan;
    if (currentPlan == null || planLines.isEmpty) {
      return [_estimateLinesTable()];
    }
    final widgets = <pw.Widget>[];
    final primary = planLines.where((l) => !l.isAlternative).toList()
      ..sort(_byPhaseAndSequence);
    final alternatives = planLines.where((l) => l.isAlternative).toList()
      ..sort(_byPhaseAndSequence);
    final phaseIndexes = primary.map((l) => l.phaseIndex).toSet().toList()
      ..sort();
    for (final phaseIndex in phaseIndexes) {
      final phase = currentPlan.phases
          .where((p) => p.index == phaseIndex)
          .firstOrNull;
      final name = phase?.name ?? 'Phase ${phaseIndex + 1}';
      final lines = primary.where((l) => l.phaseIndex == phaseIndex).toList();
      widgets.add(
        DocumentWidgets.section(theme, 'Phase ${phaseIndex + 1}: $name'),
      );
      if (phase?.note != null && phase!.note!.isNotEmpty) {
        widgets.add(pw.Text(phase.note!, style: theme.mutedStyle));
      }
      widgets.add(_planLinesTable(lines));
      widgets.add(
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Phase subtotal: ${formatMoney(planSubtotal(lines))}',
              style: theme.boldStyle,
            ),
          ),
        ),
      );
    }
    if (alternatives.isNotEmpty) {
      final groups = <String, List<TreatmentPlanLine>>{};
      for (final line in alternatives) {
        groups
            .putIfAbsent(line.alternativeGroup ?? 'Alternative', () => [])
            .add(line);
      }
      widgets.add(DocumentWidgets.section(theme, 'Alternative options'));
      widgets.add(
        pw.Text(
          'Alternatives are offered in place of the corresponding planned '
          'procedure and are not included in the total below.',
          style: theme.mutedStyle,
        ),
      );
      for (final entry in groups.entries) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
            child: pw.Text(entry.key, style: theme.boldStyle),
          ),
        );
        widgets.add(_planLinesTable(entry.value));
      }
    }
    return widgets;
  }

  int _byPhaseAndSequence(TreatmentPlanLine a, TreatmentPlanLine b) {
    final phase = a.phaseIndex.compareTo(b.phaseIndex);
    return phase != 0 ? phase : a.sequence.compareTo(b.sequence);
  }

  pw.Widget _planLinesTable(List<TreatmentPlanLine> lines) =>
      DocumentWidgets.table(
        theme,
        headers: const [
          'Code',
          'Procedure',
          'Tooth',
          'Qty',
          'Fee',
          'Discount',
          'GST',
          'Net',
        ],
        rows: [
          for (final l in lines)
            [
              l.code,
              l.laymanName == l.name ? l.name : '${l.name}\n${l.laymanName}',
              _teethLabel(l.tooth, l.teeth, l.surfaces),
              '${l.quantity}',
              l.unitFee.format(symbol: false),
              l.discount.isZero ? '-' : l.discount.format(symbol: false),
              l.gstClass == GstClass.exemptHealthcare ? 'Exempt' : 'Taxable',
              l.net.format(symbol: false),
            ],
        ],
        rightAligned: const {3, 4, 5, 7},
        centered: const {2, 6},
        columnWidths: const {1: pw.FlexColumnWidth()},
      );

  String _teethLabel(ToothId? tooth, List<ToothId> teeth, SurfaceSet surfaces) {
    if (teeth.isNotEmpty) return formatTeeth(teeth, notation);
    return formatToothSurfaces(tooth, surfaces, notation);
  }

  pw.Widget _estimateLinesTable() => DocumentWidgets.table(
    theme,
    headers: const [
      '#',
      'Description',
      'Tooth',
      'Qty',
      'Fee',
      'Discount',
      'GST',
      'Total',
    ],
    rows: [
      for (var i = 0; i < estimate.lines.length; i++)
        [
          '${i + 1}',
          estimate.lines[i].description,
          estimate.lines[i].tooth == null
              ? '-'
              : formatTooth(estimate.lines[i].tooth!, notation),
          '${estimate.lines[i].quantity}',
          estimate.lines[i].unitFee.format(symbol: false),
          estimate.lines[i].discount.isZero
              ? '-'
              : estimate.lines[i].discount.format(symbol: false),
          estimate.lines[i].taxRatePercent == 0
              ? 'Exempt'
              : formatPercent(estimate.lines[i].taxRatePercent),
          estimate.lines[i].lineTotal.format(symbol: false),
        ],
    ],
    rightAligned: const {3, 4, 5, 7},
    centered: const {0, 2, 6},
    columnWidths: const {1: pw.FlexColumnWidth()},
  );

  pw.Widget _totals() => DocumentWidgets.totals(
    theme,
    [
      MapEntry('Subtotal', formatMoney(estimate.subtotal)),
      if (!estimate.discountTotal.isZero)
        MapEntry('Discount', '- ${formatMoney(estimate.discountTotal)}'),
      if (!estimate.taxTotal.isZero)
        MapEntry('GST', formatMoney(estimate.taxTotal)),
      MapEntry('Estimated total', formatMoney(estimate.grandTotal)),
    ],
    emphasisLabels: const {'Estimated total'},
  );

  pw.Widget _acceptanceBlock() {
    final accepted =
        plan?.isAccepted ?? estimate.status == EstimateStatus.accepted;
    final signerLines = <String>[
      if (accepted && plan?.acceptedBySignerName != null)
        'Signed by ${plan!.acceptedBySignerName}',
      if (accepted && plan?.acceptedAt != null)
        'on ${formatDateTime(plan!.acceptedAt!)}',
      if (!accepted) 'Name, relationship and date',
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'I have had the planned treatment, its alternatives and the above '
          'estimate explained to me and accept it.',
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            DocumentWidgets.signatureBox(
              theme,
              caption: 'Patient / guardian signature',
              lines: signerLines,
            ),
            DocumentWidgets.signatureBox(
              theme,
              caption: 'Dentist',
              lines: [
                theme.dentistNameLine(dentist!),
                theme.registrationLine(dentist!),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
