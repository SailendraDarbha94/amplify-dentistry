import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_providers.dart';

/// Renders the invoice with [InvoicePdf] and shows it in [PdfPreviewPage]
/// (print and share built in). Fonts, clinic, dentist and payments come from
/// the providers; the render happens once per invoice version.
class InvoicePdfPage extends ConsumerWidget {
  /// Creates the page.
  const InvoicePdfPage({
    super.key,
    required this.patient,
    required this.invoice,
  });

  /// Billed patient.
  final Patient patient;

  /// Invoice to render (totals computed).
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final fonts = ref.watch(documentFontsProvider);
    final clinic = ref.watch(currentClinicProvider);
    final dentist = ref.watch(currentMemberProvider);
    final payments = ref.watch(
      invoicePaymentsProvider((patientId: patient.id, invoiceId: invoice.id)),
    );
    final error = [fonts, clinic, dentist, payments].where((a) => a.hasError);
    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(invoice.number)),
        body: ErrorView(
          message: error.first.error.toString(),
          onRetry: () => ref.invalidate(documentFontsProvider),
        ),
      );
    }
    if (!fonts.hasValue ||
        !clinic.hasValue ||
        !dentist.hasValue ||
        !payments.hasValue) {
      return LoadingScaffold(message: s.loading);
    }
    return PdfPreviewPage(
      title: invoice.number,
      fileName: '${invoice.number}.pdf',
      builder: (_) => renderInvoicePdf(
        fonts: fonts.requireValue,
        clinic: clinic.requireValue,
        dentist: dentist.requireValue,
        patient: patient,
        invoice: invoice,
        payments: payments.requireValue,
      ),
    );
  }
}

/// Builds the invoice PDF bytes.
Future<Uint8List> renderInvoicePdf({
  required DocumentFonts fonts,
  required Clinic clinic,
  required ClinicMember dentist,
  required Patient patient,
  required Invoice invoice,
  List<Payment> payments = const [],
}) => InvoicePdf(
  clinic: clinic,
  dentist: dentist,
  patient: patient,
  invoice: invoice,
  payments: payments,
  theme: DocumentTheme(fonts: fonts),
).build();
