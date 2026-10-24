import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/compliance/compliance_rules.dart';
import 'package:ampdent_mobile/features/compliance/sterilisation_log_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));
  final now = DateTime(2026, 10, 25, 9);
  final t = DateTime.utc(2026, 10, 1);

  SterilisationCycle cycle(
    String id,
    DateTime at, {
    BiologicalIndicatorResult? bi,
    bool ci = true,
  }) => SterilisationCycle(
    id: id,
    clinicId: 'c',
    cycleNumber: 'SC-$id',
    autoclaveName: 'Autoclave 1',
    cycledAt: at,
    cycleType: SterilisationCycleType.classB,
    temperatureC: 134,
    pressureKpa: 210,
    durationMinutes: 4,
    chemicalIndicatorPassed: ci,
    biologicalIndicatorResult: bi,
    operatorId: 'd',
    createdAt: t,
  );

  Licence licence(String id, {DateTime? expiresAt, DateTime? qaDueAt}) =>
      Licence(
        id: id,
        clinicId: 'c',
        kind: LicenceKind.aerbRegistration,
        identifier: 'AERB/123',
        expiresAt: expiresAt,
        qaDueAt: qaDueAt,
        createdAt: t,
        updatedAt: t,
      );

  group('sporeTestOverdue', () {
    test('is true when no spore test was ever recorded', () {
      expect(sporeTestOverdue(const [], now), isTrue);
      expect(
        sporeTestOverdue([
          cycle('1', now.subtract(const Duration(days: 1))),
        ], now),
        isTrue,
      );
      expect(
        sporeTestOverdue([
          cycle(
            '1',
            now.subtract(const Duration(days: 1)),
            bi: BiologicalIndicatorResult.notDone,
          ),
        ], now),
        isTrue,
      );
    });

    test('is false within 7 days of the last test and true after 8', () {
      final recent = [
        cycle(
          '1',
          now.subtract(const Duration(days: 6)),
          bi: BiologicalIndicatorResult.pass,
        ),
      ];
      expect(sporeTestOverdue(recent, now), isFalse);
      final stale = [
        cycle(
          '1',
          now.subtract(const Duration(days: 8)),
          bi: BiologicalIndicatorResult.pass,
        ),
        cycle('2', now.subtract(const Duration(days: 2))),
      ];
      expect(sporeTestOverdue(stale, now), isTrue);
      expect(lastSporeTestAt(stale), now.subtract(const Duration(days: 8)));
    });

    test('a pending test counts as run; a failed last test is flagged', () {
      final pending = [
        cycle(
          '1',
          now.subtract(const Duration(days: 1)),
          bi: BiologicalIndicatorResult.pending,
        ),
      ];
      expect(sporeTestOverdue(pending, now), isFalse);
      expect(lastSporeTestFailed(pending), isFalse);
      final failed = [
        cycle(
          '1',
          now.subtract(const Duration(days: 3)),
          bi: BiologicalIndicatorResult.pass,
        ),
        cycle(
          '2',
          now.subtract(const Duration(days: 1)),
          bi: BiologicalIndicatorResult.fail,
        ),
      ];
      expect(lastSporeTestFailed(failed), isTrue);
    });
  });

  group('licence alerts', () {
    test('levels by expiry and QA due', () {
      expect(licenceAlertLevel(licence('a'), now), LicenceAlertLevel.none);
      expect(
        licenceAlertLevel(
          licence('b', expiresAt: now.add(const Duration(days: 200))),
          now,
        ),
        LicenceAlertLevel.ok,
      );
      expect(
        licenceAlertLevel(
          licence('c', expiresAt: now.add(const Duration(days: 60))),
          now,
        ),
        LicenceAlertLevel.expiringSoon,
      );
      expect(
        licenceAlertLevel(
          licence('d', expiresAt: now.subtract(const Duration(days: 1))),
          now,
        ),
        LicenceAlertLevel.expired,
      );
      expect(
        licenceAlertLevel(
          licence(
            'e',
            expiresAt: now.add(const Duration(days: 400)),
            qaDueAt: now.add(const Duration(days: 30)),
          ),
          now,
        ),
        LicenceAlertLevel.expiringSoon,
      );
    });

    test('licencesNeedingAttention sorts soonest first', () {
      final list = licencesNeedingAttention([
        licence('far', expiresAt: now.add(const Duration(days: 365))),
        licence('soon', expiresAt: now.add(const Duration(days: 45))),
        licence('past', expiresAt: now.subtract(const Duration(days: 5))),
        licence('none'),
      ], now);
      expect(list.map((l) => l.id), ['past', 'soon']);
      expect(licenceDaysToDue(list.first, now), -5);
    });

    test('complianceAlertCount adds the spore test to licence alerts', () {
      expect(
        complianceAlertCount(
          cycles: const [],
          licences: [
            licence('soon', expiresAt: now.add(const Duration(days: 10))),
          ],
          now: now,
        ),
        2,
      );
      expect(
        complianceAlertCount(
          cycles: [
            cycle(
              '1',
              now.subtract(const Duration(days: 1)),
              bi: BiologicalIndicatorResult.pass,
            ),
          ],
          licences: const [],
          now: now,
        ),
        0,
      );
    });
  });

  test('sterilisationLogText lists every cycle of the month', () {
    final clinic = Clinic(
      id: 'c',
      name: 'Smile Dental',
      city: 'Hyderabad',
      stateCode: '36',
      pincode: '500034',
      phone: '+919000000001',
      createdAt: t,
      updatedAt: t,
    );
    final cycles = cyclesInMonth(
      [
        cycle(
          '2',
          DateTime(2026, 10, 3, 9),
          bi: BiologicalIndicatorResult.pass,
        ),
        cycle('1', DateTime(2026, 10, 2, 9), ci: false),
        cycle('9', DateTime(2026, 9, 30, 9)),
      ],
      2026,
      10,
    );
    expect(cycles.map((c) => c.id), ['1', '2']);
    final text = sterilisationLogText(
      clinic: clinic,
      year: 2026,
      month: 10,
      cycles: cycles,
      operatorNames: const {'d': 'Dr. Rao'},
      generatedAt: now,
    );
    expect(text, contains('STERILISATION REGISTER - October 2026'));
    expect(text, contains('SC-1'));
    expect(text, contains('SC-2'));
    expect(text, contains('FAIL'));
    expect(text, contains('Dr. Rao'));
    expect(text, contains('Spore tests: 1'));
    expect(sterilisationLogFileName(2026, 3), 'sterilisation-log-2026-03.txt');
  });
}
