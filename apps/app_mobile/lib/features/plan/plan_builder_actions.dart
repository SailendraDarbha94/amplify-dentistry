import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/consent/signature_pad.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'plan_accept_sheet.dart';
import 'plan_add_line_sheet.dart';
import 'plan_builder_page.dart';
import 'plan_dialogs.dart';
import 'plan_estimate_flow.dart';
import 'plan_line_sheet.dart';
import 'plan_model.dart';
import 'plan_phase_section.dart';
import 'plan_providers.dart';

/// The builder page's actions, kept apart from its layout. The host state
/// exposes the editor and busy flag; every write goes through
/// `PlanService` with the current actor.
mixin PlanBuilderActions on ConsumerState<PlanBuilderPage> {
  /// Current editor (null while loading or when the plan is missing).
  PlanEditor? get editor;
  set editor(PlanEditor? value);

  /// Whether a write is in flight.
  bool get busy;
  set busy(bool value);

  /// Load failure message.
  String? get loadError;
  set loadError(String? value);

  /// Patient of the plan, as last seen by the page's build.
  Patient? get patient;

  /// Current clinic, as last seen by the page's build.
  Clinic? get clinic;

  /// Acting member, as last seen by the page's build.
  ClinicMember? get dentist;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _guard<T>(Future<T> Function() body) async {
    setState(() => busy = true);
    try {
      return await body();
    } on StateError catch (e) {
      _snack(e.message);
    } on ArgumentError catch (e) {
      _snack(e.message?.toString() ?? e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return null;
  }

  /// Loads the plan into the editor.
  Future<void> loadPlan() async {
    try {
      final loaded = await ref.read(planServiceProvider).load(widget.planId);
      if (!mounted) return;
      setState(() {
        editor = loaded;
        loadError = loaded == null ? 'Plan not found' : null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => loadError = e.toString());
    }
  }

  /// Saves the editor; returns whether it succeeded.
  Future<bool> saveEditor() async {
    final e = editor;
    if (e == null) return false;
    final saved = await _guard(
      () => ref
          .read(planServiceProvider)
          .save(
            e,
            providerId: ref.read(actorContextProvider).actorId,
            now: ref.read(clockProvider)(),
          ),
    );
    if (saved == null) return false;
    setState(() => editor = saved);
    return true;
  }

  Future<bool> _ensureSaved() async {
    final e = editor;
    if (e == null) return false;
    if (!e.dirty) return true;
    return saveEditor();
  }

  /// Stamps the plan as presented.
  Future<void> presentPlan() async {
    if (!await _ensureSaved()) return;
    final e = editor!;
    final plan = await _guard(
      () => ref
          .read(planServiceProvider)
          .present(e, now: ref.read(clockProvider)()),
    );
    if (plan == null) return;
    setState(() => editor = e.saved(plan, e.lines));
    _snack('Marked as presented');
  }

  /// Issues the next estimate version and opens its PDF.
  Future<void> issueEstimateAndPreview() async {
    if (!await _ensureSaved()) return;
    final e = editor!;
    if (!mounted) return;
    final estimate = await runEstimateFlow(context, ref, editor: e);
    if (estimate == null || !mounted) return;
    await openEstimate(estimate);
  }

  /// Opens an estimate PDF with share and WhatsApp actions.
  Future<void> openEstimate(Estimate estimate) async {
    final e = editor;
    final patient = this.patient;
    final clinic = this.clinic;
    final dentist = this.dentist;
    if (e == null || patient == null || clinic == null || dentist == null) {
      _snack(context.strings.loading);
      return;
    }
    await showEstimatePreview(
      context,
      ref,
      patient: patient,
      clinic: clinic,
      dentist: dentist,
      estimate: estimate,
      plan: e.plan,
      planLines: e.lines,
    );
  }

  /// Lists issued estimates.
  Future<void> openEstimates() async {
    final e = editor;
    if (e == null) return;
    final estimates = await ref.read(planEstimatesProvider(e.plan.id).future);
    if (!mounted) return;
    await showEstimatesSheet(
      context,
      ref,
      estimates: estimates,
      onOpen: openEstimate,
    );
  }

  /// Captures signer and signature, then accepts the plan.
  Future<void> acceptPlan() async {
    if (!await _ensureSaved() || !mounted) return;
    final e = editor!;
    final patient = this.patient;
    if (patient == null) {
      _snack(context.strings.loading);
      return;
    }
    final now = ref.read(clockProvider)();
    final estimates = await ref.read(planEstimatesProvider(e.plan.id).future);
    if (!mounted) return;
    final acceptance = await PlanAcceptSheet.show(
      context,
      editor: e,
      patient: patient,
      now: now,
      exporter: ref.read(signatureExporterProvider),
      hasEstimate: latestEstimate(estimates) != null,
    );
    if (acceptance == null) return;
    final plan = await _guard(
      () => ref
          .read(planServiceProvider)
          .accept(
            e,
            patient: patient,
            signerName: acceptance.signerName,
            relation: acceptance.relation,
            signaturePng: acceptance.signaturePng,
            estimateDeclinedReason: acceptance.estimateDeclinedReason,
            now: now,
          ),
    );
    if (plan == null) return;
    setState(() => editor = e.saved(plan, e.lines));
    _snack('Plan accepted; procedures moved to accepted');
  }

  /// Creates the next version and opens it.
  Future<void> revisePlan() async {
    final e = editor;
    if (e == null) return;
    final next = await _guard(
      () => ref.read(planServiceProvider).revise(e.plan.id),
    );
    if (next == null || !mounted) return;
    context.pushReplacement('/patients/${widget.patientId}/plan/${next.id}');
  }

  /// Renames the plan.
  Future<void> renamePlan() async {
    final e = editor;
    if (e == null) return;
    final title = await TextPromptDialog.show(
      context,
      title: 'Plan title',
      initial: e.plan.title,
      fieldKey: const ValueKey('plan-rename-input'),
    );
    if (title == null || title.isEmpty) return;
    setState(() => editor = e.setTitle(title));
  }

  /// Renames a phase.
  Future<void> renamePhase(PlanPhase phase) async {
    final e = editor;
    if (e == null) return;
    final name = await TextPromptDialog.show(
      context,
      title: 'Phase name',
      initial: phase.name,
      fieldKey: const ValueKey('plan-phase-input'),
    );
    if (name == null || name.isEmpty) return;
    setState(() => editor = e.renamePhase(phase.index, name));
  }

  /// Adds a line to [phaseIndex] from the chart or the catalogue.
  Future<void> addLineTo(int phaseIndex) async {
    final e = editor;
    if (e == null) return;
    final line = await PlanAddLineSheet.show(
      context,
      editor: e,
      procedures:
          ref.read(planProceduresProvider(widget.patientId)).value ?? const [],
      catalog: ref.read(catalogItemsProvider).value ?? const [],
      notation: ref.read(notationProvider),
      phaseIndex: phaseIndex,
    );
    if (line == null) return;
    setState(() => editor = e.addLine(line));
  }

  /// Opens the line editor.
  Future<void> editLine(TreatmentPlanLine line) async {
    final e = editor;
    if (e == null) return;
    final updated = await PlanLineSheet.show(
      context,
      line: line,
      phases: e.phases,
      alternativeGroups: e.alternativeGroups,
      catalogItem: ref.read(catalogByIdProvider)[line.catalogItemId],
    );
    if (updated == null) return;
    setState(() => editor = e.updateLine(updated));
  }

  /// Handles a line's overflow menu.
  Future<void> onLineAction(
    TreatmentPlanLine line,
    PlanLineAction action,
  ) async {
    final e = editor;
    if (e == null) return;
    switch (action) {
      case PlanLineAction.edit:
        await editLine(line);
      case PlanLineAction.moveToPhase:
        final target = await showModalBottomSheet<int>(
          context: context,
          useSafeArea: true,
          builder: (ctx) => ListView(
            shrinkWrap: true,
            children: [
              for (final p in e.phases)
                ListTile(
                  key: ValueKey('plan-move-${p.index}'),
                  title: Text(p.name),
                  selected: p.index == line.phaseIndex,
                  onTap: () => Navigator.of(ctx).pop(p.index),
                ),
              ListTile(
                key: const ValueKey('plan-move-new'),
                leading: const Icon(Icons.add),
                title: const Text('New phase'),
                onTap: () => Navigator.of(ctx).pop(e.phases.length),
              ),
            ],
          ),
        );
        if (target == null) return;
        var next = e;
        if (target >= e.phases.length) next = next.addPhase();
        setState(() => editor = next.moveToPhase(line.id, target));
      case PlanLineAction.toggleAlternative:
        setState(
          () => editor = e.setAlternative(
            line.id,
            alternative: !line.isAlternative,
            group: line.alternativeGroup ?? 'Plan B',
          ),
        );
      case PlanLineAction.remove:
        final ok = await ConfirmSheet.show(
          context,
          title: 'Remove ${line.laymanName}?',
          message: 'The chart procedure stays, marked planned-inactive.',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (!ok) return;
        setState(() => editor = e.removeLine(line.id));
    }
  }
}
