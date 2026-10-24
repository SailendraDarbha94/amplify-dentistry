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

/// Printed description for a procedure line: name, stage for multi-sitting
/// work, and the teeth when more than one is involved.
String procedureLineDescription(
  ProcedureRecord procedure,
  ToothNotation notation,
) {
  final buffer = StringBuffer(procedure.name);
  if (procedure.isMultiSitting) {
    buffer.write(
      ' (${procedure.stageIndex + 1}/${procedure.totalStages}'
      '${procedure.currentStageName.isEmpty ? '' : ' ${procedure.currentStageName}'})',
    );
  }
  if (procedure.teeth.length > 1) {
    buffer.write(' - ${notation.formatAll(procedure.teeth)}');
  }
  return buffer.toString();
}

/// Builds an [InvoiceLine] from a procedure: fee and discount come from the
/// procedure, GST class and SAC/HSN from its catalogue item (exempt health-
/// care when the item is unknown).
InvoiceLine invoiceLineFromProcedure(
  ProcedureRecord procedure, {
  CatalogItem? item,
  required ToothNotation notation,
  String Function() idGenerator = newId,
}) {
  final gstClass = item?.gstClass ?? GstClass.exemptHealthcare;
  return InvoiceLine(
    id: idGenerator(),
    procedureId: procedure.id,
    catalogItemId: procedure.catalogItemId,
    description: procedureLineDescription(procedure, notation),
    tooth: procedure.tooth,
    unitPrice: procedure.fee,
    discount: procedure.discount,
    gstClass: gstClass,
    sacHsnCode: item?.sacHsnCode ?? gstClass.defaultCode,
  );
}

/// Draft lines for every billable procedure. Completed procedures are
/// preselected, as are any listed in [preselectedIds] (the `procedureIds`
/// query parameter); in-progress work is offered unselected.
List<InvoiceDraftLine> draftLinesFromProcedures(
  Iterable<ProcedureRecord> procedures, {
  required Map<String, CatalogItem> catalog,
  required ToothNotation notation,
  Set<String> preselectedIds = const {},
  String Function() idGenerator = newId,
}) => [
  for (final p in procedures)
    InvoiceDraftLine(
      line: invoiceLineFromProcedure(
        p,
        item: catalog[p.catalogItemId],
        notation: notation,
        idGenerator: idGenerator,
      ),
      selected:
          p.status == ProcedureStatus.completed ||
          preselectedIds.contains(p.id),
      catalogGstClass: catalog[p.catalogItemId]?.gstClass,
      procedure: p,
    ),
];

/// Procedure ids already billed on a non-void invoice.
Set<String> billedProcedureIds(Iterable<Invoice> invoices) => {
  for (final inv in invoices)
    if (inv.status != InvoiceStatus.voided)
      for (final l in inv.lines)
        if (l.procedureId != null) l.procedureId!,
};

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
