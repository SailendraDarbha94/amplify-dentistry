import 'package:ampdent_core/ampdent_core.dart';

/// One editable line of a new invoice: the [InvoiceLine] being built, whether
/// it is included, and the GST class the catalogue assigned so an override
/// can be flagged.
class InvoiceDraftLine {
  /// Creates a draft line.
  const InvoiceDraftLine({
    required this.line,
    this.selected = true,
    this.catalogGstClass,
    this.procedure,
  });

  /// The line as it will be written (rates are applied at issue time).
  final InvoiceLine line;

  /// Whether the line goes on the invoice.
  final bool selected;

  /// GST class from the catalogue item, when known.
  final GstClass? catalogGstClass;

  /// Procedure the line bills, when any.
  final ProcedureRecord? procedure;

  /// Stage of multi-sitting work this line bills, when any.
  int? get stageIndex => line.stageIndex;

  /// Widget key suffix: the procedure id (plus `-s<k>` for a stage), or the
  /// line id for a free line.
  String get keySuffix {
    final p = procedure;
    if (p == null) return line.id;
    return BillableStage(procedure: p, stageIndex: line.stageIndex).key;
  }

  /// Whether the dentist changed the GST class away from the catalogue's.
  bool get gstClassOverridden =>
      catalogGstClass != null && line.gstClass != catalogGstClass;

  /// Whether the discount is larger than the gross line amount.
  bool get discountTooLarge => line.discount > line.gross;

  /// Returns a copy with the given fields replaced.
  InvoiceDraftLine copyWith({InvoiceLine? line, bool? selected}) =>
      InvoiceDraftLine(
        line: line ?? this.line,
        selected: selected ?? this.selected,
        catalogGstClass: catalogGstClass,
        procedure: procedure,
      );
}

/// One billable unit: a whole single-sitting procedure, or one reached stage
/// of multi-sitting work. A procedure with N stages is billed as N instalments
/// of its fee (`Money.split`), each once, when that stage is reached.
class BillableStage {
  /// Creates a unit; [stageIndex] is null for single-sitting work.
  const BillableStage({required this.procedure, this.stageIndex});

  /// The procedure.
  final ProcedureRecord procedure;

  /// 0-based stage, or null for the whole procedure.
  final int? stageIndex;

  /// Whether this is one stage of multi-sitting work.
  bool get isStage => stageIndex != null;

  /// Fee of this unit: the stage's instalment, or the whole fee.
  Money get fee => isStage
      ? procedure.fee.split(procedure.totalStages)[stageIndex!]
      : procedure.fee;

  /// Discount of this unit, split like the fee.
  Money get discount => isStage
      ? procedure.discount.split(procedure.totalStages)[stageIndex!]
      : procedure.discount;

  /// Widget key suffix: `<procedureId>` or `<procedureId>-s<k>`.
  String get key => isStage ? '${procedure.id}-s$stageIndex' : procedure.id;
}

/// Billable units of [procedure] reached so far: none unless the status is
/// billable; one whole unit for single-sitting work; for multi-sitting work
/// every stage up to the current one (all stages once completed).
List<BillableStage> reachedStages(ProcedureRecord procedure) {
  if (!procedure.status.isBillable) return const [];
  if (!procedure.isMultiSitting) return [BillableStage(procedure: procedure)];
  final last = procedure.status == ProcedureStatus.completed
      ? procedure.totalStages - 1
      : procedure.stageIndex.clamp(0, procedure.totalStages - 1);
  return [
    for (var k = 0; k <= last; k++)
      BillableStage(procedure: procedure, stageIndex: k),
  ];
}

/// Printed description for a procedure line: name, `stage k of N` (with the
/// stage name when known) for one stage of multi-sitting work, and the teeth
/// when more than one is involved.
String procedureLineDescription(
  ProcedureRecord procedure,
  ToothNotation notation, {
  int? stageIndex,
}) {
  final buffer = StringBuffer(procedure.name);
  if (stageIndex != null) {
    final name = stageIndex < procedure.stageNames.length
        ? procedure.stageNames[stageIndex]
        : '';
    buffer.write(
      ' (stage ${stageIndex + 1} of ${procedure.totalStages}'
      '${name.isEmpty ? '' : ': $name'})',
    );
  }
  if (procedure.teeth.length > 1) {
    buffer.write(' - ${notation.formatAll(procedure.teeth)}');
  }
  return buffer.toString();
}

/// Builds an [InvoiceLine] from a procedure (or one stage of it): fee and
/// discount come from the procedure (split per stage), GST class and SAC/HSN
/// from its catalogue item (exempt health-care when the item is unknown).
InvoiceLine invoiceLineFromProcedure(
  ProcedureRecord procedure, {
  CatalogItem? item,
  required ToothNotation notation,
  int? stageIndex,
  String Function() idGenerator = newId,
}) {
  final unit = BillableStage(procedure: procedure, stageIndex: stageIndex);
  final gstClass = item?.gstClass ?? GstClass.exemptHealthcare;
  return InvoiceLine(
    id: idGenerator(),
    procedureId: procedure.id,
    stageIndex: stageIndex,
    catalogItemId: procedure.catalogItemId,
    description: procedureLineDescription(
      procedure,
      notation,
      stageIndex: stageIndex,
    ),
    tooth: procedure.tooth,
    unitPrice: unit.fee,
    discount: unit.discount,
    gstClass: gstClass,
    sacHsnCode: item?.sacHsnCode ?? gstClass.defaultCode,
  );
}

/// Draft lines for billable units. Completed procedures and reached stages
/// of multi-sitting work are preselected, as are any whose procedure is in
/// [preselectedIds] (the `procedureIds` query parameter); single-sitting work
/// still in progress is offered unselected.
List<InvoiceDraftLine> draftLinesFromStages(
  Iterable<BillableStage> stages, {
  required Map<String, CatalogItem> catalog,
  required ToothNotation notation,
  Set<String> preselectedIds = const {},
  String Function() idGenerator = newId,
}) => [
  for (final s in stages)
    InvoiceDraftLine(
      line: invoiceLineFromProcedure(
        s.procedure,
        item: catalog[s.procedure.catalogItemId],
        notation: notation,
        stageIndex: s.stageIndex,
        idGenerator: idGenerator,
      ),
      selected:
          s.procedure.status == ProcedureStatus.completed ||
          s.isStage ||
          preselectedIds.contains(s.procedure.id),
      catalogGstClass: catalog[s.procedure.catalogItemId]?.gstClass,
      procedure: s.procedure,
    ),
];

/// Draft lines for every reached unit of [procedures] (see
/// [draftLinesFromStages]); nothing is treated as already billed.
List<InvoiceDraftLine> draftLinesFromProcedures(
  Iterable<ProcedureRecord> procedures, {
  required Map<String, CatalogItem> catalog,
  required ToothNotation notation,
  Set<String> preselectedIds = const {},
  String Function() idGenerator = newId,
}) => draftLinesFromStages(
  [for (final p in procedures) ...reachedStages(p)],
  catalog: catalog,
  notation: notation,
  preselectedIds: preselectedIds,
  idGenerator: idGenerator,
);

/// Procedure ids with any line on a non-void invoice.
Set<String> billedProcedureIds(Iterable<Invoice> invoices) => {
  for (final inv in invoices)
    if (inv.status != InvoiceStatus.voided)
      for (final l in inv.lines)
        if (l.procedureId != null) l.procedureId!,
};

/// Billed stages per procedure on non-void invoices; a line without a stage
/// (the whole procedure) is recorded as null.
Map<String, Set<int?>> billedStages(Iterable<Invoice> invoices) {
  final out = <String, Set<int?>>{};
  for (final inv in invoices) {
    if (inv.status == InvoiceStatus.voided) continue;
    for (final l in inv.lines) {
      final id = l.procedureId;
      if (id == null) continue;
      (out[id] ??= {}).add(l.stageIndex);
    }
  }
  return out;
}

/// Reached units of [procedures] not yet billed on a non-void invoice. A
/// whole-procedure line blocks every stage; any billed stage blocks a
/// whole-procedure unit.
List<BillableStage> unbilledStages(
  Iterable<ProcedureRecord> procedures,
  Iterable<Invoice> invoices,
) {
  final billed = billedStages(invoices);
  return [
    for (final p in procedures)
      for (final s in reachedStages(p))
        if (!_isBilled(billed[p.id], s)) s,
  ];
}

bool _isBilled(Set<int?>? billed, BillableStage stage) {
  if (billed == null || billed.isEmpty) return false;
  if (!stage.isStage || billed.contains(null)) return true;
  return billed.contains(stage.stageIndex);
}

/// Applies the clinic's GST rate in force at [at] to every line.
List<InvoiceLine> withGstRates(
  Iterable<InvoiceLine> lines,
  GstRateTable rates,
  DateTime at,
) => [
  for (final l in lines)
    l.copyWith(taxRatePercent: rates.rateFor(l.gstClass, at: at).ratePercent),
];

/// Assembles a draft [Invoice] from the selected lines with totals and the
/// suggested document type, ready for `BillingRepository.saveDraft`. The
/// number is left empty so the repository mints a `DRAFT-` number.
Invoice buildDraftInvoice({
  required String id,
  required String clinicId,
  required String patientId,
  required String issuedBy,
  required Iterable<InvoiceDraftLine> lines,
  required GstRateTable rates,
  required bool clinicGstRegistered,
  required DateTime now,
  String? notes,
}) {
  final selected = [for (final l in lines.where((l) => l.selected)) l.line];
  final rated = withGstRates(selected, rates, now);
  return computeInvoiceTotals(
    Invoice(
      id: id,
      clinicId: clinicId,
      patientId: patientId,
      number: '',
      documentType: suggestDocumentType(
        clinicGstRegistered: clinicGstRegistered,
        lineClasses: rated.map((l) => l.gstClass),
      ),
      issuedAt: now,
      lines: rated,
      notes: notes,
      issuedBy: issuedBy,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// Running balance after each ledger entry (oldest first).
List<(LedgerEntry, Money)> ledgerWithRunningBalance(
  Iterable<LedgerEntry> entries,
) {
  var balance = const Money.zero();
  return [for (final e in entries) (e, balance += e.amount)];
}

/// Patients whose account belongs with [self]: those sharing a guardian
/// phone, the guardian's own record, and the wards of [self] when [self] is
/// the guardian. [self] comes first.
List<Patient> familyMembers(Patient self, Iterable<Patient> all) {
  final guardianPhone = self.guardianPhone;
  final others = <Patient>[];
  for (final p in all) {
    if (p.id == self.id) continue;
    final sharesGuardian =
        guardianPhone != null &&
        guardianPhone.isNotEmpty &&
        (p.guardianPhone == guardianPhone || p.phone == guardianPhone);
    final isWard = p.guardianPhone != null && p.guardianPhone == self.phone;
    if (sharesGuardian || isWard) others.add(p);
  }
  others.sort((a, b) => a.displayName.compareTo(b.displayName));
  return [self, ...others];
}
