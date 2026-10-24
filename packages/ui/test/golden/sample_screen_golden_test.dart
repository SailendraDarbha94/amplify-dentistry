import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A representative patient screen built only from ampdent_ui widgets.
class _SampleScreen extends StatelessWidget {
  const _SampleScreen();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AdaptiveScaffold(
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      appBar: AppBar(title: Text(strings.patient)),
      banner: const OfflineBanner(isOffline: true, pendingCount: 3),
      destinations: [
        AdaptiveDestination(
          icon: Icons.people_outline,
          label: strings.patients,
        ),
        AdaptiveDestination(
          icon: Icons.calendar_today_outlined,
          label: strings.schedule,
        ),
        AdaptiveDestination(
          icon: Icons.receipt_long_outlined,
          label: strings.bill,
        ),
        AdaptiveDestination(
          icon: Icons.settings_outlined,
          label: strings.settings,
        ),
      ],
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SearchField(hintText: 'Name, phone or patient ID'),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: 'Ravi Kumar',
            subtitle: '34 y, Male',
            trailing: const StatusBadge(
              label: 'Planned',
              tone: BadgeTone.planned,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledValue(
                  label: 'Phone',
                  value: '',
                  valueWidget: PhoneText('9876543210'),
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: LabeledValue(
                        label: 'Due',
                        value: '',
                        valueWidget: MoneyText(
                          '₹4,500.00',
                          emphasis: MoneyEmphasis.strong,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LabeledValue(
                        label: 'Last visit',
                        value: '12 Oct 2026',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            children: [
              QuickActionTile(
                icon: Icons.grid_on,
                label: strings.chart,
                onTap: () {},
              ),
              QuickActionTile(
                icon: Icons.assignment_outlined,
                label: strings.consent,
                onTap: () {},
                badgeCount: 1,
              ),
              QuickActionTile(
                icon: Icons.receipt_long_outlined,
                label: strings.bill,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ToggleChipGroup<String>(
            options: const [
              ToggleChipOption(value: 'all', label: 'All'),
              ToggleChipOption(value: 'planned', label: 'Planned'),
              ToggleChipOption(value: 'done', label: 'Completed'),
            ],
            selected: const {'planned'},
            onChanged: (_) {},
          ),
          const SizedBox(height: AppSpacing.lg),
          BigActionButton(
            label: strings.save,
            icon: Icons.check,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('sample screen golden at 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _SampleScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/sample_screen.png'),
    );
  });
}
