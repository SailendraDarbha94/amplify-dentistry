import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compliance_banners.dart';
import 'compliance_providers.dart';
import 'cycle_form_sheet.dart';
import 'licence_form_sheet.dart';
import 'licence_wallet_view.dart';
import 'sterilisation_log_view.dart';

/// Compliance hub: sterilisation register and licence wallet, with alert
/// banners for the weekly spore test and expiring licences.
class CompliancePage extends ConsumerStatefulWidget {
  /// Creates the page opened on [initialTab] (0 sterilisation, 1 licences).
  const CompliancePage({super.key, this.initialTab = 0});

  /// Tab to open first.
  final int initialTab;

  /// Tab titles in order.
  static const List<String> tabTitles = ['Sterilisation', 'Licences'];

  @override
  ConsumerState<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends ConsumerState<CompliancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: CompliancePage.tabTitles.length,
    vsync: this,
    initialIndex: widget.initialTab,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _logCycle() async {
    final ctx = ref.read(actorContextProvider);
    final cycles = ref.read(recentCyclesProvider).value ?? const [];
    final draft = await CycleFormSheet.show(
      context,
      clinicId: ctx.clinicId,
      operatorId: ctx.actorId,
      lastAutoclaveName: cycles.isEmpty ? null : cycles.first.autoclaveName,
      clock: ref.read(clockProvider),
    );
    if (draft == null || !mounted) return;
    final saved = await ref
        .read(complianceRepositoryProvider)
        .recordCycle(ctx, draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cycle ${saved.cycleNumber} logged')),
    );
  }

  Future<void> _addLicence() async {
    final ctx = ref.read(actorContextProvider);
    final draft = await LicenceFormSheet.show(
      context,
      clinicId: ctx.clinicId,
      clock: ref.read(clockProvider),
    );
    if (draft == null || !mounted) return;
    await ref.read(complianceRepositoryProvider).upsertLicence(ctx, draft);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onSterilisation = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final t in CompliancePage.tabTitles)
              Tab(key: ValueKey('compliance-tab-$t'), text: t),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter,
              0,
            ),
            child: ComplianceBanners(
              onSporeTap: () => _tabs.animateTo(0),
              onLicenceTap: () => _tabs.animateTo(1),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [SterilisationLogView(), LicenceWalletView()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: ValueKey(
          onSterilisation ? 'compliance-log-cycle' : 'compliance-add-licence',
        ),
        onPressed: onSterilisation ? _logCycle : _addLicence,
        icon: Icon(onSterilisation ? Icons.add_task : Icons.add),
        label: Text(onSterilisation ? 'Log cycle' : '${s.add} licence'),
      ),
    );
  }
}
