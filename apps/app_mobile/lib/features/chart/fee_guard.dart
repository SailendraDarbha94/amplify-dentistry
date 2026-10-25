import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:flutter/material.dart';

import 'chart_strings.dart';

/// Whether [fee] sits inside the catalogue item's usual range.
bool feeInRange(CatalogItem item, Money fee) =>
    fee >= item.feeMin && fee <= item.feeMax;

/// Asks the clinician to confirm a fee outside the catalogue range, showing
/// the range. Resolves true on `Use this fee`. Test keys: `fee-confirm`,
/// `fee-cancel`.
Future<bool> confirmFeeOutsideRange(
  BuildContext context,
  CatalogItem item,
  Money fee,
) async {
  final s = context.strings;
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: Text(ChartStrings.feeOutsideRangeTitle),
      content: Text(
        '${AppFormat.money(fee, showPaise: false)} is outside '
        '${AppFormat.money(item.feeMin, showPaise: false)} - '
        '${AppFormat.money(item.feeMax, showPaise: false)} for '
        '${item.name}.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('fee-cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          key: const ValueKey('fee-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ChartStrings.feeUseAnyway),
        ),
      ],
    ),
  );
  return ok ?? false;
}
