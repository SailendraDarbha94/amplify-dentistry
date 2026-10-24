import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/export/audit_diff.dart';
import 'package:ampdent_mobile/features/export/audit_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 20, 9);
  AuditEvent event({
    required String id,
    AuditAction action = AuditAction.update,
    String entityType = 'Patient',
    String actorId = 'm1',
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? reason,
    DateTime? at,
  }) => AuditEvent(
    id: id,
    clinicId: 'c',
    actorId: actorId,
    action: action,
    entityType: entityType,
    entityId: 'e-$id',
    before: before,
    after: after,
    reason: reason,
    deviceId: 'dev',
    occurredAt: at ?? t0,
  );

  group('diffSnapshots', () {
    test('lists changed keys only, sorted, skipping updatedAt', () {
      final diff = diffSnapshots(
        {
          'phone': '+911',
          'firstName': 'Asha',
          'tags': ['a'],
          'updatedAt': '1',
        },
        {
          'phone': '+912',
          'firstName': 'Asha',
          'tags': ['a', 'b'],
          'city': 'Hyd',
          'updatedAt': '2',
        },
      );
      expect(diff.map((d) => d.key), ['city', 'phone', 'tags']);
      expect(diff.first.isAdded, isTrue);
      expect(diff[1].before, '+911');
      expect(diff[1].after, '+912');
    });

    test('create lists after fields; delete lists before fields', () {
      expect(diffSnapshots(null, {'a': 1, 'b': null}).map((d) => d.key), ['a']);
      expect(diffSnapshots({'a': 1}, null).single.isRemoved, isTrue);
      expect(diffSnapshots(null, null), isEmpty);
    });

    test('diffValueLabel renders money, nulls and nested values', () {
      expect(diffValueLabel(null), '-');
      expect(diffValueLabel({'paise': 150000}), '₹1500.00');
      expect(diffValueLabel({'paise': 5}), '₹0.05');
      expect(diffValueLabel(['x', 1]), '["x",1]');
      expect(diffValueLabel(''), '""');
      expect(diffValueLabel(true), 'true');
    });
  });

  group('AuditFilter', () {
    final events = [
      event(id: '1', entityType: 'Patient', actorId: 'm1'),
      event(id: '2', entityType: 'Invoice', actorId: 'm2'),
      event(
        id: '3',
        entityType: 'Invoice',
        actorId: 'm1',
        action: AuditAction.create,
      ),
      event(id: '4', at: DateTime.utc(2026, 1, 1)),
    ];
    final filter = AuditFilter(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );

    test('range only', () {
      expect(filter.apply(events).map((e) => e.id), ['1', '2', '3']);
      expect(filter.hasNarrowing, isFalse);
    });

    test('entity, actor and action narrow; clearFilterField resets', () {
      final f = filter.copyWith(entityType: 'Invoice');
      expect(f.apply(events).map((e) => e.id), ['2', '3']);
      final g = f.copyWith(actorId: 'm1');
      expect(g.apply(events).map((e) => e.id), ['3']);
      final h = g.copyWith(action: AuditAction.update);
      expect(h.apply(events), isEmpty);
      final cleared = h.copyWith(entityType: null, actorId: null, action: null);
      expect(cleared.hasNarrowing, isFalse);
      expect(cleared.apply(events).length, 3);
      expect(distinctEntityTypes(events), ['Invoice', 'Patient']);
    });

    test('recent covers the last 30 days up to the end of today', () {
      final f = AuditFilter.recent(DateTime(2026, 10, 25, 15));
      expect(f.to, DateTime(2026, 10, 26));
      expect(f.from, DateTime(2026, 9, 25));
    });
  });

  group('auditCsv', () {
    test('escapes commas, quotes and newlines', () {
      expect(csvEscape('plain'), 'plain');
      expect(csvEscape('a,b'), '"a,b"');
      expect(csvEscape('say "hi"'), '"say ""hi"""');
      expect(csvEscape('line\nbreak'), '"line\nbreak"');
    });

    test('writes a header and one row per event with changed fields', () {
      final csv = auditCsv(
        [
          event(
            id: '1',
            before: {'phone': '+911', 'name': 'A, B'},
            after: {'phone': '+912', 'name': 'A, B'},
            reason: 'typo',
          ),
          event(id: '2', action: AuditAction.export, entityType: 'Clinic'),
        ],
        actorNames: const {'m1': 'Dr. Rao'},
      );
      final lines = csv.trim().split('\n');
      expect(lines.length, 3);
      expect(lines.first, auditCsvHeaders.join(','));
      expect(
        lines[1],
        contains(
          '2026-10-20T09:00:00.000Z,update,Patient,e-1,Dr. Rao,m1,dev,typo,phone,',
        ),
      );
      expect(lines[1], contains('"{""name"":""A, B"",""phone"":""+911""}"'));
      expect(
        lines[2],
        startsWith(
          '2026-10-20T09:00:00.000Z,export,Clinic,e-2,Dr. Rao,m1,dev,,,,',
        ),
      );
      expect(auditActionLabel(AuditAction.softDelete), 'Deleted');
    });
  });
}
