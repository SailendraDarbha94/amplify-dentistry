import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_shell.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/plan/plan_providers.dart'
    show planServiceProvider;
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'chart_mapping.dart';
import 'chart_providers.dart';
import 'chart_strings.dart';
import 'consent_guard.dart';
import 'consent_guard_dialog.dart';
import 'preop_guard.dart';
import 'preop_guard_dialog.dart';
import 'procedure_list.dart';
import 'tooth_action_bar.dart';
import 'tooth_sheet.dart';

/// Billing route that opens a new invoice with [procedureId] preselected.
String billingRouteFor(String patientId, String procedureId) =>
    '/patients/$patientId/billing/invoice/new?procedureIds=$procedureId';

/// The chairside screen: odontogram with findings and procedures drawn as
/// overlays, notation and mixed-dentition toggles, a tooth action bar and
/// the procedure list with quick actions.
/// Test keys: `chart-odontogram`, `chart-perio`, `chart-mixed`,
/// `chart-action-finding|procedure|state|history|clear`.
class ChartPage extends ConsumerStatefulWidget {
  /// Creates the page; [initialTooth] preselects a tooth (`?tooth=16`).
  const ChartPage({super.key, required this.patientId, this.initialTooth});

  /// Patient whose chart this is.
  final String patientId;

  /// Tooth selected when the page opens.
  final ToothId? initialTooth;

  @override
  ConsumerState<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends ConsumerState<ChartPage> {
  static const Logger _log = Logger('chart.page');

  late ToothId? _selected = widget.initialTooth;
  SurfaceSet _surfaces = const SurfaceSet.empty();
  bool? _mixedOverride;
  bool _busy = false;

  void _selectTooth(ToothId tooth) => setState(() {
    if (_selected != tooth) _surfaces = const SurfaceSet.empty();
    _selected = tooth;
  });

  void _toggleSurface(ToothId tooth, ToothSurface surface) {
    if (tooth != _selected) return _selectTooth(tooth);
    setState(() => _surfaces = _surfaces.toggled(surface));
  }

  void _clearSelection() => setState(() {
    _selected = null;
    _surfaces = const SurfaceSet.empty();
  });

  Future<void> _openSheet(ToothSheetTab tab) async {
    final tooth = _selected;
    if (tooth == null) return;
    final result = await ToothSheet.show(
      context,
      patientId: widget.patientId,
      tooth: tooth,
      surfaces: _surfaces,
      initialTab: tab,
    );
    if (!mounted || result == null) return;
    setState(() => _surfaces = const SurfaceSet.empty());
    _showResult(result);
    final next = result.nextRoute;
    if (next != null) await context.push(next);
  }

  /// The app's root messenger (it outlives this page, so the SnackBar and
  /// its action survive a pop): by key once `main.dart` binds it, else the
  /// nearest one, which in the app is that same root messenger.
  ScaffoldMessengerState get _messenger =>
      rootScaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);

  void _showResult(ToothSheetResult result) {
    final p = result.procedure;
    final recall = result.recall;
    final text = recall == null
        ? result.message
        : '${result.message} · ${ChartStrings.recallCreated} '
              '${AppFormat.date(recall.dueAt)}';
    // Captured now: the action may fire after this page has been popped.
    final router = GoRouter.of(context);
    _messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        action: p != null && p.status.isBillable
            ? SnackBarAction(
                label: ChartStrings.addToBill,
                onPressed: () =>
                    router.push(billingRouteFor(widget.patientId, p.id)),
              )
            : null,
      ),
    );
  }

  void _addToBill(ProcedureRecord p) =>
      context.push(billingRouteFor(widget.patientId, p.id));

  /// Advances or completes [p]. The busy flag is raised synchronously, before
  /// the first await, so a gloved double tap cannot run two transitions (and
  /// record two stages or two recalls) while the pre-op check is loading.
  Future<void> _markDone(ProcedureRecord p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final item = ref.read(catalogByIdProvider)[p.catalogItemId];
      final kind = classifyProcedure(p.code, category: item?.category);
      final now = ref.read(clockProvider)();
      // Estimates precede treatment: a plan line's first sitting needs an
      // issued estimate (or the patient's recorded refusal of one).
      final planId = p.planId;
      if (planId != null && p.status != ProcedureStatus.inProgress) {
        await ref
            .read(planServiceProvider)
            .ensureEstimateBeforeTreatment(planId);
      }
      // Consent precedes treatment: checked before the radiograph guard.
      final consents = await ref
          .read(consentRepositoryProvider)
          .consentsForPatient(widget.patientId);
      final consentCheck = checkExistingProcedureConsent(
        p,
        item: item,
        consents: consents,
      );
      String? consentReason;
      if (consentCheck.blocks) {
        if (!mounted) return;
        final choice = await ConsentGuardDialog.show(
          context,
          procedureName: p.name,
        );
        if (choice == null) return;
        if (choice.getConsent) {
          if (!mounted) return;
          await context.push(consentRouteFor(widget.patientId, p.id));
          return;
        }
        consentReason = choice.reason;
      }
      final images = await ref
          .read(clinicalRepositoryProvider)
          .imagesForPatient(widget.patientId);
      final check = checkProcedurePreOp(
        p,
        kind: kind,
        at: now,
        catalogFlag: item?.requiresPreOpRadiograph ?? false,
        images: images,
      );
      PreOpResolution? resolution;
      if (check.blocks) {
        if (!mounted) return;
        resolution = await PreOpGuardDialog.show(
          context,
          procedureName: p.name,
          candidates: check.candidates,
        );
        if (resolution == null) return;
      }
      if (!mounted) return;
      final result = await ref
          .read(chartServiceProvider)
          .markDone(
            p,
            item: item,
            consentReason: consentReason,
            preOpReason: resolution?.reason,
            preOpImageIds: [
              ...check.attachedImageIds,
              ...?resolution?.imageIds,
            ],
          );
      if (!mounted) return;
      _showResult(ToothSheetResult.forProcedure(result));
    } on Object catch (e) {
      _log.warning('mark done failed', error: e);
      if (!mounted) return;
      final text = e is StateError ? e.message : e.toString();
      _messenger.showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNotation(ToothNotation notation) async {
    try {
      await ref.read(chartServiceProvider).saveNotation(notation);
    } on Object catch (e) {
      _log.warning('notation save failed', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final patient = ref.watch(chartPatientProvider(widget.patientId));
    final seed = ref.watch(chartSeedProvider(widget.patientId));
    final states = ref.watch(toothStatesProvider(widget.patientId));
    final findingsAsync = ref.watch(chartFindingsProvider(widget.patientId));
    final proceduresAsync = ref.watch(
      chartProceduresProvider(widget.patientId),
    );
    final error =
        patient.error ??
        seed.error ??
        states.error ??
        findingsAsync.error ??
        proceduresAsync.error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.chart)),
        body: ErrorView(
          key: const ValueKey('chart-error'),
          message: error.toString(),
          onRetry: () {
            ref.invalidate(chartSeedProvider(widget.patientId));
            ref.invalidate(toothStatesProvider(widget.patientId));
            ref.invalidate(chartFindingsProvider(widget.patientId));
            ref.invalidate(chartProceduresProvider(widget.patientId));
          },
        ),
      );
    }
    if (patient.isLoading || seed.isLoading || states.isLoading) {
      return LoadingScaffold(message: s.loading);
    }
    final p = patient.value;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.chart)),
        body: const ErrorView(message: 'Patient not found'),
      );
    }
    final stateMap = states.value ?? const <ToothId, ToothState>{};
    final findings = findingsAsync.value ?? const <Finding>[];
    final procedures = proceduresAsync.value ?? const <ProcedureRecord>[];
    final catalogById = ref.watch(catalogByIdProvider);
    final notation = ref.watch(notationProvider);
    final now = ref.watch(clockProvider)();
    final visuals = buildToothVisuals(
      states: stateMap,
      findings: findings,
      procedures: procedures,
      catalogById: catalogById,
    );
    final mixed =
        _mixedOverride ?? mixedDentitionDefault(p.ageYears(now), stateMap);
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayName),
        actions: [
          IconButton(
            key: const ValueKey('chart-perio'),
            tooltip: ChartStrings.perioChart,
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () =>
                context.push('/patients/${widget.patientId}/chart/perio'),
          ),
        ],
      ),
      body: Column(
        children: [
          ChartToolbar(
            notation: notation,
            onNotation: _saveNotation,
            mixed: mixed,
            onMixed: (v) => setState(() => _mixedOverride = v),
          ),
          Expanded(
            // No horizontal padding on the list: the odontogram needs the
            // full 360 px of a small phone (8 columns x 44 px touch targets
            // plus its own 4 px padding) to fit without scrolling. The other
            // rows add their own gutter.
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Odontogram(
                    key: const ValueKey('chart-odontogram'),
                    teeth: visuals,
                    notation: notation,
                    selectedTooth: selected,
                    selectedSurfaces: _surfaces,
                    mixedDentition: mixed,
                    compact: constraints.maxWidth < 600,
                    onToothTap: _selectTooth,
                    onSurfaceTap: _toggleSurface,
                    onToothLongPress: (tooth) {
                      _selectTooth(tooth);
                      _openSheet(ToothSheetTab.finding);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: ToothLegend(),
                ),
                if (selected == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      ChartStrings.tapToothHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: ChartProcedureList(
                    procedures: procedures,
                    notation: notation,
                    busy: _busy,
                    onMarkDone: _markDone,
                    onAddToBill: _addToBill,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: selected == null
          ? null
          : ToothActionBar(
              label:
                  '${s.tooth} '
                  '${describeToothSurfaces(selected, _surfaces, notation)}',
              onAction: _openSheet,
              onClear: _clearSelection,
            ),
    );
  }
}
