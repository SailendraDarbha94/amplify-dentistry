/// Billing, recall, messaging and compliance fixtures shared by the
/// repository tests.
library;

import 'package:ampdent_core/ampdent_core.dart';

import 'helpers.dart';

InvoiceLine invoiceLine({
  String id = 'il-1',
  String description = 'Root canal (back tooth)',
  Money unitPrice = const Money.rupees(5000),
  Money discount = const Money.zero(),
  GstClass gstClass = GstClass.exemptHealthcare,
  String sac = '999312',
}) => InvoiceLine(
  id: id,
  procedureId: 'proc-1',
  catalogItemId: 'cat-1',
  description: description,
  tooth: ToothId.parse('36'),
  unitPrice: unitPrice,
  discount: discount,
  gstClass: gstClass,
  sacHsnCode: sac,
);

Invoice draftInvoice({
  String id = 'inv-1',
  String number = '',
  List<InvoiceLine>? lines,
  DateTime? issuedAt,
}) => Invoice(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  number: number,
  documentType: InvoiceDocumentType.receipt,
  issuedAt: issuedAt ?? t0,
  lines:
      lines ??
      [
        invoiceLine(),
        invoiceLine(
          id: 'il-2',
          description: 'Teeth whitening',
          unitPrice: const Money.rupees(10000),
          gstClass: GstClass.cosmeticTaxable,
          sac: '999722',
        ),
      ],
  notes: 'Thank you',
  issuedBy: dentistId,
  createdAt: t0,
  updatedAt: t0,
);

Payment payment({
  String id = 'pay-1',
  String? invoiceId = 'inv-1',
  Money amount = const Money.rupees(6800),
  bool isRefund = false,
  DateTime? receivedAt,
}) => Payment(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  invoiceId: invoiceId,
  amount: amount,
  method: PaymentMethod.upi,
  reference: 'UTR123',
  gatewayToken: 'tok',
  cardLast4: '4242',
  cardBrand: 'RuPay',
  receivedAt: receivedAt ?? t1,
  receivedBy: dentistId,
  isRefund: isRefund,
  note: 'paid at desk',
  createdAt: receivedAt ?? t1,
);

Adjustment adjustment({String id = 'adj-1'}) => Adjustment(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  invoiceId: 'inv-1',
  type: AdjustmentType.discount,
  amount: const Money.rupees(500),
  reason: 'Senior citizen',
  approvedBy: dentistId,
  createdAt: t2,
);

Recall recall({
  String id = 'recall-1',
  DateTime? dueAt,
  RecallStatus status = RecallStatus.due,
  RecallType type = RecallType.hygiene,
  Money value = const Money.rupees(1500),
}) => Recall(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  type: type,
  triggeredByProcedureId: 'proc-1',
  dueAt: dueAt ?? t0,
  interval: RecallInterval.sixMonths,
  status: status,
  lastNotifiedAt: null,
  estimatedValue: value,
  note: 'recall note',
  createdAt: t0,
  updatedAt: t0,
);

MessageLog message({String id = 'msg-1'}) => MessageLog(
  id: id,
  clinicId: clinicId,
  patientId: patientId,
  channel: MessageChannel.whatsapp,
  category: MessageCategory.utility,
  templateCode: 'appt_reminder_24h',
  toPhone: '9000000004',
  variables: const {'name': 'Anil', 'time': '9:00'},
  renderedPreview: 'Reminder: appointment tomorrow at 9:00',
  costPaise: 12,
  createdAt: t0,
);

SterilisationCycle cycle({String id = 'cyc-1', String number = 'SC-00001'}) =>
    SterilisationCycle(
      id: id,
      clinicId: clinicId,
      cycleNumber: number,
      autoclaveName: 'Autoclave A',
      cycledAt: t0,
      cycleType: SterilisationCycleType.classB,
      temperatureC: 134,
      pressureKpa: 210,
      durationMinutes: 18,
      biologicalIndicatorResult: BiologicalIndicatorResult.pass,
      loadContents: 'Handpieces',
      operatorId: dentistId,
      note: 'ok',
      createdAt: t0,
    );

Licence licence({String id = 'lic-1', DateTime? expiresAt}) => Licence(
  id: id,
  clinicId: clinicId,
  kind: LicenceKind.aerbRegistration,
  identifier: 'AERB-1',
  authority: 'AERB',
  issuedAt: DateTime.utc(2025, 1, 1),
  expiresAt: expiresAt ?? DateTime.utc(2027, 1, 1),
  qaDueAt: DateTime.utc(2026, 12, 1),
  documentPath: '/docs/aerb.pdf',
  note: 'licence note',
  createdAt: t0,
  updatedAt: t0,
);
