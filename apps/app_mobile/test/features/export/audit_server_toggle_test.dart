import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/features/export/audit_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feature_harness.dart';

/// The audit viewer hides the server's own trigger rows (`device_id =
/// 'server'`) unless "Include server entries" is on.
void main() {
  group('AuditFilter.includeServer', () {
    final now = DateTime(2026, 10, 20, 9);
    final filter = AuditFilter.recent(now);
    AuditEvent event(String deviceId) => AuditEvent(
      id: 'e-$deviceId',
      clinicId: testClinicId,
      actorId: testDentistId,
      action: AuditAction.update,
      entityType: 'Patient',
      entityId: testPatientId,
      deviceId: deviceId,
      occurredAt: now,
    );

    test('is off by default and drops server rows only', () {
      expect(filter.includeServer, isFalse);
      expect(filter.matches(event('phone-1')), isTrue);
      expect(filter.matches(event(serverAuditDeviceId)), isFalse);
      final on = filter.copyWith(includeServer: true);
      expect(on.matches(event(serverAuditDeviceId)), isTrue);
      expect(on.copyWith(entityType: 'Chair').includeServer, isTrue);
    });
  });

  group('audit page', () {
    late FeatureTestEnv env;

    setUp(() async {
      env = await FeatureTestEnv.open(withPatient: true);
      await env.repos.audit.append(
        const ActorContext(
          clinicId: testClinicId,
          actorId: 'server-trigger',
          deviceId: serverAuditDeviceId,
        ),
        action: AuditAction.update,
        entityType: 'Patient',
        entityId: testPatientId,
        reason: 'server trigger row pulled by sync',
      );
    });
    tearDown(() => env.close());

    testWidgets('server rows appear only with the toggle on', (tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/audit');
      await settle(tester, frames: 10);
      final toggle = find.byKey(const ValueKey('audit-include-server'));
      expect(toggle, findsOneWidget);
      expect(find.textContaining('server-trigger'), findsNothing);

      await tester.tap(toggle);
      await settle(tester, frames: 10);
      expect(find.textContaining('server-trigger'), findsOneWidget);

      await tester.tap(toggle);
      await settle(tester, frames: 10);
      expect(find.textContaining('server-trigger'), findsNothing);
    });
  });
}
