import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'consent_detail_page.dart';
import 'consent_list_page.dart';
import 'consent_new_page.dart';

/// Splits a comma-separated query value into non-empty ids.
List<String> parseIdList(String? raw) => (raw ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// Procedure consent routes: list, new (with `procedureIds`, `template` and
/// `planId` query parameters) and detail. `new` is listed before
/// `:consentId` so the literal segment wins.
final List<RouteBase> consentRoutes = [
  GoRoute(
    path: '/patients/:id/consent',
    builder: (context, state) =>
        ConsentListPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/consent/new',
    builder: (context, state) => ConsentNewPage(
      key: ValueKey(state.uri.toString()),
      patientId: state.pathParameters['id']!,
      procedureIds: parseIdList(state.uri.queryParameters['procedureIds']),
      templateCode: state.uri.queryParameters['template'],
      planId: state.uri.queryParameters['planId'],
    ),
  ),
  GoRoute(
    path: '/patients/:id/consent/:consentId',
    builder: (context, state) => ConsentDetailPage(
      patientId: state.pathParameters['id']!,
      consentId: state.pathParameters['consentId']!,
    ),
  ),
];
