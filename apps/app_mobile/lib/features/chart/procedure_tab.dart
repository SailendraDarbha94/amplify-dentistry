import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_mapping.dart';
import 'chart_providers.dart';
import 'chart_strings.dart';
import 'preop_guard.dart';
import 'preop_guard_dialog.dart';
import 'surface_picker.dart';
import 'tooth_sheet.dart';

/// Catalogue items matching a free-text query and optional category.
List<CatalogItem> filterCatalog(
  Iterable<CatalogItem> items,
  String query, {
  ProcedureCategory? category,
}) {
  final q = query.trim().toLowerCase();
  return items.where((i) {
    if (category != null && i.category != category) return false;
    if (q.isEmpty) return true;
    return i.code.toLowerCase().contains(q) ||
        i.name.toLowerCase().contains(q) ||
        i.laymanName.toLowerCase().contains(q);
  }).toList();
}

/// Adds a procedure to the selected tooth from the catalogue: fee
/// prefilled, surfaces from the chart selection, planned or done today, and
/// a stage control for multi-sitting work. The pre-op radiograph guard runs
/// before any `done` status is written.
/// Test keys: `procedure-search`, `procedure-category-<name>`,
/// `procedure-item-<code>`, `procedure-change`, `procedure-fee`,
/// `procedure-status-planned`, `procedure-status-done`, `procedure-stage`,
/// `procedure-note`, `procedure-save`.
class ProcedureTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const ProcedureTab({
    super.key,
    required this.patientId,
    required this.tooth,
    this.surfaces = const SurfaceSet.empty(),
  });

  /// Patient.
  final String patientId;

  /// Tooth.
  final ToothId tooth;

  /// Surfaces selected on the chart.
  final SurfaceSet surfaces;

  @override
  ConsumerState<ProcedureTab> createState() => _ProcedureTabState();
}

class _ProcedureTabState extends ConsumerState<ProcedureTab> {
  String _query = '';
  ProcedureCategory? _category;
  CatalogItem? _item;
  late SurfaceSet _surfaces = widget.surfaces;
  bool _done = false;
  int _stageIndex = 0;
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  void _select(CatalogItem item) => setState(() {
    _item = item;
    _fee.text = item.defaultFee.wholeRupees.toString();
    _stageIndex = 0;
    _error = null;
  });

  ProcedureStatus get _status {
    final item = _item!;
    if (!_done) return ProcedureStatus.planned;
    if (!item.isMultiSitting) return ProcedureStatus.completed;
    return _stageIndex >= item.stages.length - 1
        ? ProcedureStatus.completed
        : ProcedureStatus.inProgress;
  }

  /// Validates and saves. `_saving` is raised synchronously, before the
  /// first await, so a double tap on Save cannot create two procedure rows
  /// while the pre-op radiograph check is loading.
  Future<void> _save() async {
    if (_saving) return;
    final item = _item!;
    final fee = Money.tryParse(_fee.text);
    if (fee == null || fee.isNegative) {
      setState(() => _error = ChartStrings.feeInvalid);
      return;
    }
    if (item.treatmentArea.needsSurfaces && _surfaces.isEmpty) {
      setState(() => _error = ChartStrings.surfacesRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final status = _status;
      final kind = classifyProcedure(item.code, category: item.category);
      var note = _note.text.trim();
      var imageIds = const <String>[];
      if (status != ProcedureStatus.planned) {
        final images = await ref
            .read(clinicalRepositoryProvider)
            .imagesForPatient(widget.patientId);
        final check = checkPreOpRadiograph(
          kind: kind,
          catalogFlag: item.requiresPreOpRadiograph,
          teeth: [widget.tooth],
          images: images,
        );
        imageIds = check.attachedImageIds;
        if (check.blocks) {
          if (!mounted) return;
          final resolution = await PreOpGuardDialog.show(
            context,
            procedureName: item.name,
            candidates: check.candidates,
          );
          if (resolution == null) return;
          imageIds = [...imageIds, ...resolution.imageIds];
          final reason = resolution.reason?.trim() ?? '';
          if (reason.isNotEmpty) note = appendPreOpReason(note, reason);
        }
      }
      if (!mounted) return;
      final result = await ref
          .read(chartServiceProvider)
          .addProcedure(
            patientId: widget.patientId,
            item: item,
            tooth: item.treatmentArea.needsTooth ? widget.tooth : null,
            surfaces: item.treatmentArea.needsSurfaces
                ? _surfaces
                : const SurfaceSet.empty(),
            fee: fee,
            status: status,
            stageIndex: _stageIndex,
            note: note,
            preOpImageIds: imageIds,
          );
      if (!mounted) return;
      Navigator.of(context).pop(ToothSheetResult.forProcedure(result));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) return _buildPicker(context);
    return _buildForm(context, item);
  }

  Widget _buildPicker(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final all = ref.watch(catalogItemsProvider).value ?? const <CatalogItem>[];
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: ChartStrings.catalogueEmpty,
      );
    }
    final items = filterCatalog(all, _query, category: _category);
    final groups = <ProcedureCategory, List<CatalogItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.category, () => []).add(i);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: SearchField(
            key: const ValueKey('procedure-search'),
            hintText: ChartStrings.searchCatalogue,
            debounce: Duration.zero,
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            children: [
              for (final c in ProcedureCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    key: ValueKey('procedure-category-${c.name}'),
                    label: Text(AppFormat.enumLabel(c)),
                    selected: _category == c,
                    onSelected: (_) =>
                        setState(() => _category = _category == c ? null : c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(icon: Icons.search_off, title: s.noResults)
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          AppFormat.enumLabel(entry.key),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      for (final i in entry.value)
                        ListTile(
                          key: ValueKey('procedure-item-${i.code}'),
                          title: Text(i.name),
                          subtitle: Text(i.laymanName),
                          trailing: MoneyText(
                            AppFormat.money(i.defaultFee, showPaise: false),
                          ),
                          onTap: () => _select(i),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, CatalogItem item) {
    final s = context.strings;
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Text(item.name, style: theme.textTheme.titleMedium),
        Text(
          '${item.code} · ${AppFormat.enumLabel(item.category)}',
          style: theme.textTheme.bodySmall,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('procedure-change'),
            onPressed: () => setState(() => _item = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(ChartStrings.chooseAnother),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('procedure-fee'),
          controller: _fee,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ChartStrings.fee,
            helperText:
                '${AppFormat.money(item.feeMin, showPaise: false)} - '
                '${AppFormat.money(item.feeMax, showPaise: false)}',
          ),
        ),
        if (item.treatmentArea.needsSurfaces) ...[
          const FormGap(),
          FormSection(
            title: s.surface,
            children: [
              SurfacePicker(
                tooth: widget.tooth,
                value: _surfaces,
                onChanged: (v) => setState(() => _surfaces = v),
              ),
            ],
          ),
        ],
        const FormGap(),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              key: const ValueKey('procedure-status-planned'),
              label: Text(s.planned),
              selected: !_done,
              onSelected: (_) => setState(() => _done = false),
            ),
            ChoiceChip(
              key: const ValueKey('procedure-status-done'),
              label: Text(ChartStrings.doneToday),
              selected: _done,
              onSelected: (_) => setState(() => _done = true),
            ),
          ],
        ),
        if (_done && item.isMultiSitting) ...[
          const FormGap(),
          DropdownButtonFormField<int>(
            key: const ValueKey('procedure-stage'),
            initialValue: _stageIndex,
            decoration: InputDecoration(labelText: ChartStrings.stageDoneToday),
            items: [
              for (var i = 0; i < item.stages.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    i == item.stages.length - 1
                        ? '${i + 1}. ${item.stages[i]} (${ChartStrings.allStages})'
                        : '${i + 1}. ${item.stages[i]}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _stageIndex = v ?? 0),
          ),
        ],
        const FormGap(),
        TextField(
          key: const ValueKey('procedure-note'),
          controller: _note,
          decoration: InputDecoration(labelText: ChartStrings.noteOptional),
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        BigActionButton(
          key: const ValueKey('procedure-save'),
          label: s.save,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
