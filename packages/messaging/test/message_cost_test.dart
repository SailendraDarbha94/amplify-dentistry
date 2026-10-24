import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

void main() {
  group('rate card', () {
    test('records the read date and the Oct 2026 India rates', () {
      expect(metaIndiaRateCardReadOn, '2026-10-18');
      expect(utilityRateMicroRupees, 115000); // ₹0.1150
      expect(authenticationRateMicroRupees, 115000); // ₹0.1150
      expect(marketingRateMicroRupees, 863100); // ₹0.8631
      expect(messagingGstPercent, 18);
      expect(rateMicroRupees(MessageCategory.utility), utilityRateMicroRupees);
      expect(
        rateMicroRupees(MessageCategory.marketing),
        marketingRateMicroRupees,
      );
      expect(rateMicroRupees(MessageCategory.service), 0);
    });
  });

  group('estimateCostPaise', () {
    test('1,500 utility messages ≈ ₹203.55 incl. GST', () {
      expect(
        estimateCostPaise(MessageCategory.utility, count: 1500),
        closeTo(20355, 1),
      );
    });

    test('1,500 utility messages ex GST = ₹172.50', () {
      expect(
        estimateCostPaise(
          MessageCategory.utility,
          count: 1500,
          includeGst: false,
        ),
        17250,
      );
    });

    test('single message rounds to the nearest paisa', () {
      // ₹0.115 -> 11.5 paise ex GST, rounds half up to 12.
      expect(estimateCostPaise(MessageCategory.utility, includeGst: false), 12);
      // ₹0.115 × 1.18 = ₹0.1357 -> 14 paise.
      expect(estimateCostPaise(MessageCategory.utility), 14);
      // ₹0.8631 × 1.18 = ₹1.018458 -> 102 paise.
      expect(estimateCostPaise(MessageCategory.marketing), 102);
      expect(
        estimateCostPaise(MessageCategory.marketing, includeGst: false),
        86,
      );
    });

    test('authentication costs the same as utility', () {
      expect(
        estimateCostPaise(MessageCategory.authentication, count: 1500),
        estimateCostPaise(MessageCategory.utility, count: 1500),
      );
    });

    test('1,800 utility messages a month ≈ ₹245 incl. GST (spec figure)', () {
      // 1,800 × ₹0.115 = ₹207 + 18% = ₹244.26
      expect(estimateCostPaise(MessageCategory.utility, count: 1800), 24426);
    });

    test('service and zero counts cost nothing; negatives are rejected', () {
      expect(estimateCostPaise(MessageCategory.service, count: 1000), 0);
      expect(estimateCostPaise(MessageCategory.utility, count: 0), 0);
      expect(
        () => estimateCostPaise(MessageCategory.utility, count: -1),
        throwsArgumentError,
      );
    });

    test('estimateCost returns Money', () {
      expect(
        estimateCost(MessageCategory.utility, count: 1500),
        const Money.paise(20355),
      );
    });
  });
}
