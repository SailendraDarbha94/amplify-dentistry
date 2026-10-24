import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Invoice, payment and ledger routes (placeholder in this build).
final List<RouteBase> billingRoutes = [
  placeholderRoute(
    '/patients/:id/billing',
    'Billing',
    icon: Icons.receipt_long_outlined,
  ),
  placeholderRoute(
    '/patients/:id/billing/invoice/new',
    'New invoice',
    icon: Icons.receipt_long_outlined,
  ),
  placeholderRoute(
    '/patients/:id/billing/invoice/:invoiceId',
    'Invoice',
    icon: Icons.receipt_long_outlined,
  ),
];
