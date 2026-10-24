# ampdent_documents

On-device PDF generation for the AmpDent dental platform, built on `pdf` and
`printing`.

Documents: invoice / receipt / tax invoice / invoice-cum-bill of supply,
versioned estimate, prescription (Rx with QR verification), procedure consent,
lab slip and the 72-hour patient record copy.

Every document prints the clinic letterhead, the dentist's name,
qualifications and `Reg. No.` (DCI Code 3.4.1), page numbers, a generated-at
timestamp and a SHA-256 document hash of the content model.

Fonts: Noto Sans (Regular, Bold) plus Noto Sans Devanagari and Telugu as
fallbacks, under the SIL Open Font License (`assets/fonts/LICENSE-OFL.txt`).

```dart
final fonts = await DocumentFonts.load();
final theme = DocumentTheme(fonts: fonts);
final bytes = await InvoicePdf(
  clinic: clinic, dentist: dentist, patient: patient, invoice: invoice,
  payments: payments, theme: theme,
).build();
await printPdf(bytes, name: invoice.number);
```
