import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'plan_dialogs.dart';
import 'plan_model.dart';

/// Parses `16, 17, 26` into tooth ids; invalid tokens are skipped.
List<ToothId> parseToothList(String raw) => [
  for (final part in raw.split(RegExp('[,\\s]+')))
    if (part.trim().isNotEmpty && ToothId.tryParse(part.trim()) != null)
      ToothId.parse(part.trim()),
];

/// Adds a line: either from a procedure already planned on the chart, or
/// from the catalogue (asking for teeth when the item needs them). Returns
/// the new line or null.
class PlanAddLineSheet extends StatefulWidget {
  /// Creates the sheet.
  const PlanAddLineSheet({
    super.key,
    required this.editor,
    required this.procedures,
    required this.catalog,
    required this.notation,
    required this.phaseIndex,
  });

  /// Plan being edited (to exclude lines already present).
  final PlanEditor editor;

  /// All procedures of the patient.
  final List<ProcedureRecord> procedures;

  /// Effective catalogue.
  final List<CatalogItem> catalog;

  /// Clinic display notation.
  final ToothNotation notation;

  /// Phase the new line goes into.
  final int phaseIndex;

  /// Shows the sheet.
  static Future<TreatmentPlanLine?> show(
    BuildContext context, {
    required PlanEditor editor,
    required List<ProcedureRecord> procedures,
    required List<CatalogItem> catalog,
    required ToothNotation notation,
    required int phaseIndex,
  }) => showModalBottomSheet<TreatmentPlanLine>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PlanAddLineSheet(
      editor: editor,
      procedures: procedures,
      catalog: catalog,
      notation: notation,
      phaseIndex: phaseIndex,
    ),
  );

  @override
  State<PlanAddLineSheet> createState() => _PlanAddLineSheetState();
}

class _PlanAddLineSheetState extends State<PlanAddLineSheet> {
  String _query = '';

  Map<String, CatalogItem> get _byId => {
    for (final i in widget.catalog) i.id: i,
  };

  List<ProcedureRecord> get _unlinked {
    final used = {
      for (final l in widget.editor.lines)
        if (l.procedureId != null) l.procedureId!,
    };
    return widget.procedures
        .where(
          (p) =>
              (p.status == ProcedureStatus.planned ||
                  p.status == ProcedureStatus.plannedInactive) &&
              !used.contains(p.id) &&
              (p.planId == null || p.planId == widget.editor.plan.id),
        )
        .toList();
  }

  List<CatalogItem> get _matches {
    final q = _query.trim().toLowerCase();
    final items = widget.catalog.where((i) => i.isActive);
    if (q.isEmpty) return items.toList();
    return items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.laymanName.toLowerCase().contains(q) ||
              i.code.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _pickCatalog(CatalogItem item) async {
    ToothId? tooth;
    var teeth = const <ToothId>[];
    if (item.treatmentArea.needsTooth) {
      final raw = await _askTeeth(item);
      if (raw == null) return;
      final parsed = parseToothList(raw);
      if (parsed.length == 1) {
        tooth = parsed.single;
      } else {
        teeth = parsed;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      lineFromCatalogItem(
        item,
        plan: widget.editor.plan,
        tooth: tooth,
        teeth: teeth,
        phaseIndex: widget.phaseIndex,
      ),
    );
  }

  Future<String?> _askTeeth(CatalogItem item) => TextPromptDialog.show(
    context,
    title: item.laymanName,
    labelText: 'Teeth (FDI, comma separated)',
    hintText: '16 or 16, 17',
    keyboardType: TextInputType.number,
    okLabel: context.strings.add,
    fieldKey: const ValueKey('plan-teeth-input'),
    okKey: const ValueKey('plan-teeth-ok'),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final unlinked = _unlinked;
    final byId = _byId;
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Add to ${widget.editor.phases[widget.phaseIndex].name}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            TabBar(
              tabs: [
                Tab(text: 'Planned on chart (${unlinked.length})'),
                const Tab(text: 'Catalogue'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  unlinked.isEmpty
                      ? EmptyState(
                          icon: Icons.grid_on,
                          title: s.nothingHere,
                          message:
                              'Planned procedures from the chart appear here.',
                        )
                      : ListView(
                          children: [
                            for (final p in unlinked)
                              ListTile(
                                key: ValueKey('plan-proc-${p.id}'),
                                title: Text(
                                  byId[p.catalogItemId]?.laymanName ?? p.name,
                                ),
                                subtitle: Text(
                                  [
                                    p.code,
                                    if (p.tooth != null)
                                      widget.notation.format(p.tooth!),
                                    if (p.teeth.isNotEmpty)
                                      widget.notation.formatAll(p.teeth),
                                  ].join('  |  '),
                                ),
                                trailing: MoneyText(
                                  AppFormat.money(p.fee, showPaise: false),
                                ),
                                onTap: () => Navigator.of(context).pop(
                                  lineFromProcedure(
                                    p,
                                    plan: widget.editor.plan,
                                    item: byId[p.catalogItemId],
                                    phaseIndex: widget.phaseIndex,
                                  ),
                                ),
                              ),
                          ],
                        ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: SearchField(
                          key: const ValueKey('plan-catalog-search'),
                          hintText: 'Procedure name or code',
                          debounce: Duration.zero,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _matches.length,
                          itemBuilder: (_, i) {
                            final item = _matches[i];
                            return ListTile(
                              key: ValueKey('plan-catalog-${item.code}'),
                              title: Text(item.laymanName),
                              subtitle: Text(
                                '${item.name}  |  ${item.code}  |  '
                                '${gstClassLabel(item.gstClass)}',
                              ),
                              trailing: MoneyText(
                                AppFormat.money(
                                  item.defaultFee,
                                  showPaise: false,
                                ),
                              ),
                              onTap: () => _pickCatalog(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
