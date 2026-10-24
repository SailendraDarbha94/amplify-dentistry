import 'package:go_router/go_router.dart';

import 'invoice_detail_page.dart';
import 'new_invoice_page.dart';
import 'patient_billing_page.dart';

/// Invoice, payment and ledger routes. `invoice/new` is listed before
/// `invoice/:invoiceId` so the literal segment wins.
final List<RouteBase> billingRoutes = [
  GoRoute(
    path: '/patients/:id/billing',
    builder: (context, state) =>
        PatientBillingPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/billing/invoice/new',
    builder: (context, state) => NewInvoicePage(
      patientId: state.pathParameters['id']!,
      preselectedProcedureIds: parseProcedureIds(
        state.uri.queryParameters['procedureIds'],
      ),
    ),
  ),
  GoRoute(
    path: '/patients/:id/billing/invoice/:invoiceId',
    builder: (context, state) => InvoiceDetailPage(
      patientId: state.pathParameters['id']!,
      invoiceId: state.pathParameters['invoiceId']!,
      openPdf: state.uri.queryParameters['pdf'] == '1',
    ),
  ),
];

/// Splits the comma-separated `procedureIds` query parameter.
Set<String> parseProcedureIds(String? raw) => {
  if (raw != null)
    for (final id in raw.split(','))
      if (id.trim().isNotEmpty) id.trim(),
};
