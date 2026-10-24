import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Bottom sheet that searches the ICD-10 K00-K14 oral codes. Shows the
/// categories until a query is typed.
class Icd10PickerSheet extends StatefulWidget {
  /// Creates the sheet.
  const Icd10PickerSheet({super.key});

  /// Shows the sheet and returns the chosen code or null.
  static Future<Icd10Code?> show(BuildContext context) =>
      showModalBottomSheet<Icd10Code>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const Icd10PickerSheet(),
      );

  @override
  State<Icd10PickerSheet> createState() => _Icd10PickerSheetState();
}

class _Icd10PickerSheetState extends State<Icd10PickerSheet> {
  String _query = '';
  String? _category;

  List<Icd10Code> get _results {
    if (_query.trim().isNotEmpty) return searchIcd10(_query);
    if (_category != null) return icd10Children(_category!);
    return icd10OralCodes.where((c) => c.isCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final results = _results;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (_category != null && _query.isEmpty)
                  IconButton(
                    tooltip: s.back,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _category = null),
                  ),
                Expanded(
                  child: SearchField(
                    key: const ValueKey('icd10-search'),
                    hintText: 'ICD-10 code or diagnosis',
                    autofocus: true,
                    debounce: Duration.zero,
                    onChanged: (q) => setState(() => _query = q),
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
                      final code = results[i];
                      final drillable =
                          code.isCategory &&
                          _query.isEmpty &&
                          icd10Children(code.code).isNotEmpty;
                      return ListTile(
                        key: ValueKey('icd10-${code.code}'),
                        leading: SizedBox(
                          width: 56,
                          child: Text(
                            code.code,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        title: Text(code.description),
                        trailing: drillable
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: () => drillable
                            ? setState(() => _category = code.code)
                            : Navigator.of(context).pop(code),
                        onLongPress: () => Navigator.of(context).pop(code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
