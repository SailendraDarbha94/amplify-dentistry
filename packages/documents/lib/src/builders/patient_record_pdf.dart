import 'package:ampdent_core/ampdent_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hash/document_hash.dart';
import '../text/formatters.dart';
import '../theme/document_theme.dart';
import '../theme/document_widgets.dart';
import 'document_builder.dart';
import 'patient_record_history.dart';

/// The patient's record copy that the DCI Code (Reg. 3.3.2) requires within
/// 72 hours of a request: demographics, a tabular odontogram, the full
/// chronological clinical history and the financial summary.
class PatientRecordPdf extends DocumentBuilder {
  /// Creates the builder. All collections default to empty; [asOf] is the
  /// date the odontogram and ages are evaluated at (defaults to now).
  PatientRecordPdf({
    required super.clinic,
    required this.patient,
    super.dentist,
    this.toothStates = const [],
    this.findings = const [],
    this.procedures = const [],
    this.plans = const [],
    this.invoices = const [],
    this.payments = const [],
    this.prescriptions = const [],
    this.consents = const [],
    this.notes = const [],
    this.perioExams = const [],
    this.medicalHistory,
    DateTime? asOf,
    required super.theme,
  }) : asOf = asOf ?? DateTime.now();

  /// The patient.
  final Patient patient;

  /// Tooth state history.
  final List<ToothStateRecord> toothStates;

  /// Findings.
  final List<Finding> findings;

  /// Procedures (all statuses; deleted rows are listed as such).
  final List<ProcedureRecord> procedures;

  /// Treatment plans.
  final List<TreatmentPlan> plans;

  /// Invoices.
  final List<Invoice> invoices;

  /// Payments.
  final List<Payment> payments;

  /// Prescriptions.
  final List<Prescription> prescriptions;

  /// Procedure consents.
  final List<ConsentRecord> consents;

  /// Clinical notes.
  final List<ClinicalNote> notes;

  /// Periodontal exams.
  final List<PerioExam> perioExams;

  /// Latest medical history, if any.
  final MedicalHistory? medicalHistory;

  /// Evaluation date.
  final DateTime asOf;

  @override
  String get title => 'PATIENT RECORD COPY';

  @override
  String? get subtitle =>
      '${patient.patientNumber}  |  as of ${formatDate(asOf)}';

  @override
  String get documentHash => documentContentHash({
    'patient': patient.toJson(),
    'asOf': asOf.toUtc().toIso8601String(),
    'counts': {
      'toothStates': toothStates.length,
      'findings': findings.length,
      'procedures': procedures.length,
      'plans': plans.length,
      'invoices': invoices.length,
      'payments': payments.length,
      'prescriptions': prescriptions.length,
      'consents': consents.length,
      'notes': notes.length,
      'perioExams': perioExams.length,
    },
    'ids': [
      ...toothStates.map((e) => e.id),
      ...findings.map((e) => e.id),
      ...procedures.map((e) => e.id),
      ...plans.map((e) => e.id),
      ...invoices.map((e) => e.id),
      ...payments.map((e) => e.id),
      ...prescriptions.map((e) => e.id),
      ...consents.map((e) => e.id),
      ...notes.map((e) => e.id),
      ...perioExams.map((e) => e.id),
    ]..sort(),
  });

  @override
  String? get footerNote =>
      'Record copy furnished under DCI Code of Ethics 3.3.2. Confidential: '
      'contains personal health data protected under the DPDP Act, 2023.';

  @override
  String get suggestedFileName =>
      'Record_${patient.patientNumber}_${asOf.toIso8601String().substring(0, 10)}.pdf';

  @override
  List<pw.Widget> buildBody(pw.Context context) => [
    _summary(),
    if (medicalHistory != null) ..._medicalHistory(medicalHistory!),
    DocumentWidgets.section(theme, 'Odontogram (current tooth states)'),
    ..._odontogram(),
    DocumentWidgets.section(theme, 'Clinical history (chronological)'),
    _history(),
    DocumentWidgets.section(theme, 'Financial summary'),
    ..._financial(),
  ];

  pw.Widget _summary() => DocumentWidgets.infoColumns(
    theme,
    left: [
      MapEntry('Patient', patient.displayName),
      MapEntry('Patient No.', patient.patientNumber),
      MapEntry('Age / Sex', formatAgeSex(patient, asOf)),
      MapEntry(
        'Date of birth',
        patient.dateOfBirth == null ? null : formatDate(patient.dateOfBirth!),
      ),
      MapEntry('Phone', patient.phone),
      MapEntry('Address', formatPatientAddress(patient)),
    ],
    right: [
      MapEntry('ABHA', patient.abhaNumber),
      MapEntry(
        'Guardian',
        patient.guardianName == null
            ? null
            : '${patient.guardianName} (${patient.guardianRelation ?? 'guardian'})',
      ),
      MapEntry('Registered on', formatDate(patient.createdAt)),
      MapEntry('Procedures on file', '${procedures.length}'),
      MapEntry('Visits with notes', '${notes.length}'),
      MapEntry('Record generated', formatDateTime(theme.generatedAt)),
    ],
  );

  List<pw.Widget> _medicalHistory(MedicalHistory history) {
    final flags = history.redFlags
        .map((f) => humanizeEnumName(f.name))
        .toList();
    final allergies = history.allergies
        .map(
          (a) =>
              '${a.substance}'
              '${a.reaction == null ? '' : ' (${a.reaction})'}'
              ' - ${a.severity.name}',
        )
        .toList();
    return [
      DocumentWidgets.section(
        theme,
        'Medical history (recorded ${formatDate(history.recordedAt)})',
      ),
      DocumentWidgets.keyValue(
        theme,
        'Red flags',
        flags.isEmpty ? 'None' : flags.join(', '),
      ),
      DocumentWidgets.keyValue(
        theme,
        'Allergies',
        allergies.isEmpty ? 'None recorded' : allergies.join('; '),
      ),
      DocumentWidgets.keyValue(
        theme,
        'Medications',
        history.medications.isEmpty ? 'None' : history.medications.join(', '),
      ),
      DocumentWidgets.keyValue(theme, 'Notes', history.otherNotes),
    ];
  }

  List<pw.Widget> _odontogram() {
    final states = currentToothStates(toothStates);
    // Primary rows only while at least one primary tooth is still in the
    // mouth or expected (adults with every primary tooth exfoliated skip them).
    final showPrimary = states.entries.any(
      (e) => e.key.isPrimary && !e.value.isAbsent,
    );
    final widgets = <pw.Widget>[];
    for (final arch in Arch.values) {
      widgets.add(_archTable(arch, Dentition.permanent, states));
      if (showPrimary) {
        widgets.add(pw.SizedBox(height: 3));
        widgets.add(_archTable(arch, Dentition.primary, states));
      }
      widgets.add(pw.SizedBox(height: 4));
    }
    widgets.add(
      pw.Text(
        'Legend: P present, U unerupted, E erupting, I impacted, M missing, '
        'X extracted, S exfoliated, R retained primary, IM implant, '
        'SN supernumerary, blank = not recorded. Teeth in ${notation.label}.',
        style: theme.mutedStyle,
      ),
    );
    return widgets;
  }

  pw.Widget _archTable(
    Arch arch,
    Dentition dentition,
    Map<ToothId, ToothState> states,
  ) {
    final row = ToothId.archRow(arch, dentition);
    final label = '${arch == Arch.upper ? 'Upper' : 'Lower'} ${dentition.name}';
    return pw.TableHelper.fromTextArray(
      headers: [label, for (final t in row) formatTooth(t, notation)],
      data: [
        ['State', for (final t in row) _stateCode(states[t])],
      ],
      headerStyle: theme.tableHeaderStyle,
      headerDecoration: const pw.BoxDecoration(
        color: DocumentColors.headerFill,
      ),
      cellStyle: theme.tableCellStyle,
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      columnWidths: const {0: pw.FixedColumnWidth(66)},
      defaultColumnWidth: const pw.FlexColumnWidth(),
    );
  }

  String _stateCode(ToothState? state) => switch (state) {
    null => '',
    ToothState.present => 'P',
    ToothState.unerupted => 'U',
    ToothState.erupting => 'E',
    ToothState.impacted => 'I',
    ToothState.missing => 'M',
    ToothState.extracted => 'X',
    ToothState.exfoliated => 'S',
    ToothState.retainedPrimary => 'R',
    ToothState.implant => 'IM',
    ToothState.supernumerary => 'SN',
  };

  pw.Widget _history() {
    final events = buildPatientHistory(
      notation: notation,
      findings: findings,
      procedures: procedures,
      plans: plans,
      prescriptions: prescriptions,
      consents: consents,
      notes: notes,
      perioExams: perioExams,
    );
    if (events.isEmpty) return pw.Text('No clinical entries on file.');
    return DocumentWidgets.table(
      theme,
      headers: const ['Date', 'Type', 'Tooth', 'Details'],
      rows: [
        for (final e in events)
          [formatDate(e.occurredAt), e.kind, e.teeth, e.details],
      ],
      columnWidths: const {3: pw.FlexColumnWidth()},
    );
  }

  List<pw.Widget> _financial() {
    final billed =
        invoices
            .where((i) => i.status != InvoiceStatus.voided && !i.isDraftNumber)
            .toList()
          ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
    final totalBilled = billed.map((i) => i.grandTotal).total;
    final totalPaid = payments
        .map((p) => p.isRefund ? -p.amount : p.amount)
        .total;
    final outstanding = billed.map((i) => i.balance).total;
    return [
      if (billed.isEmpty)
        pw.Text('No issued invoices on file.')
      else
        DocumentWidgets.table(
          theme,
          headers: const ['Date', 'Number', 'Type', 'Total', 'Paid', 'Balance'],
          rows: [
            for (final i in billed)
              [
                formatDate(i.issuedAt),
                i.number,
                humanizeEnumName(i.documentType.name),
                i.grandTotal.format(symbol: false),
                i.amountPaid.format(symbol: false),
                i.balance.format(symbol: false),
              ],
          ],
          rightAligned: const {3, 4, 5},
          columnWidths: const {2: pw.FlexColumnWidth()},
        ),
      pw.SizedBox(height: 6),
      DocumentWidgets.totals(
        theme,
        [
          MapEntry('Total billed', formatMoney(totalBilled)),
          MapEntry('Total received', formatMoney(totalPaid)),
          MapEntry('Outstanding balance', formatMoney(outstanding)),
        ],
        emphasisLabels: const {'Outstanding balance'},
      ),
    ];
  }
}
