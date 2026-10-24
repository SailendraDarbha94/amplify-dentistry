import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 1);

DataConsent _consent(
  DataPurpose purpose, {
  bool granted = true,
  int dayOffset = 0,
  DateTime? withdrawnAt,
  String id = 'c',
}) => DataConsent(
  id: '$id-${purpose.name}-$dayOffset',
  clinicId: 'clinic',
  patientId: 'patient',
  purpose: purpose,
  granted: granted,
  noticeVersion: 'v1',
  languageCode: 'en',
  channel: 'inClinic',
  grantedAt: _t0.add(Duration(days: dayOffset)),
  withdrawnAt: withdrawnAt,
  createdAt: _t0.add(Duration(days: dayOffset)),
);

SendDecision _decide(
  MessageCategory category,
  List<DataConsent> consents, {
  bool minorRouted = false,
  bool isMinor = false,
  bool implied = false,
}) => OptInPolicy.canSend(
  category: category,
  consents: consents,
  isMinorRoutedToGuardian: minorRouted,
  isMinor: isMinor,
  impliedConsent: implied,
);

void main() {
  final reminders = _consent(DataPurpose.appointmentReminders);
  final records = _consent(DataPurpose.treatmentRecords);
  final marketing = _consent(DataPurpose.marketing);
  final billingOnly = _consent(DataPurpose.billing);

  group('OptInPolicy utility/authentication', () {
    for (final category in [
      MessageCategory.utility,
      MessageCategory.authentication,
    ]) {
      test('$category allowed by appointmentReminders consent', () {
        final d = _decide(category, [reminders]);
        expect(d.allowed, isTrue);
        expect(d.reason, 'appointment_reminders_consent');
      });

      test('$category allowed by treatmentRecords consent', () {
        final d = _decide(category, [records]);
        expect(d.allowed, isTrue);
        expect(d.reason, 'treatment_records_consent');
      });

      test('$category denied with no relevant consent', () {
        expect(_decide(category, const []).allowed, isFalse);
        expect(_decide(category, [billingOnly]).allowed, isFalse);
        expect(_decide(category, [marketing]).allowed, isFalse);
        expect(
          _decide(category, const []).reason,
          'transactional_consent_missing',
        );
      });

      test('$category allowed by implied consent for existing patients', () {
        final d = _decide(category, const [], implied: true);
        expect(d.allowed, isTrue);
        expect(d.reason, 'implied_consent_existing_patient');
      });

      test('$category denied when the consent was declined', () {
        final declined = _consent(
          DataPurpose.appointmentReminders,
          granted: false,
        );
        expect(_decide(category, [declined]).allowed, isFalse);
      });

      test('$category denied when the consent was withdrawn', () {
        final withdrawn = _consent(
          DataPurpose.appointmentReminders,
          withdrawnAt: _t0.add(const Duration(days: 3)),
        );
        expect(_decide(category, [withdrawn]).allowed, isFalse);
      });

      test('$category still allowed for a minor routed to the guardian', () {
        expect(
          _decide(category, [reminders], minorRouted: true).allowed,
          isTrue,
        );
      });
    }
  });

  group('OptInPolicy marketing', () {
    test('requires marketing consent; reminders consent is not enough', () {
      expect(_decide(MessageCategory.marketing, [reminders]).allowed, isFalse);
      expect(
        _decide(MessageCategory.marketing, [reminders]).reason,
        'marketing_consent_missing',
      );
    });

    test('allowed by active marketing consent', () {
      final d = _decide(MessageCategory.marketing, [reminders, marketing]);
      expect(d.allowed, isTrue);
      expect(d.reason, 'marketing_consent');
    });

    test('denied once withdrawn', () {
      final withdrawn = _consent(
        DataPurpose.marketing,
        withdrawnAt: _t0.add(const Duration(days: 10)),
      );
      final d = _decide(MessageCategory.marketing, [withdrawn]);
      expect(d.allowed, isFalse);
      expect(d.reason, 'marketing_consent_withdrawn');
    });

    test('implied consent never covers marketing', () {
      expect(
        _decide(MessageCategory.marketing, const [], implied: true).allowed,
        isFalse,
      );
    });

    test('never sent where a minor is routed to a guardian', () {
      final d = _decide(MessageCategory.marketing, [
        marketing,
      ], minorRouted: true);
      expect(d.allowed, isFalse);
      expect(d.reason, 'marketing_to_minor_forbidden');
    });

    test('newest row wins: later decline overrides earlier grant', () {
      final later = _consent(
        DataPurpose.marketing,
        granted: false,
        dayOffset: 5,
      );
      expect(
        _decide(MessageCategory.marketing, [marketing, later]).allowed,
        isFalse,
      );
      expect(
        _decide(MessageCategory.marketing, [later, marketing]).allowed,
        isFalse,
      );
    });

    test('newest row wins: later grant overrides earlier decline', () {
      final declined = _consent(DataPurpose.marketing, granted: false);
      final regrant = _consent(DataPurpose.marketing, dayOffset: 7);
      expect(
        _decide(MessageCategory.marketing, [declined, regrant]).allowed,
        isTrue,
      );
    });
  });

  group('OptInPolicy service and minors', () {
    test('service replies need no stored consent', () {
      final d = _decide(MessageCategory.service, const []);
      expect(d.allowed, isTrue);
      expect(d.reason, 'service_reply_within_window');
    });

    test('a minor not routed to a guardian is refused in every category', () {
      for (final category in MessageCategory.values) {
        final d = _decide(
          category,
          [reminders, marketing],
          isMinor: true,
          minorRouted: false,
        );
        expect(d.allowed, isFalse, reason: '$category');
        expect(d.reason, 'minor_not_routed_to_guardian');
      }
    });
  });

  group('consent ledger helpers', () {
    test(
      'latestConsentsByPurpose picks newest grantedAt, ties by createdAt',
      () {
        final a = _consent(DataPurpose.marketing, id: 'a');
        final b = DataConsent(
          id: 'b',
          clinicId: 'clinic',
          patientId: 'patient',
          purpose: DataPurpose.marketing,
          granted: false,
          noticeVersion: 'v1',
          languageCode: 'en',
          channel: 'inClinic',
          grantedAt: _t0,
          createdAt: _t0.add(const Duration(seconds: 1)),
        );
        final latest = latestConsentsByPurpose([a, b, reminders]);
        expect(latest[DataPurpose.marketing]!.id, 'b');
        expect(latest[DataPurpose.appointmentReminders]!.id, reminders.id);
        expect(latest.length, 2);
      },
    );

    test('hasActiveConsent', () {
      expect(
        hasActiveConsent([reminders], DataPurpose.appointmentReminders),
        isTrue,
      );
      expect(hasActiveConsent([reminders], DataPurpose.marketing), isFalse);
      expect(hasActiveConsent(const [], DataPurpose.marketing), isFalse);
    });

    test('SendDecision toString', () {
      expect(
        const SendDecision.allow('x').toString(),
        'SendDecision(allow: x)',
      );
      expect(const SendDecision.deny('y').toString(), 'SendDecision(deny: y)');
    });
  });
}
