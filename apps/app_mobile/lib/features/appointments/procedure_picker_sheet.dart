import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appointment_form_model.dart';
import 'appointment_providers.dart';

/// Bottom sheet listing the patient's planned procedures first and a
/// catalogue search below. Resolves with the chosen [PlannedWork] or null.
class ProcedurePickerSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ProcedurePickerSheet({
    super.key,
    this.patientId,
    this.alreadyChosen = const {},
  });

  /// Patient whose planned procedures are offered (none when null).
  final String? patientId;

  /// Procedure ids / catalogue codes already on the draft, shown ticked.
  final Set<String> alreadyChosen;

  /// Shows the sheet.
  static Future<PlannedWork?> show(
    BuildContext context, {
    String? patientId,
    Set<String> alreadyChosen = const {},
  }) => showModalBottomSheet<PlannedWork>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ProcedurePickerSheet(
      patientId: patientId,
      alreadyChosen: alreadyChosen,
    ),
  );

  @override
  ConsumerState<ProcedurePickerSheet> createState() =>
      _ProcedurePickerSheetState();
}

class _ProcedurePickerSheetState extends ConsumerState<ProcedurePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final notation = ref.watch(notationProvider);
    final catalogue = ref.watch(catalogByIdProvider).value ?? const {};
    final planned = widget.patientId == null
        ? const AsyncValue<List<ProcedureRecord>>.data([])
        : ref.watch(plannedProceduresProvider(widget.patientId!));
    final search = ref.watch(catalogSearchProvider(_query.trim()));
    final plannedList = planned.value ?? const <ProcedureRecord>[];
    final showPlanned = _query.trim().isEmpty && plannedList.isNotEmpty;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.horizontalGutter,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.procedures,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.horizontalGutter,
            child: SearchField(
              key: const ValueKey('procedure-search'),
              hintText: 'Search the catalogue',
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              children: [
                if (showPlanned) ...[
                  _Header(s.planned),
                  for (final p in plannedList)
                    _WorkTile(
                      key: ValueKey('procedure-planned-${p.id}'),
                      work: PlannedWork.fromProcedure(
                        p,
                        notation: notation,
                        catalogItem: catalogue[p.catalogItemId],
                      ),
                      chosen: widget.alreadyChosen.contains(p.id),
                      badge: p.status.name,
                    ),
                  _Header('Catalogue'),
                ],
                ...search.when(
                  loading: () => const [
                    Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [ErrorView(message: e.toString())],
                  data: (items) => items.isEmpty
                      ? [
                          EmptyState(
                            icon: Icons.medical_services_outlined,
                            title: s.noResults,
                          ),
                        ]
                      : [
                          for (final item in items)
                            _WorkTile(
                              key: ValueKey('procedure-catalog-${item.code}'),
                              work: PlannedWork.fromCatalog(item),
                              chosen: widget.alreadyChosen.contains(item.code),
                              badge: item.code,
                            ),
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.xs,
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    super.key,
    required this.work,
    required this.chosen,
    required this.badge,
  });

  final PlannedWork work;
  final bool chosen;
  final String badge;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(chosen ? Icons.check_circle : Icons.add_circle_outline),
    title: Text(work.label),
    subtitle: Text('${work.durationMinutes} min · $badge'),
    enabled: !chosen,
    onTap: chosen ? null : () => Navigator.of(context).pop(work),
  );
}
