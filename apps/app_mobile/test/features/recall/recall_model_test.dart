import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/recall/recall_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feature_harness.dart';

void main() {
  final now = harnessNow;

  group('groupRecalls', () {
    test('buckets by local day and sums each group value', () {
      final recalls = [
        recallFixture(
          id: 'o1',
          dueAt: now.subtract(const Duration(days: 5)),
          value: const Money.rupees(1500),
        ),
        recallFixture(
          id: 'o2',
          dueAt: now.subtract(const Duration(days: 1)),
          value: const Money.rupees(500),
          type: RecallType.review,
        ),
        recallFixture(
          id: 't1',
          dueAt: DateTime(2026, 10, 21, 17),
          value: const Money.rupees(800),
        ),
        recallFixture(
          id: 'u1',
          dueAt: now.add(const Duration(days: 10)),
          value: const Money.rupees(2000),
        ),
        recallFixture(
          id: 'done',
          dueAt: now.subtract(const Duration(days: 2)),
          status: RecallStatus.completed,
          value: const Money.rupees(9999),
        ),
      ];
      final groups = groupRecalls(recalls, now);
      expect(groups[RecallGroup.overdue]!.map((r) => r.id), ['o1', 'o2']);
      expect(groups[RecallGroup.dueToday]!.map((r) => r.id), ['t1']);
      expect(groups[RecallGroup.upcoming]!.map((r) => r.id), ['u1']);
      expect(
        recallGroupValue(groups[RecallGroup.overdue]!),
        const Money.rupees(2000),
      );
      expect(
        recallGroupValue(groups[RecallGroup.dueToday]!),
        const Money.rupees(800),
      );
      expect(
        recallGroupValue(groups[RecallGroup.upcoming]!),
        const Money.rupees(2000),
      );
      expect(recallGroupValue(const <Recall>[]), const Money.zero());
    });

    test('midnight boundaries: 00:00 today is due today, 23:59 yesterday is overdue', () {
      final groups = groupRecalls([
        recallFixture(id: 'a', dueAt: DateTime(2026, 10, 21)),
        recallFixture(id: 'b', dueAt: DateTime(2026, 10, 20, 23, 59)),
        recallFixture(id: 'c', dueAt: DateTime(2026, 10, 22)),
      ], now);
      expect(groups[RecallGroup.dueToday]!.single.id, 'a');
      expect(groups[RecallGroup.overdue]!.single.id, 'b');
      expect(groups[RecallGroup.upcoming]!.single.id, 'c');
    });
  });

  test('filterRecallsByType keeps everything for an empty filter', () {
    final recalls = [
      recallFixture(id: 'h', dueAt: now, type: RecallType.hygiene),
      recallFixture(id: 'r', dueAt: now, type: RecallType.review),
    ];
    expect(filterRecallsByType(recalls, const {}), hasLength(2));
    expect(
      filterRecallsByType(recalls, const {RecallType.review}).single.id,
      'r',
    );
  });

  test('template code follows the group', () {
    expect(recallTemplateCode(RecallGroup.overdue), 'RECALL_OVERDUE');
    expect(recallTemplateCode(RecallGroup.dueToday), 'RECALL_DUE');
    expect(recallTemplateCode(RecallGroup.upcoming), 'RECALL_DUE');
  });

  test('every recall type has a label', () {
    for (final t in RecallType.values) {
      expect(recallTypeLabel(t), isNotEmpty);
    }
  });
}
