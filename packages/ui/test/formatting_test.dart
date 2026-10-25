import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('IndianPhoneFormat', () {
    test('formats the common Indian inputs', () {
      for (final raw in [
        '9876543210',
        '09876543210',
        '919876543210',
        '+91-98765 43210',
        ' +91 98765 43210 ',
      ]) {
        expect(IndianPhoneFormat.format(raw), '+91 98765 43210', reason: raw);
      }
    });

    test('leaves non-Indian numbers untouched', () {
      expect(IndianPhoneFormat.format('+1 415 555 2671'), '+1 415 555 2671');
      expect(IndianPhoneFormat.format('12345'), '12345');
      expect(IndianPhoneFormat.nationalDigits('12345'), isNull);
    });

    test('validates mobiles by leading digit', () {
      expect(IndianPhoneFormat.isValidMobile('9876543210'), isTrue);
      expect(IndianPhoneFormat.isValidMobile('1234567890'), isFalse);
      expect(IndianPhoneFormat.nationalDigits('+91 98765 43210'), '9876543210');
    });

    testWidgets('PhoneText renders the formatted number', (tester) async {
      await tester.pumpWidget(
        testApp(const PhoneText('9876543210', icon: true)),
      );
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    });
  });

  group('ShortDate and DateChip', () {
    final d = DateTime(2026, 10, 18);
    test('formats dates in English', () {
      expect(ShortDate.dayMonth(d), '18 Oct');
      expect(ShortDate.weekdayDayMonth(d), 'Sun 18 Oct');
      expect(ShortDate.dayMonthYear(d), '18 Oct 2026');
    });

    testWidgets('DateChip shows Today for the current day', (tester) async {
      await tester.pumpWidget(
        testApp(
          Column(
            children: [
              DateChip(date: d, now: d),
              DateChip(
                date: d.add(const Duration(days: 1)),
                now: d,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Mon 19 Oct'), findsOneWidget);
    });
  });

  group('MoneyText', () {
    testWidgets('colours negatives with the error colour', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Column(
            children: [MoneyText('₹1,250.00'), MoneyText('-₹500.00')],
          ),
        ),
      );
      final context = tester.element(find.byType(Column));
      final neg = tester.widget<Text>(find.text('-₹500.00'));
      final pos = tester.widget<Text>(find.text('₹1,250.00'));
      expect(neg.style?.color, Theme.of(context).colorScheme.error);
      expect(pos.style?.color, isNot(Theme.of(context).colorScheme.error));
    });
  });

  group('ToggleChipGroup', () {
    testWidgets('single-select replaces, multi-select accumulates', (
      tester,
    ) async {
      Set<String> selected = {'a'};
      const options = [
        ToggleChipOption(value: 'a', label: 'A'),
        ToggleChipOption(value: 'b', label: 'B'),
      ];
      await tester.pumpWidget(
        testApp(
          ToggleChipGroup<String>(
            options: options,
            selected: selected,
            multiSelect: false,
            onChanged: (s) => selected = s,
          ),
        ),
      );
      await tester.tap(find.text('B'));
      expect(selected, {'b'});

      selected = {'a'};
      await tester.pumpWidget(
        testApp(
          ToggleChipGroup<String>(
            options: options,
            selected: selected,
            onChanged: (s) => selected = s,
          ),
        ),
      );
      await tester.tap(find.text('B'));
      expect(selected, {'a', 'b'});
    });
  });

  group('OfflineBanner and ConfirmSheet', () {
    testWidgets('banner hides when online with nothing pending', (
      tester,
    ) async {
      await tester.pumpWidget(testApp(const OfflineBanner(isOffline: false)));
      expect(find.byType(Material), findsOneWidget); // only the Scaffold's.
      await tester.pumpWidget(
        testApp(const OfflineBanner(isOffline: false, pendingCount: 2)),
      );
      expect(find.text('Not synced yet - 2 changes waiting'), findsOneWidget);
      expect(find.textContaining('Syncing'), findsNothing);
    });

    testWidgets(
      'ConfirmSheet.show resolves true on confirm and false on cancel',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          testApp(
            Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await ConfirmSheet.show(
                    context,
                    title: 'Delete this item?',
                    destructive: true,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(result, isTrue);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      },
    );
  });

  group('AppStrings', () {
    testWidgets('of() falls back to English and honours a scope', (
      tester,
    ) async {
      late AppStrings seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = AppStrings.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.localeCode, 'en');
      expect(seen.pendingChangesCount(3), '3 changes waiting to sync');

      const custom = AppStrings(
        localeCode: 'xx',
        appName: 'x',
        save: 's',
        cancel: 'c',
        next: 'n',
        back: 'b',
        done: 'd',
        confirm: 'c',
        delete: 'd',
        edit: 'e',
        add: 'a',
        close: 'c',
        retry: 'r',
        skip: 's',
        clear: 'c',
        ok: 'o',
        yes: 'y',
        no: 'n',
        patients: 'p',
        patient: 'p',
        newPatient: 'n',
        schedule: 's',
        today: 't',
        appointment: 'a',
        chart: 'c',
        findings: 'f',
        procedures: 'p',
        plan: 'p',
        treatmentPlan: 't',
        estimate: 'e',
        consent: 'c',
        notes: 'n',
        prescription: 'p',
        bill: 'b',
        invoice: 'i',
        payment: 'p',
        receipt: 'r',
        ledger: 'l',
        recall: 'r',
        lab: 'l',
        labCase: 'l',
        settings: 's',
        more: 'm',
        offline: 'o',
        online: 'o',
        syncing: 's',
        synced: 's',
        pendingChanges: 'p',
        notSyncedYet: 'n',
        changeWaiting: 'cw',
        changesWaiting: 'cws',
        syncFailed: 's',
        search: 's',
        searchHint: 's',
        searchPatientsHint: 's',
        noResults: 'n',
        nothingHere: 'n',
        loading: 'l',
        somethingWentWrong: 's',
        tryAgain: 't',
        required: 'r',
        optional: 'o',
        invalidPhone: 'i',
        invalidValue: 'i',
        name: 'n',
        phone: 'p',
        age: 'a',
        gender: 'g',
        dateOfBirth: 'd',
        guardian: 'g',
        address: 'a',
        amount: 'a',
        total: 't',
        discount: 'd',
        gst: 'g',
        paid: 'p',
        due: 'd',
        balance: 'b',
        cash: 'c',
        upi: 'u',
        card: 'c',
        planned: 'p',
        inProgress: 'i',
        completed: 'c',
        existing: 'e',
        accepted: 'a',
        cancelled: 'c',
        overdue: 'o',
        draft: 'd',
        tooth: 't',
        teeth: 't',
        surface: 's',
        selectAll: 's',
        deselectAll: 'd',
        deleteConfirmTitle: 'd',
        deleteConfirmMessage: 'd',
        discardChangesTitle: 'd',
        discardChangesMessage: 'd',
        discard: 'd',
        keepEditing: 'k',
      );
      await tester.pumpWidget(
        AppStringsScope(
          strings: custom,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                seen = AppStrings.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(seen.localeCode, 'xx');
    });
  });
}
