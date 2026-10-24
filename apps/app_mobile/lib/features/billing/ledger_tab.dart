import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_providers.dart';
import 'billing_strings.dart';
import 'invoice_draft.dart';

/// Ledger with running balance, an aging summary of the patient's open
/// invoices, and a read-only family toggle that merges the ledgers of
/// patients sharing a guardian phone.
class LedgerTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const LedgerTab({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  ConsumerState<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<LedgerTab> {
  bool _family = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final invoices =
        ref.watch(billingInvoicesProvider(widget.patientId)).value ?? const [];
    final now = ref.watch(clockProvider)();
    final aging = agingBuckets(invoices, now);
    final family = ref.watch(familyMembersProvider(widget.patientId)).value;
    final hasFamily = family != null && family.length > 1;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        if (hasFamily)
          SwitchListTile(
            key: const ValueKey('ledger-family-toggle'),
            title: Text(BillingStrings.familyView),
            subtitle: Text(BillingStrings.familyViewHint),
            value: _family,
            onChanged: (v) => setState(() => _family = v),
          ),
        Padding(
          padding: AppSpacing.horizontalGutter,
          child: SectionCard(
            title: BillingStrings.aging,
            child: Row(
              children: [
                for (final key in agingBucketKeys)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          key,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        MoneyText(
                          key: ValueKey('aging-$key'),
                          AppFormat.money(aging[key]!, showPaise: false),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_family && hasFamily)
          _FamilyLedger(patientId: widget.patientId)
        else
          _PatientLedger(patientId: widget.patientId, dueLabel: s.due),
      ],
    );
  }
}

class _PatientLedger extends ConsumerWidget {
  const _PatientLedger({required this.patientId, required this.dueLabel});

  final String patientId;
  final String dueLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(patientLedgerProvider(patientId));
    return ledger.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (entries) {
        if (entries.isEmpty) {
          return EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: BillingStrings.noLedgerEntries,
          );
        }
        final rows = ledgerWithRunningBalance(entries).reversed.toList();
        return Column(
          children: [
            for (final (entry, running) in rows)
              LedgerEntryTile(
                key: ValueKey('ledger-row-${entry.id}'),
                entry: entry,
                runningBalance: running,
              ),
          ],
        );
      },
    );
  }
}

class _FamilyLedger extends ConsumerWidget {
  const _FamilyLedger({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(familyLedgerProvider(patientId));
    return ledger.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (rows) {
        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.family_restroom_outlined,
            title: BillingStrings.noLedgerEntries,
          );
        }
        final withBalance = ledgerWithRunningBalance(rows.map((r) => r.entry))
            .reversed
            .toList();
        final byId = {for (final r in rows) r.entry.id: r.patient};
        return Column(
          children: [
            for (final (entry, running) in withBalance)
              LedgerEntryTile(
                key: ValueKey('family-ledger-row-${entry.id}'),
                entry: entry,
                runningBalance: running,
                patientName: byId[entry.id]?.displayName,
              ),
          ],
        );
      },
    );
  }
}

/// One ledger posting with the balance after it.
class LedgerEntryTile extends StatelessWidget {
  /// Creates the tile.
  const LedgerEntryTile({
    super.key,
    required this.entry,
    required this.runningBalance,
    this.patientName,
  });

  /// The posting.
  final LedgerEntry entry;

  /// Balance after this posting.
  final Money runningBalance;

  /// Shown in family view.
  final String? patientName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCharge = entry.amount > const Money.zero();
    return ListTile(
      minTileHeight: AppSpacing.minTapTarget,
      leading: Icon(switch (entry.entryType) {
        LedgerEntryType.charge => Icons.receipt_long_outlined,
        LedgerEntryType.payment => Icons.payments_outlined,
        LedgerEntryType.adjustment => Icons.tune_outlined,
        LedgerEntryType.refund => Icons.undo_outlined,
      }),
      title: Text(
        entry.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          AppFormat.dateTime(entry.occurredAt),
          BillingStrings.ledgerTypeLabel(entry.entryType),
          ?patientName,
        ].join(' - '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(
            AppFormat.money(entry.amount),
            emphasis: MoneyEmphasis.strong,
            color: isCharge ? null : colors.success,
          ),
          Text(
            '${context.strings.balance} ${AppFormat.money(runningBalance)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
