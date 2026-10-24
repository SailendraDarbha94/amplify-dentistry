import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import 'consent_form_sections.dart';
import 'consent_model.dart';
import 'consent_picker.dart';
import 'consent_providers.dart';
import 'consent_service.dart';
import 'signature_pad.dart';

/// New procedure consent. Opened with `?procedureIds=a,b` it groups the
/// procedures by template and takes one consent per template in sequence;
/// with `?template=CODE` it takes that stand-alone form; with neither it
/// shows a picker first.
class ConsentNewPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ConsentNewPage({
    super.key,
    required this.patientId,
    this.procedureIds = const [],
    this.templateCode,
    this.planId,
  });

  /// The patient.
  final String patientId;

  /// Procedures to consent for (from the query string).
  final List<String> procedureIds;

  /// Stand-alone template code (`PHOTO-USE`, `GENERAL-EXAM`).
  final String? templateCode;

  /// Plan the consent belongs to, when launched from a plan.
  final String? planId;

  @override
  ConsumerState<ConsentNewPage> createState() => _ConsentNewPageState();
}

class _ConsentNewPageState extends ConsumerState<ConsentNewPage> {
  List<String>? _pickedIds;
  String? _pickedTemplate;
  int _index = 0;
  String _language = 'en';
  bool _readAloud = false;
  SignerRelation? _relation;
  bool _signerPrefilled = false;
  bool _saving = false;
  final TextEditingController _discussion = TextEditingController();
  final TextEditingController _signerName = TextEditingController();
  final TextEditingController _signerPhone = TextEditingController();
  final TextEditingController _witness = TextEditingController();
  final SignatureController _signature = newSignatureController();

  bool get _pickerMode =>
      widget.procedureIds.isEmpty &&
      widget.templateCode == null &&
      _pickedIds == null &&
      _pickedTemplate == null;

  List<String> get _ids => _pickedIds ?? widget.procedureIds;
  String? get _templateCode => _pickedTemplate ?? widget.templateCode;

  @override
  void dispose() {
    _discussion.dispose();
    _signerName.dispose();
    _signerPhone.dispose();
    _witness.dispose();
    _signature.dispose();
    super.dispose();
  }

  List<ConsentGroup> _groups(List<ProcedureRecord> procedures) {
    final selected = procedures.where((p) => _ids.contains(p.id)).toList();
    final code = _templateCode;
    if (code != null) {
      final t = consentTemplateByCode(code);
      if (t == null) return const [];
      return [ConsentGroup(template: t, procedures: selected)];
    }
    return groupProceduresByTemplate(selected);
  }

  void _prefillSigner(Patient patient, DateTime now) {
    if (_signerPrefilled) return;
    _signerPrefilled = true;
    if (patient.isMinor(now)) {
      _relation = signerRelationFromGuardian(patient.guardianRelation);
      _signerName.text = patient.guardianName ?? '';
      _signerPhone.text = patient.guardianPhone ?? '';
    } else {
      _relation = SignerRelation.self;
      _signerName.text = patient.displayName;
      _signerPhone.text = patient.phone;
    }
  }

  void _resetForNext() {
    _discussion.clear();
    _witness.clear();
    _readAloud = false;
    _signature.clear();
  }

  Future<void> _sign({
    required ConsentGroup group,
    required Patient patient,
    required ClinicMember dentist,
    required String renderedText,
    required int groupCount,
  }) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final png = await ref.read(signatureExporterProvider)(_signature);
      final record = await ref
          .read(consentServiceProvider)
          .sign(
            ConsentSigning(
              template: group.template,
              languageCode: _language,
              renderedText: renderedText,
              procedureIds: group.procedureIds,
              planId: widget.planId,
              teeth: group.teeth,
              signerName: _signerName.text,
              signerRelation: _relation ?? SignerRelation.self,
              signerPhone: _signerPhone.text,
              witnessName: _witness.text,
              discussionNote: _discussion.text,
              readAloud: _readAloud,
              signaturePng: png,
            ),
            patient: patient,
            dentist: dentist,
            now: ref.read(clockProvider)(),
          );
      if (!mounted) return;
      if (_index + 1 < groupCount) {
        setState(() {
          _index += 1;
          _resetForNext();
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Saved. Next: consent ${_index + 1}')),
        );
      } else {
        await router.pushReplacement(
          '/patients/${widget.patientId}/consent/${record.id}',
        );
      }
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final patient = ref.watch(patientProvider(widget.patientId));
    final clinic = ref.watch(currentClinicProvider);
    final dentist = ref.watch(currentMemberProvider);
    final procedures = ref.watch(
      consentableProceduresProvider(widget.patientId),
    );
    final notation = ref.watch(notationProvider);
    final now = ref.watch(clockProvider)();
    if (patient.isLoading ||
        clinic.isLoading ||
        dentist.isLoading ||
        procedures.isLoading) {
      return LoadingScaffold(message: s.loading);
    }
    final p = patient.value;
    final c = clinic.value;
    final d = dentist.value;
    if (p == null || c == null || d == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.consent)),
        body: ErrorView(message: p == null ? 'Patient not found' : s.loading),
      );
    }
    final procs = procedures.value ?? const <ProcedureRecord>[];
    if (_pickerMode) {
      return Scaffold(
        appBar: AppBar(title: Text('New ${s.consent.toLowerCase()}')),
        body: ConsentPicker(
          procedures: procs,
          notation: notation,
          onContinue: (ids, template) => setState(() {
            _pickedIds = ids;
            _pickedTemplate = template;
          }),
        ),
      );
    }
    final groups = _groups(procs);
    if (groups.isEmpty || _index >= groups.length) {
      return Scaffold(
        appBar: AppBar(title: Text(s.consent)),
        body: const ErrorView(message: 'No consent template matched'),
      );
    }
    _prefillSigner(p, now);
    final group = groups[_index];
    final renderedText = renderConsentText(
      group.template,
      consentVariables(
        patient: p,
        dentist: d,
        clinic: c,
        teeth: group.teeth,
        notation: notation,
        now: now,
      ),
    );
    final isMinor = p.isMinor(now);
    final relation = _relation ?? SignerRelation.self;
    final blocked = isMinor && relation == SignerRelation.self;
    final dentistOk =
        d.isClinician && (d.registrationNumber ?? '').trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text('${s.consent}: ${p.displayName}')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                if (!dentistOk)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      ConsentStrings.dentistRequired,
                      key: const ValueKey('consent-dentist-block'),
                      style: TextStyle(color: AppColors.of(context).danger),
                    ),
                  ),
                ConsentGroupHeader(
                  group: group,
                  notation: notation,
                  index: _index,
                  count: groups.length,
                ),
                const SizedBox(height: AppSpacing.lg),
                FormSection(
                  title: 'Language',
                  children: [
                    ConsentLanguageSelector(
                      value: _language,
                      onChanged: (v) => setState(() => _language = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FormSection(
                  title: 'Consent text',
                  description: 'Shown to the signer exactly as below.',
                  children: [
                    ConsentTextView(text: renderedText),
                    CheckboxListTile(
                      key: const ValueKey('consent-read-aloud'),
                      value: _readAloud,
                      onChanged: (v) => setState(() => _readAloud = v ?? false),
                      title: const Text(ConsentStrings.readAloud),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    TextField(
                      key: const ValueKey('consent-discussion'),
                      controller: _discussion,
                      minLines: 2,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'What I explained (required)',
                        hintText: 'Risks, alternatives, questions answered',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FormSection(
                  title: 'Signer',
                  children: [
                    SignerRelationSelector(
                      value: relation,
                      isMinor: isMinor,
                      onChanged: (r) => setState(() {
                        _relation = r;
                        if (r == SignerRelation.self) {
                          _signerName.text = p.displayName;
                          _signerPhone.text = p.phone;
                        } else if (p.guardianName != null) {
                          _signerName.text = p.guardianName!;
                          _signerPhone.text = p.guardianPhone ?? '';
                        }
                      }),
                    ),
                    TextField(
                      key: const ValueKey('consent-signer-name'),
                      controller: _signerName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: s.name),
                    ),
                    TextField(
                      key: const ValueKey('consent-signer-phone'),
                      controller: _signerPhone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: s.phone),
                    ),
                    TextField(
                      key: const ValueKey('consent-witness'),
                      controller: _witness,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Witness (${s.optional.toLowerCase()})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FormSection(
                  title: 'Signature',
                  children: [
                    SignaturePadField(
                      controller: _signature,
                      padKey: const ValueKey('consent-signature'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: BigActionButton(
                key: const ValueKey('consent-sign'),
                label: 'Sign and save',
                icon: Icons.draw_outlined,
                loading: _saving,
                onPressed: blocked || !dentistOk || _saving
                    ? null
                    : () => _sign(
                        group: group,
                        patient: p,
                        dentist: d,
                        renderedText: renderedText,
                        groupCount: groups.length,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
