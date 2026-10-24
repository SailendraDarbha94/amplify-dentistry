import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';

final DateTime now = DateTime(2026, 10, 18, 11, 30);

DocumentFonts? _fonts;

/// Fonts read straight from disk (flutter test runs with the package as cwd).
DocumentFonts testFonts() =>
    _fonts ??= DocumentFonts.fromFiles(Directory('assets/fonts'));

DocumentTheme testTheme({DocumentPaper paper = DocumentPaper.a4}) =>
    DocumentTheme(fonts: testFonts(), paper: paper, generatedAt: now);

ToothId t(String fdi) => ToothId.parse(fdi);

final Clinic clinic = Clinic(
  id: 'clinic-1',
  name: 'Smile Dental Care',
  legalName: 'Smile Dental Care LLP',
  addressLines: const ['12-3-456, Road No. 10', 'Banjara Hills'],
  city: 'Hyderabad',
  stateCode: '36',
  pincode: '500034',
  phone: '+91 98765 43210',
  whatsappPhone: '+91 98765 43210',
  email: 'hello@smiledental.example',
  gstin: '36ABCDE1234F1Z5',
  createdAt: now,
  updatedAt: now,
);

/// The same clinic without a GSTIN (exempt-only clinics need not register).
final Clinic unregisteredClinic = Clinic(
  id: clinic.id,
  name: clinic.name,
  addressLines: clinic.addressLines,
  city: clinic.city,
  stateCode: clinic.stateCode,
  pincode: clinic.pincode,
  phone: clinic.phone,
  createdAt: now,
  updatedAt: now,
);

final ClinicMember dentist = ClinicMember(
  id: 'member-1',
  clinicId: clinic.id,
  displayName: 'Priya Sharma',
  role: ClinicRole.ownerDentist,
  registrationNumber: 'A-12345',
  registrationCouncil: 'TSDC',
  qualifications: const ['BDS', 'MDS (Endodontics)'],
  phone: '+91 91234 56789',
  createdAt: now,
  updatedAt: now,
);

final Patient patient = Patient(
  id: 'patient-1',
  clinicId: clinic.id,
  patientNumber: 'P-000123',
  firstName: 'Ravi',
  lastName: 'Kumar',
  phone: '+91 90000 11111',
  dateOfBirth: DateTime(1990, 5, 14),
  sex: Sex.male,
  addressLines: const ['Flat 4B, Lake View Apartments'],
  city: 'Hyderabad',
  pincode: '500081',
  createdAt: now,
  updatedAt: now,
);

InvoiceLine line({
  required String id,
  required String description,
  required Money unitPrice,
  ToothId? tooth,
  GstClass gstClass = GstClass.exemptHealthcare,
  num taxRatePercent = 0,
  Money discount = const Money.zero(),
  int quantity = 1,
}) => InvoiceLine(
  id: id,
  description: description,
  tooth: tooth,
  quantity: quantity,
  unitPrice: unitPrice,
  discount: discount,
  gstClass: gstClass,
  sacHsnCode: gstClass.defaultCode,
  taxRatePercent: taxRatePercent,
);

/// ₹1,000 exempt RCT + ₹2,000 whitening at 18% + ₹500 goods at 5%.
Invoice sampleInvoice({
  InvoiceDocumentType type = InvoiceDocumentType.invoiceCumBillOfSupply,
  String number = 'SDC/26-27/0042',
  Money amountPaid = const Money.rupees(1500),
}) => computeInvoiceTotals(
  Invoice(
    id: 'invoice-1',
    clinicId: clinic.id,
    patientId: patient.id,
    number: number,
    documentType: type,
    status: InvoiceStatus.partiallyPaid,
    issuedAt: now,
    lines: [
      line(
        id: 'l1',
        description: 'Root canal treatment - molar (stage 1/3)',
        tooth: t('46'),
        unitPrice: const Money.rupees(1000),
      ),
      line(
        id: 'l2',
        description: 'In-office teeth whitening',
        unitPrice: const Money.rupees(2000),
        gstClass: GstClass.cosmeticTaxable,
        taxRatePercent: 18,
      ),
      line(
        id: 'l3',
        description: 'Denture adhesive (goods)',
        unitPrice: const Money.rupees(500),
        gstClass: GstClass.goods,
        taxRatePercent: 5,
      ),
    ],
    amountPaid: amountPaid,
    issuedBy: dentist.id,
    createdAt: now,
    updatedAt: now,
  ),
);

/// Exempt-only receipt for an unregistered clinic.
Invoice sampleReceipt() => computeInvoiceTotals(
  Invoice(
    id: 'invoice-2',
    clinicId: clinic.id,
    patientId: patient.id,
    number: 'DRAFT-INV-202610-0007',
    documentType: InvoiceDocumentType.receipt,
    issuedAt: now,
    lines: [
      line(
        id: 'r1',
        description: 'Scaling and polishing',
        unitPrice: const Money.rupees(1500),
      ),
      line(
        id: 'r2',
        description: 'Composite filling',
        tooth: t('36'),
        unitPrice: const Money.rupees(2500),
        discount: const Money.rupees(500),
      ),
    ],
    issuedBy: dentist.id,
    createdAt: now,
    updatedAt: now,
  ),
);

final List<Payment> samplePayments = [
  Payment(
    id: 'pay-1',
    clinicId: clinic.id,
    patientId: patient.id,
    invoiceId: 'invoice-1',
    amount: const Money.rupees(1000),
    method: PaymentMethod.upi,
    reference: 'UPI-REF-8812',
    receivedAt: now,
    receivedBy: 'Reception',
    createdAt: now,
  ),
  Payment(
    id: 'pay-2',
    clinicId: clinic.id,
    patientId: patient.id,
    invoiceId: 'invoice-1',
    amount: const Money.rupees(500),
    method: PaymentMethod.card,
    cardLast4: '4242',
    cardBrand: 'Visa',
    receivedAt: now,
    receivedBy: 'Reception',
    createdAt: now,
  ),
];
