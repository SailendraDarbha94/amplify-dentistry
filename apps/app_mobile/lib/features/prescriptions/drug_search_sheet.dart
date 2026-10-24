import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'rx_model.dart';

/// Filters the drug master by generic or brand name and an optional
/// category; the match is case-insensitive and prefix-friendly.
List<Drug> filterDrugs(
  Iterable<Drug> drugs, {
  String query = '',
  String? category,
}) {
  final q = query.trim().toLowerCase();
  return drugs.where((d) {
    if (category != null && d.category != category) return false;
    if (q.isEmpty) return true;
    return d.genericName.toLowerCase().contains(q) ||
        d.brandNames.any((b) => b.toLowerCase().contains(q)) ||
        d.category.toLowerCase().contains(q);
  }).toList()..sort((a, b) => a.genericName.compareTo(b.genericName));
}

/// Distinct categories in display order (most used first).
List<String> drugCategories(Iterable<Drug> drugs) {
  final counts = <String, int>{};
  for (final d in drugs) {
    counts[d.category] = (counts[d.category] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return keys;
}

/// Bottom sheet that searches the drug master. Generic names are shown in
/// capitals with brands, strength, form and schedule tag underneath.
class DrugSearchSheet extends StatefulWidget {
  /// Creates the sheet.
  const DrugSearchSheet({
    super.key,
    required this.drugs,
    this.history,
    this.isMinor = false,
  });

  /// Active drug master.
  final List<Drug> drugs;

  /// Latest history, for allergy and pregnancy markers.
  final MedicalHistory? history;

  /// Patient is under 18.
  final bool isMinor;

  /// Shows the sheet and returns the chosen drug or null.
  static Future<Drug?> show(
    BuildContext context, {
    required List<Drug> drugs,
    MedicalHistory? history,
    bool isMinor = false,
  }) => showModalBottomSheet<Drug>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        DrugSearchSheet(drugs: drugs, history: history, isMinor: isMinor),
  );

  @override
  State<DrugSearchSheet> createState() => _DrugSearchSheetState();
}

class _DrugSearchSheetState extends State<DrugSearchSheet> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final categories = drugCategories(widget.drugs);
    final results = filterDrugs(
      widget.drugs,
      query: _query,
      category: _category,
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: SearchField(
              key: const ValueKey('drug-search'),
              hintText: 'Generic or brand name',
              autofocus: true,
              debounce: Duration.zero,
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.horizontalGutter,
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      key: ValueKey('drug-category-$c'),
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (v) =>
                          setState(() => _category = v ? c : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? EmptyState(icon: Icons.search_off, title: s.noResults)
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final d = results[i];
                      final allergic = allergyConflicts(widget.history, d);
                      final cautions = cautionLabels(
                        drug: d,
                        history: widget.history,
                        isMinor: widget.isMinor,
                      );
                      return ListTile(
                        key: ValueKey('drug-${d.id}'),
                        isThreeLine: cautions.isNotEmpty || allergic,
                        leading: Icon(
                          allergic
                              ? Icons.dangerous_outlined
                              : Icons.medication_outlined,
                          color: allergic ? colors.danger : null,
                        ),
                        title: Text(
                          '${d.genericName.toUpperCase()} ${d.strength}',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${drugFormLabel(d.form)} · '
                              '${d.brandNames.take(3).join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (allergic || cautions.isNotEmpty)
                              Wrap(
                                spacing: AppSpacing.xs,
                                children: [
                                  if (allergic)
                                    const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: StatusBadge(
                                        label: 'Allergy recorded',
                                        tone: BadgeTone.danger,
                                        dense: true,
                                      ),
                                    ),
                                  for (final c in cautions)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: StatusBadge(
                                        label: c,
                                        tone: BadgeTone.warning,
                                        dense: true,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        trailing: d.schedule == DrugSchedule.h1
                            ? const StatusBadge(
                                label: 'H1',
                                tone: BadgeTone.warning,
                                dense: true,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
