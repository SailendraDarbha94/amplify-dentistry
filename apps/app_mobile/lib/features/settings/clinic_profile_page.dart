import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_draft.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Edit the clinic profile printed on every document.
class ClinicProfilePage extends ConsumerWidget {
  /// Creates the page.
  const ClinicProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinic = ref.watch(currentClinicProvider);
    return clinic.when(
      loading: () => LoadingScaffold(message: context.strings.loading),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: e.toString()),
      ),
      data: (c) => ClinicProfileForm(clinic: c),
    );
  }
}

/// Collected text values; optional ones become null when blank.
class ClinicProfileValues {
  /// Creates values pre-filled from [clinic].
  ClinicProfileValues(Clinic clinic)
    : name = clinic.name,
      legalName = clinic.legalName ?? '',
      address = clinic.addressLines.join('\n'),
      city = clinic.city,
      stateCode = clinic.stateCode,
      pincode = clinic.pincode,
      phone = clinic.phone,
      whatsappPhone = clinic.whatsappPhone ?? '',
      email = clinic.email ?? '',
      upiVpa = clinic.upiVpa ?? '',
      gstin = clinic.gstin ?? '';

  /// Field values as typed.
  String name, legalName, address, city, pincode, phone;

  /// Field values as typed (optional).
  String whatsappPhone, email, upiVpa, gstin;

  /// Two-digit GST state code.
  String? stateCode;

  static String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  /// Applies the values onto [base], clearing optional fields that were
  /// blanked (which `copyWith` alone cannot do).
  Clinic apply(Clinic base, DateTime now) => Clinic(
    id: base.id,
    name: name.trim(),
    legalName: _opt(legalName),
    addressLines: address
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(),
    city: city.trim(),
    stateCode: stateCode ?? base.stateCode,
    pincode: pincode.trim(),
    phone: OnboardingValidators.normalisePhone(phone),
    whatsappPhone: _opt(whatsappPhone) == null
        ? null
        : OnboardingValidators.normalisePhone(whatsappPhone),
    email: _opt(email),
    gstin: _opt(gstin)?.toUpperCase(),
    defaultNotation: base.defaultNotation,
    timeZone: base.timeZone,
    upiVpa: _opt(upiVpa),
    logoPath: base.logoPath,
    createdAt: base.createdAt,
    updatedAt: now,
  );
}

/// The profile form for a loaded clinic.
class ClinicProfileForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const ClinicProfileForm({super.key, required this.clinic});

  /// Clinic being edited.
  final Clinic clinic;

  @override
  ConsumerState<ClinicProfileForm> createState() => _ClinicProfileFormState();
}

class _ClinicProfileFormState extends ConsumerState<ClinicProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final ClinicProfileValues _v = ClinicProfileValues(widget.clinic);
  bool _busy = false;

  Future<void> _save() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() => _busy = true);
    try {
      await ref
          .read(clinicRepositoryProvider)
          .updateClinic(
            ref.read(actorContextProvider),
            _v.apply(widget.clinic, DateTime.now().toUtc()),
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Scaffold(
      appBar: AppBar(title: const Text('Clinic profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            FormSection(
              title: 'Identity',
              children: [
                TextFormField(
                  key: const ValueKey('clinic-name'),
                  initialValue: _v.name,
                  decoration: const InputDecoration(labelText: 'Clinic name'),
                  validator: (v) =>
                      OnboardingValidators.required(v, 'Clinic name'),
                  onSaved: (v) => _v.name = v ?? '',
                ),
                TextFormField(
                  initialValue: _v.legalName,
                  decoration: const InputDecoration(
                    labelText: 'Legal name',
                    helperText: 'Optional; when different from the name',
                  ),
                  onSaved: (v) => _v.legalName = v ?? '',
                ),
                TextFormField(
                  initialValue: _v.address,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 3,
                  onSaved: (v) => _v.address = v ?? '',
                ),
                FormRow(
                  children: [
                    TextFormField(
                      initialValue: _v.city,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (v) =>
                          OnboardingValidators.required(v, 'City'),
                      onSaved: (v) => _v.city = v ?? '',
                    ),
                    TextFormField(
                      initialValue: _v.pincode,
                      decoration: const InputDecoration(labelText: 'PIN code'),
                      keyboardType: TextInputType.number,
                      validator: OnboardingValidators.pincode,
                      onSaved: (v) => _v.pincode = v ?? '',
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: gstStateByCode(_v.stateCode ?? '') == null
                      ? null
                      : _v.stateCode,
                  decoration: const InputDecoration(labelText: 'State'),
                  isExpanded: true,
                  items: [
                    for (final st in activeGstStateCodes)
                      DropdownMenuItem(
                        value: st.code,
                        child: Text('${st.name} (${st.code})'),
                      ),
                  ],
                  validator: (v) => v == null ? 'Pick your state' : null,
                  onChanged: (v) => _v.stateCode = v,
                  onSaved: (v) => _v.stateCode = v,
                ),
              ],
            ),
            const FormGap(height: AppSpacing.xl),
            FormSection(
              title: 'Contact and payments',
              children: [
                TextFormField(
                  initialValue: _v.phone,
                  decoration: const InputDecoration(labelText: 'Clinic phone'),
                  keyboardType: TextInputType.phone,
                  validator: OnboardingValidators.phone,
                  onSaved: (v) => _v.phone = v ?? '',
                ),
                TextFormField(
                  initialValue: _v.whatsappPhone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      OnboardingValidators.indianMobile(v, optional: true),
                  onSaved: (v) => _v.whatsappPhone = v ?? '',
                ),
                TextFormField(
                  initialValue: _v.email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (v) => _v.email = v ?? '',
                ),
                TextFormField(
                  initialValue: _v.upiVpa,
                  decoration: const InputDecoration(labelText: 'UPI id'),
                  validator: OnboardingValidators.upiVpa,
                  onSaved: (v) => _v.upiVpa = v ?? '',
                ),
                TextFormField(
                  key: const ValueKey('clinic-gstin'),
                  initialValue: _v.gstin,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN',
                    helperText: 'Blank when not registered (receipts only)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: OnboardingValidators.gstin,
                  onSaved: (v) => _v.gstin = v ?? '',
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
          key: const ValueKey('clinic-save'),
          label: s.save,
          icon: Icons.check,
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ),
    );
  }
}
