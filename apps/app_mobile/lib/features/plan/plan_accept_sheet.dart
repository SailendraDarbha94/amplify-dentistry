import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/features/consent/consent_form_sections.dart';
import 'package:ampdent_mobile/features/consent/consent_model.dart';
import 'package:ampdent_mobile/features/consent/signature_pad.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import 'plan_model.dart';

/// What the accept sheet returns.
class PlanAcceptance {
  /// Creates the acceptance.
  const PlanAcceptance({
    required this.signerName,
    required this.relation,
    required this.signaturePng,
    this.estimateDeclinedReason,
  });

  /// Who signed.
  final String signerName;

  /// In what capacity.
  final SignerRelation relation;

  /// Drawn signature.
  final Uint8List signaturePng;

  /// Why no written estimate was issued, when the patient declined one.
  final String? estimateDeclinedReason;
}

/// Captures the signer's name, capacity and a stylus signature to accept a
/// plan. A minor cannot self-sign. Without an issued estimate the sheet
/// requires the patient's refusal of a written estimate to be recorded.
class PlanAcceptSheet extends StatefulWidget {
  /// Creates the sheet.
  const PlanAcceptSheet({
    super.key,
    required this.editor,
    required this.patient,
    required this.now,
    required this.exporter,
    this.hasEstimate = true,
  });

  /// Plan being accepted.
  final PlanEditor editor;

  /// Patient (for the minor rule and name prefill).
  final Patient patient;

  /// Current time.
  final DateTime now;

  /// Turns the strokes into PNG bytes.
  final SignatureExporter exporter;

  /// Whether an estimate has been issued for the plan.
  final bool hasEstimate;

  /// Shows the sheet; null when cancelled.
  static Future<PlanAcceptance?> show(
    BuildContext context, {
    required PlanEditor editor,
    required Patient patient,
    required DateTime now,
    required SignatureExporter exporter,
    bool hasEstimate = true,
  }) => showModalBottomSheet<PlanAcceptance>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PlanAcceptSheet(
      editor: editor,
      patient: patient,
      now: now,
      exporter: exporter,
      hasEstimate: hasEstimate,
    ),
  );

  @override
  State<PlanAcceptSheet> createState() => _PlanAcceptSheetState();
}

class _PlanAcceptSheetState extends State<PlanAcceptSheet> {
  late SignerRelation _relation;
  late final TextEditingController _name;
  final TextEditingController _declinedReason = TextEditingController();
  final SignatureController _signature = newSignatureController();
  bool _busy = false;
  bool _estimateDeclined = false;

  bool get _isMinor => widget.patient.isMinor(widget.now);

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    if (_isMinor) {
      _relation = signerRelationFromGuardian(p.guardianRelation);
      _name = TextEditingController(text: p.guardianName ?? '');
    } else {
      _relation = SignerRelation.self;
      _name = TextEditingController(text: p.displayName);
    }
    _signature.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _signature.removeListener(_onChanged);
    _signature.dispose();
    _name.dispose();
    _declinedReason.dispose();
    super.dispose();
  }

  bool get _estimateOk =>
      widget.hasEstimate ||
      (_estimateDeclined && _declinedReason.text.trim().isNotEmpty);

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final png = await widget.exporter(_signature);
    if (!mounted) return;
    if (png == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ConsentStrings.signatureRequired)),
      );
      return;
    }
    Navigator.of(context).pop(
      PlanAcceptance(
        signerName: _name.text,
        relation: _relation,
        signaturePng: png,
        estimateDeclinedReason: widget.hasEstimate || !_estimateDeclined
            ? null
            : _declinedReason.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final blocked = _isMinor && _relation == SignerRelation.self;
    final canConfirm =
        !blocked &&
        !_busy &&
        _estimateOk &&
        _name.text.trim().isNotEmpty &&
        _signature.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Accept ${widget.editor.plan.title}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.editor.lines.where((l) => !l.isAlternative).length} '
            'procedures, ${AppFormat.money(widget.editor.total, showPaise: false)}'
            ' (pre-tax). Lines are frozen on acceptance; later changes need a '
            'revision.',
            style: theme.textTheme.bodyMedium,
          ),
          if (!widget.hasEstimate) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              PlanStrings.estimateRequired,
              key: const ValueKey('accept-estimate-missing'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('accept-estimate-declined'),
              value: _estimateDeclined,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Patient declined a written estimate'),
              onChanged: (v) => setState(() => _estimateDeclined = v ?? false),
            ),
            if (_estimateDeclined)
              TextField(
                key: const ValueKey('accept-estimate-declined-reason'),
                controller: _declinedReason,
                decoration: const InputDecoration(
                  labelText: 'How the patient declined (recorded on the plan)',
                ),
                onChanged: (_) => setState(() {}),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SignerRelationSelector(
            value: _relation,
            isMinor: _isMinor,
            onChanged: (r) => setState(() {
              _relation = r;
              _name.text = r == SignerRelation.self
                  ? widget.patient.displayName
                  : (widget.patient.guardianName ?? _name.text);
            }),
          ),
          const FormGap(),
          TextField(
            key: const ValueKey('accept-signer-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: s.name),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          SignaturePadField(
            controller: _signature,
            padKey: const ValueKey('accept-signature'),
          ),
          const SizedBox(height: AppSpacing.md),
          BigActionButton(
            key: const ValueKey('accept-confirm'),
            label: 'Accept plan',
            icon: Icons.verified_outlined,
            loading: _busy,
            onPressed: canConfirm ? _confirm : null,
          ),
        ],
      ),
    );
  }
}
