import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patient_form_model.dart';
import 'patient_form_sections.dart';
import 'patient_providers.dart';

/// Add or edit a patient. With a [patientId] the existing row and latest
/// consents are loaded first.
class PatientFormPage extends ConsumerWidget {
  /// Creates the page; null [patientId] means a new patient.
  const PatientFormPage({super.key, this.patientId});

  /// Patient to edit, or null.
  final String? patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = patientId;
    if (id == null) {
      return const PatientForm(initial: PatientFormData());
    }
    final patient = ref.watch(patientProvider(id));
    final consents = ref.watch(latestDataConsentsProvider(id));
    if (patient.isLoading || consents.isLoading) {
      return LoadingScaffold(message: context.strings.loading);
    }
    final existing = patient.value;
    if (existing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: 'Patient not found'),
      );
    }
    return PatientForm(
      existing: existing,
      initial: PatientFormData.fromPatient(
        existing,
        consents.value ?? const {},
      ),
    );
  }
}

/// The form proper, pre-filled from [initial].
class PatientForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const PatientForm({super.key, required this.initial, this.existing});

  /// Starting values.
  final PatientFormData initial;

  /// Existing patient when editing.
  final Patient? existing;

  @override
  ConsumerState<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends ConsumerState<PatientForm> {
  static const Logger _log = Logger('patients.form');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final PatientFormControllers _c;
  late DateTime? _dob;
  late Sex _sex;
  late String _language;
  late String _guardianRelation;
  late Map<DataPurpose, bool> _consents;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _c = PatientFormControllers(i);
    _dob = i.dateOfBirth;
    _sex = i.sex;
    _language = i.preferredLanguage;
    _guardianRelation = i.guardianRelation;
    _consents = {
      for (final p in patientFormConsentPurposes) p: i.consents[p] ?? false,
    };
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _isMinor => patientIsMinor(
    dateOfBirth: _dob,
    approxAgeYears: _dob == null ? _c.approxAgeValue : null,
    now: ref.read(clockProvider)(),
  );

  PatientFormData _collect() => PatientFormData(
    firstName: _c.firstName.text,
    lastName: _c.lastName.text,
    phone: _c.phone.text,
    altPhone: _c.altPhone.text,
    email: _c.email.text,
    dateOfBirth: _dob,
    approxAgeYears: _dob == null ? _c.approxAgeValue : null,
    sex: _sex,
    addressLines: [_c.address1.text, _c.address2.text],
    city: _c.city.text,
    pincode: _c.pincode.text,
    abhaNumber: _c.abha.text,
    preferredLanguage: _language,
    guardianName: _c.guardianName.text,
    guardianRelation: _guardianRelation,
    guardianPhone: _c.guardianPhone.text,
    notes: _c.notes.text,
    consents: _consents,
  );

  Future<void> _pickDob() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (!mounted || picked == null) return;
    setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    setState(() => _busy = true);
    try {
      final saver = PatientSaver(
        patients: ref.read(patientRepositoryProvider),
        consents: ref.read(consentRepositoryProvider),
        clinics: ref.read(clinicRepositoryProvider),
        ctx: ref.read(actorContextProvider),
      );
      final saved = await saver.save(
        _collect(),
        existing: widget.existing,
        now: ref.read(clockProvider)(),
      );
      if (!mounted) return;
      if (widget.existing == null) {
        // Replace the form with the new patient's page in the stack the user
        // came from (Patients list or Today quick action) so neither tab is
        // left with a stale form on top.
        context.pushReplacement('/patients/${saved.id}');
      } else {
        context.pop();
      }
    } on Object catch (error, stackTrace) {
      _log.error('save failed', error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : context.strings.somethingWentWrong,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? s.edit : s.newPatient)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            PatientIdentitySection(
              c: _c,
              dateOfBirth: _dob,
              onPickDateOfBirth: _pickDob,
              onClearDateOfBirth: () => setState(() => _dob = null),
              sex: _sex,
              onSexChanged: (v) => setState(() => _sex = v),
              onAgeChanged: (_) => setState(() {}),
            ),
            const FormGap(height: AppSpacing.xl),
            PatientContactSection(
              c: _c,
              language: _language,
              onLanguageChanged: (v) => setState(() => _language = v),
            ),
            const FormGap(height: AppSpacing.xl),
            PatientGuardianSection(
              c: _c,
              required: _isMinor,
              relation: _guardianRelation,
              onRelationChanged: (v) => setState(() => _guardianRelation = v),
            ),
            const FormGap(height: AppSpacing.xl),
            PatientConsentSection(
              consents: _consents,
              onChanged: (purpose, granted) =>
                  setState(() => _consents = {..._consents, purpose: granted}),
            ),
            const FormGap(height: AppSpacing.xl),
            FormSection(
              title: s.notes,
              children: [
                TextFormField(
                  controller: _c.notes,
                  decoration: const InputDecoration(
                    labelText: 'Front-desk notes',
                    helperText: 'Not clinical; use the case sheet for that',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.screenPadding,
        child: BigActionButton(
          key: const ValueKey('patient-save'),
          label: s.save,
          icon: Icons.check,
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ),
    );
  }
}
