import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'patient_form_model.dart';

/// Text controllers behind the patient form, created from [PatientFormData].
class PatientFormControllers {
  /// Creates controllers pre-filled from [initial].
  PatientFormControllers(PatientFormData initial)
    : firstName = TextEditingController(text: initial.firstName),
      lastName = TextEditingController(text: initial.lastName),
      phone = TextEditingController(text: initial.phone),
      altPhone = TextEditingController(text: initial.altPhone),
      email = TextEditingController(text: initial.email),
      approxAge = TextEditingController(
        text: initial.approxAgeYears == null
            ? ''
            : initial.approxAgeYears!.toStringAsFixed(0),
      ),
      address1 = TextEditingController(
        text: initial.addressLines.isNotEmpty ? initial.addressLines[0] : '',
      ),
      address2 = TextEditingController(
        text: initial.addressLines.length > 1 ? initial.addressLines[1] : '',
      ),
      city = TextEditingController(text: initial.city),
      pincode = TextEditingController(text: initial.pincode),
      abha = TextEditingController(text: initial.abhaNumber),
      guardianName = TextEditingController(text: initial.guardianName),
      guardianPhone = TextEditingController(text: initial.guardianPhone),
      notes = TextEditingController(text: initial.notes);

  /// Field controllers.
  final TextEditingController firstName,
      lastName,
      phone,
      altPhone,
      email,
      approxAge,
      address1,
      address2,
      city,
      pincode,
      abha,
      guardianName,
      guardianPhone,
      notes;

  /// Parsed approximate age, null when blank or invalid.
  num? get approxAgeValue => num.tryParse(approxAge.text.trim());

  /// Releases every controller.
  void dispose() {
    for (final c in [
      firstName,
      lastName,
      phone,
      altPhone,
      email,
      approxAge,
      address1,
      address2,
      city,
      pincode,
      abha,
      guardianName,
      guardianPhone,
      notes,
    ]) {
      c.dispose();
    }
  }
}

/// Name, age and sex.
class PatientIdentitySection extends StatelessWidget {
  /// Creates the section.
  const PatientIdentitySection({
    super.key,
    required this.c,
    required this.dateOfBirth,
    required this.onPickDateOfBirth,
    required this.onClearDateOfBirth,
    required this.sex,
    required this.onSexChanged,
    required this.onAgeChanged,
  });

  /// Controllers.
  final PatientFormControllers c;

  /// Chosen DOB.
  final DateTime? dateOfBirth;

  /// Opens the date picker.
  final VoidCallback onPickDateOfBirth;

  /// Clears the DOB (switches to approximate age).
  final VoidCallback onClearDateOfBirth;

  /// Chosen sex.
  final Sex sex;

  /// Sex change callback.
  final ValueChanged<Sex> onSexChanged;

  /// Fired when the approximate age text changes.
  final ValueChanged<String> onAgeChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return FormSection(
      title: s.patient,
      children: [
        FormRow(
          children: [
            TextFormField(
              key: const ValueKey('patient-first-name'),
              controller: c.firstName,
              decoration: const InputDecoration(labelText: 'First name'),
              textCapitalization: TextCapitalization.words,
              validator: PatientValidators.firstName,
            ),
            TextFormField(
              key: const ValueKey('patient-last-name'),
              controller: c.lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        FormRow(
          flex: const [3, 2],
          children: [
            InkWell(
              key: const ValueKey('patient-dob'),
              onTap: onPickDateOfBirth,
              borderRadius: AppRadii.mdAll,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: s.dateOfBirth,
                  suffixIcon: dateOfBirth == null
                      ? const Icon(Icons.calendar_today_outlined)
                      : IconButton(
                          key: const ValueKey('patient-dob-clear'),
                          icon: const Icon(Icons.clear),
                          onPressed: onClearDateOfBirth,
                        ),
                ),
                child: Text(
                  dateOfBirth == null
                      ? 'Unknown'
                      : AppFormat.date(dateOfBirth!),
                ),
              ),
            ),
            TextFormField(
              key: const ValueKey('patient-approx-age'),
              controller: c.approxAge,
              enabled: dateOfBirth == null,
              decoration: const InputDecoration(
                labelText: 'Age (years)',
                helperText: 'Required if DOB unknown',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  PatientValidators.approxAge(v, required: dateOfBirth == null),
              onChanged: onAgeChanged,
            ),
          ],
        ),
        ToggleChipGroup<Sex>(
          options: const [
            ToggleChipOption(value: Sex.male, label: 'Male'),
            ToggleChipOption(value: Sex.female, label: 'Female'),
            ToggleChipOption(value: Sex.other, label: 'Other'),
          ],
          selected: sex == Sex.unspecified ? const {} : {sex},
          multiSelect: false,
          onChanged: (set) =>
              onSexChanged(set.isEmpty ? Sex.unspecified : set.first),
        ),
      ],
    );
  }
}

/// Phone, email, address, ABHA and language.
class PatientContactSection extends StatelessWidget {
  /// Creates the section.
  const PatientContactSection({
    super.key,
    required this.c,
    required this.language,
    required this.onLanguageChanged,
  });

  /// Controllers.
  final PatientFormControllers c;

  /// Preferred language code.
  final String language;

  /// Language change callback.
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Contact',
      children: [
        TextFormField(
          key: const ValueKey('patient-phone'),
          controller: c.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          validator: PatientValidators.phone,
        ),
        FormRow(
          children: [
            TextFormField(
              controller: c.altPhone,
              decoration: const InputDecoration(labelText: 'Alternate phone'),
              keyboardType: TextInputType.phone,
              validator: PatientValidators.optionalMobile,
            ),
            TextFormField(
              controller: c.email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: PatientValidators.email,
            ),
          ],
        ),
        TextFormField(
          controller: c.address1,
          decoration: const InputDecoration(labelText: 'Address'),
          textCapitalization: TextCapitalization.words,
        ),
        FormRow(
          children: [
            TextFormField(
              controller: c.city,
              decoration: const InputDecoration(labelText: 'City'),
              textCapitalization: TextCapitalization.words,
            ),
            TextFormField(
              controller: c.pincode,
              decoration: const InputDecoration(labelText: 'PIN code'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        TextFormField(
          key: const ValueKey('patient-abha'),
          controller: c.abha,
          decoration: const InputDecoration(
            labelText: 'ABHA number',
            helperText: 'Optional, 14 digits',
          ),
          keyboardType: TextInputType.number,
          validator: PatientValidators.abhaNumber,
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('patient-language'),
          initialValue: language,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Message language'),
          items: [
            for (final (code, label) in patientLanguages)
              DropdownMenuItem(value: code, child: Text(label)),
          ],
          onChanged: (v) => onLanguageChanged(v ?? 'en'),
        ),
      ],
    );
  }
}

/// Guardian details; mandatory when the patient is under 18.
class PatientGuardianSection extends StatelessWidget {
  /// Creates the section.
  const PatientGuardianSection({
    super.key,
    required this.c,
    required this.required,
    required this.relation,
    required this.onRelationChanged,
  });

  /// Controllers.
  final PatientFormControllers c;

  /// Whether the fields are mandatory (minor).
  final bool required;

  /// Chosen relation.
  final String relation;

  /// Relation change callback.
  final ValueChanged<String> onRelationChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return FormSection(
      key: const ValueKey('patient-guardian-section'),
      title: s.guardian,
      description: required
          ? 'Required for patients under 18. All messages go to the guardian.'
          : 'Optional for adults.',
      trailing: required
          ? StatusBadge(
              key: const ValueKey('patient-guardian-required'),
              label: s.required,
              tone: BadgeTone.warning,
              dense: true,
            )
          : null,
      children: [
        TextFormField(
          key: const ValueKey('patient-guardian-name'),
          controller: c.guardianName,
          decoration: const InputDecoration(labelText: 'Guardian name'),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              PatientValidators.guardianName(v, required: required),
        ),
        FormRow(
          children: [
            DropdownButtonFormField<String>(
              initialValue: relation.isEmpty ? null : relation,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Relation'),
              items: [
                for (final r in guardianRelations)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => onRelationChanged(v ?? ''),
            ),
            TextFormField(
              key: const ValueKey('patient-guardian-phone'),
              controller: c.guardianPhone,
              decoration: const InputDecoration(labelText: 'Guardian mobile'),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  PatientValidators.guardianPhone(v, required: required),
            ),
          ],
        ),
      ],
    );
  }
}

/// DPDP purpose toggles.
class PatientConsentSection extends StatelessWidget {
  /// Creates the section.
  const PatientConsentSection({
    super.key,
    required this.consents,
    required this.onChanged,
  });

  /// Current toggle values.
  final Map<DataPurpose, bool> consents;

  /// Fired with the purpose and its new value.
  final void Function(DataPurpose purpose, bool granted) onChanged;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Data consent',
      description:
          'Recorded per purpose under the DPDP Act notice. '
          'Reminders need consent; marketing is off by default.',
      gap: 0,
      children: [
        for (final purpose in patientFormConsentPurposes)
          SwitchListTile(
            key: ValueKey('patient-consent-${purpose.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(dataPurposeLabel(purpose)),
            value: consents[purpose] ?? false,
            onChanged: (v) => onChanged(purpose, v),
          ),
      ],
    );
  }
}
