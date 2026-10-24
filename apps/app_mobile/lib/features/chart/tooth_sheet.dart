import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_mapping.dart';
import 'chart_service.dart';
import 'chart_strings.dart';
import 'finding_tab.dart';
import 'procedure_tab.dart';
import 'tooth_history_tab.dart';
import 'tooth_state_tab.dart';

/// Tabs of the tooth sheet.
enum ToothSheetTab { finding, procedure, state, history }

/// What a tab reports back when it saved something.
class ToothSheetResult {
  /// Creates a result with a snackbar [message].
  const ToothSheetResult(this.message, {this.procedure, this.recall});

  /// Result for a procedure write.
  factory ToothSheetResult.forProcedure(MarkDoneResult result) {
    final p = result.procedure;
    final message = result.completed
        ? ChartStrings.procedureCompleted
        : (p.status == ProcedureStatus.inProgress
              ? ChartStrings.stageAdvanced
              : '${p.name} planned');
    return ToothSheetResult(message, procedure: p, recall: result.recall);
  }

  /// Snackbar text.
  final String message;

  /// Procedure created or updated, when any.
  final ProcedureRecord? procedure;

  /// Recall created, when any.
  final Recall? recall;
}

/// Modal sheet for one tooth: add a finding, add a procedure, change the
/// tooth state or read its history.
class ToothSheet extends ConsumerWidget {
  /// Creates the sheet.
  const ToothSheet({
    super.key,
    required this.patientId,
    required this.tooth,
    this.surfaces = const SurfaceSet.empty(),
    this.initialTab = ToothSheetTab.finding,
  });

  /// Patient whose chart this is.
  final String patientId;

  /// Selected tooth.
  final ToothId tooth;

  /// Surfaces selected on the chart, prefilled into the forms.
  final SurfaceSet surfaces;

  /// Tab shown first.
  final ToothSheetTab initialTab;

  /// Opens the sheet over the whole app (covering the bottom bar) and
  /// resolves with the saved result, or null when dismissed.
  static Future<ToothSheetResult?> show(
    BuildContext context, {
    required String patientId,
    required ToothId tooth,
    SurfaceSet surfaces = const SurfaceSet.empty(),
    ToothSheetTab initialTab = ToothSheetTab.finding,
  }) => showModalBottomSheet<ToothSheetResult>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ToothSheet(
      patientId: patientId,
      tooth: tooth,
      surfaces: surfaces,
      initialTab: initialTab,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final notation = ref.watch(notationProvider);
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: height,
        child: DefaultTabController(
          length: ToothSheetTab.values.length,
          initialIndex: initialTab.index,
          child: Column(
            children: [
              Padding(
                padding: AppSpacing.horizontalGutter,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.tooth} '
                        '${describeToothSurfaces(tooth, surfaces, notation)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('tooth-sheet-close'),
                      tooltip: s.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  Tab(text: ChartStrings.addFinding),
                  Tab(text: ChartStrings.addProcedure),
                  Tab(text: ChartStrings.toothState),
                  Tab(text: ChartStrings.history),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    FindingTab(
                      patientId: patientId,
                      tooth: tooth,
                      surfaces: surfaces,
                    ),
                    ProcedureTab(
                      patientId: patientId,
                      tooth: tooth,
                      surfaces: surfaces,
                    ),
                    ToothStateTab(patientId: patientId, tooth: tooth),
                    ToothHistoryTab(patientId: patientId, tooth: tooth),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
