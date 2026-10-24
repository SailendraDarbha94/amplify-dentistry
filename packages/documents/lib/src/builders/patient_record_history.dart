import 'package:ampdent_core/ampdent_core.dart';

import '../text/formatters.dart';

/// One row of the chronological clinical history in a record copy.
class PatientHistoryEvent {
  /// Creates an event.
  const PatientHistoryEvent({
    required this.occurredAt,
    required this.kind,
    required this.teeth,
    required this.details,
  });

  /// When the entry happened.
  final DateTime occurredAt;

  /// Entry type label (`Finding`, `Procedure`, `Note`, `Rx`, `Consent`, `Perio`).
  final String kind;

  /// Teeth involved, already formatted; `-` for none.
  final String teeth;

  /// Free-text description.
  final String details;
}

/// Merges findings, procedures, plans, prescriptions, consents, notes and
/// perio exams into one list sorted by date (oldest first).
List<PatientHistoryEvent> buildPatientHistory({
  required ToothNotation notation,
  Iterable<Finding> findings = const [],
  Iterable<ProcedureRecord> procedures = const [],
  Iterable<TreatmentPlan> plans = const [],
  Iterable<Prescription> prescriptions = const [],
  Iterable<ConsentRecord> consents = const [],
  Iterable<ClinicalNote> notes = const [],
  Iterable<PerioExam> perioExams = const [],
}) {
  final events = <PatientHistoryEvent>[
    for (final f in findings)
      PatientHistoryEvent(
        occurredAt: f.recordedAt,
        kind: 'Finding',
        teeth: formatToothSurfaces(f.tooth, f.surfaces, notation),
        details: [
          f.description,
          if (f.icdas != null) 'ICDAS ${f.icdas!.code}',
          if (f.icd10Code != null) f.icd10Code!,
          'status ${humanizeEnumName(f.status.name).toLowerCase()}',
        ].join('; '),
      ),
    for (final p in procedures)
      PatientHistoryEvent(
        occurredAt: p.completedAt ?? p.startedAt ?? p.plannedAt ?? p.createdAt,
        kind: 'Procedure',
        teeth: p.teeth.isNotEmpty
            ? formatTeeth(p.teeth, notation)
            : formatToothSurfaces(p.tooth, p.surfaces, notation),
        details: [
          '${p.code} ${p.name}',
          if (p.isMultiSitting)
            'stage ${p.stageIndex + 1}/${p.totalStages} ${p.currentStageName}',
          humanizeEnumName(p.status.name).toLowerCase(),
          'fee ${formatMoney(p.netFee)}',
          if (p.note != null && p.note!.isNotEmpty) p.note!,
        ].join('; '),
      ),
    for (final plan in plans)
      PatientHistoryEvent(
        occurredAt: plan.presentedAt ?? plan.createdAt,
        kind: 'Plan',
        teeth: '-',
        details:
            '${plan.title} v${plan.version}; '
            '${humanizeEnumName(plan.status.name).toLowerCase()}'
            '${plan.acceptedAt == null ? '' : '; accepted ${formatDate(plan.acceptedAt!)}'}',
      ),
    for (final rx in prescriptions)
      PatientHistoryEvent(
        occurredAt: rx.issuedAt,
        kind: 'Rx',
        teeth: '-',
        details: [
          if (rx.diagnosis != null) rx.diagnosis!,
          for (final l in rx.lines)
            '${l.genericName.toUpperCase()} ${l.strength} ${l.dose} '
                '${l.frequency} x ${l.durationDays} d',
        ].join('; '),
      ),
    for (final c in consents)
      PatientHistoryEvent(
        occurredAt: c.signedAt,
        kind: 'Consent',
        teeth: formatTeeth(c.teeth, notation),
        details:
            '${c.templateCode} signed by ${c.signerName} '
            '(${humanizeEnumName(c.signerRelation.name).toLowerCase()})'
            '${c.otpVerified ? ', OTP verified' : ''}',
      ),
    for (final n in notes)
      PatientHistoryEvent(
        occurredAt: n.createdAt,
        kind: 'Note',
        teeth: '-',
        details: _noteSummary(n),
      ),
    for (final e in perioExams)
      PatientHistoryEvent(
        occurredAt: e.examinedAt,
        kind: 'Perio',
        teeth: '-',
        details: _perioSummary(e),
      ),
  ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  return events;
}

String _noteSummary(ClinicalNote n) {
  final parts = <String>[
    if (n.chiefComplaint != null) 'C/O ${n.chiefComplaint}',
    if (n.provisionalDiagnosis != null) 'Prov. Dx ${n.provisionalDiagnosis}',
    if (n.finalDiagnosis != null) 'Dx ${n.finalDiagnosis}',
    if (n.treatmentDone != null) 'Tx ${n.treatmentDone}',
    if (n.advice != null) 'Advice ${n.advice}',
    if (n.followUp != null) 'F/U ${n.followUp}',
    if (n.freeText != null) n.freeText!,
    if (n.version > 1) 'v${n.version}',
    n.isSigned ? 'signed' : 'unsigned',
  ];
  return parts.join('; ');
}

String _perioSummary(PerioExam e) {
  final s = e.summary;
  final bpe = e.bpe.entries.map((x) => '${x.key.number}:${x.value.label}');
  return [
    if (bpe.isNotEmpty) 'BPE ${bpe.join(' ')}',
    if (s.sitesRecorded > 0)
      '${s.sitesRecorded} sites, BOP ${s.bleedingPercent.toStringAsFixed(0)}%, '
          'max PD ${s.maxProbingDepth} mm, max CAL ${s.maxClinicalAttachmentLoss} mm',
    if (e.stage != null) humanizeEnumName(e.stage!.name),
    if (e.grade != null) humanizeEnumName(e.grade!.name),
    if (e.note != null) e.note!,
  ].join('; ');
}
