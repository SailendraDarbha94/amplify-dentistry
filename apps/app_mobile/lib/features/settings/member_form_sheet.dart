import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_draft.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Roles that can be added from settings (the owner is created at
/// onboarding).
const List<ClinicRole> addableRoles = [
  ClinicRole.associateDentist,
  ClinicRole.visitingSpecialist,
  ClinicRole.receptionist,
  ClinicRole.assistant,
  ClinicRole.accountant,
];

/// Human label for a role.
String clinicRoleLabel(ClinicRole role) => switch (role) {
  ClinicRole.ownerDentist => 'Owner dentist',
  ClinicRole.associateDentist => 'Associate dentist',
  ClinicRole.visitingSpecialist => 'Visiting specialist',
  ClinicRole.receptionist => 'Receptionist',
  ClinicRole.assistant => 'Assistant',
  ClinicRole.accountant => 'Accountant',
  ClinicRole.lab => 'Lab contact',
};

/// Bottom sheet to add or edit a clinic member. Returns the member to save,
/// or null when dismissed.
class MemberFormSheet extends StatefulWidget {
  /// Creates the sheet; [existing] null means a new member.
  const MemberFormSheet({
    super.key,
    required this.clinicId,
    this.existing,
    this.defaultCouncil,
  });

  /// Owning clinic.
  final String clinicId;

  /// Member being edited.
  final ClinicMember? existing;

  /// Council name pre-filled for clinicians.
  final String? defaultCouncil;

  /// Shows the sheet and returns the resulting member or null.
  static Future<ClinicMember?> show(
    BuildContext context, {
    required String clinicId,
    ClinicMember? existing,
    String? defaultCouncil,
  }) => showModalBottomSheet<ClinicMember>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MemberFormSheet(
      clinicId: clinicId,
      existing: existing,
      defaultCouncil: defaultCouncil,
    ),
  );

  @override
  State<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends State<MemberFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late ClinicRole _role;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _registration;
  late final TextEditingController _council;
  late final TextEditingController _qualifications;
  late final TextEditingController _feeShare;

  bool get _isClinician => _role.isClinician;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _role = e?.role ?? ClinicRole.associateDentist;
    _name = TextEditingController(text: e?.displayName ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _registration = TextEditingController(text: e?.registrationNumber ?? '');
    _council = TextEditingController(
      text: e?.registrationCouncil ?? widget.defaultCouncil ?? '',
    );
    _qualifications = TextEditingController(
      text: e?.qualifications.join(', ') ?? '',
    );
    _feeShare = TextEditingController(
      text: e?.feeSharePercent?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _registration,
      _council,
      _qualifications,
      _feeShare,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateFeeShare(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = num.tryParse(t);
    if (n == null || n < 0 || n > 100) return 'Enter 0 to 100';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().toUtc();
    final e = widget.existing;
    final quals = _qualifications.text
        .split(',')
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toList();
    final fee = num.tryParse(_feeShare.text.trim());
    final member = ClinicMember(
      id: e?.id ?? newId(),
      clinicId: widget.clinicId,
      displayName: _name.text.trim(),
      role: _role,
      registrationNumber: _isClinician ? _registration.text.trim() : null,
      registrationCouncil: _isClinician && _council.text.trim().isNotEmpty
          ? _council.text.trim()
          : null,
      qualifications: quals,
      hprId: e?.hprId,
      phone: OnboardingValidators.normalisePhone(_phone.text),
      email: e?.email,
      feeSharePercent: _isClinician ? fee : null,
      isActive: e?.isActive ?? true,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(member);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final editingOwner = widget.existing?.role == ClinicRole.ownerDentist;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: AppSpacing.screenPadding,
          children: [
            Text(
              widget.existing == null ? 'Add member' : 'Edit member',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ClinicRole>(
              key: const ValueKey('member-role'),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r
                    in editingOwner ? [ClinicRole.ownerDentist] : addableRoles)
                  DropdownMenuItem(value: r, child: Text(clinicRoleLabel(r))),
              ],
              onChanged: editingOwner
                  ? null
                  : (v) => setState(() => _role = v ?? _role),
            ),
            const FormGap(),
            TextFormField(
              key: const ValueKey('member-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => OnboardingValidators.required(v, 'Name'),
            ),
            const FormGap(),
            TextFormField(
              key: const ValueKey('member-phone'),
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Mobile'),
              keyboardType: TextInputType.phone,
              validator: OnboardingValidators.indianMobile,
            ),
            if (_isClinician) ...[
              const FormGap(),
              TextFormField(
                key: const ValueKey('member-registration'),
                controller: _registration,
                decoration: const InputDecoration(
                  labelText: 'Council registration number',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: OnboardingValidators.registrationNumber,
              ),
              const FormGap(),
              TextFormField(
                controller: _council,
                decoration: const InputDecoration(
                  labelText: 'Registering council',
                ),
              ),
              const FormGap(),
              TextFormField(
                controller: _qualifications,
                decoration: const InputDecoration(
                  labelText: 'Qualifications',
                  helperText: 'Comma separated',
                ),
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('member-fee-share'),
                controller: _feeShare,
                decoration: const InputDecoration(
                  labelText: 'Fee share (%)',
                  helperText: 'Share of net fee for visiting specialists',
                ),
                keyboardType: TextInputType.number,
                validator: _validateFeeShare,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('member-save'),
              label: s.save,
              icon: Icons.check,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
