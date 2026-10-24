import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_controller.dart';
import '../onboarding_draft.dart';

/// Step 1: clinic identity and contact details.
class ClinicStep extends ConsumerWidget {
  /// Creates the step bound to [formKey].
  const ClinicStep({super.key, required this.formKey});

  /// Form key the page validates and saves through.
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Form(
      key: formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          FormSection(
            title: 'Clinic',
            description: 'Printed on every invoice, prescription and consent.',
            children: [
              TextFormField(
                key: const ValueKey('onboarding-clinic-name'),
                initialValue: draft.clinicName,
                decoration: const InputDecoration(labelText: 'Clinic name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    OnboardingValidators.required(v, 'Clinic name'),
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(clinicName: v ?? '')),
              ),
              FormRow(
                children: [
                  TextFormField(
                    key: const ValueKey('onboarding-city'),
                    initialValue: draft.city,
                    decoration: const InputDecoration(labelText: 'City'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => OnboardingValidators.required(v, 'City'),
                    onSaved: (v) =>
                        controller.update((d) => d.copyWith(city: v ?? '')),
                  ),
                  TextFormField(
                    key: const ValueKey('onboarding-pincode'),
                    initialValue: draft.pincode,
                    decoration: const InputDecoration(
                      labelText: 'PIN code',
                      helperText: 'Optional',
                    ),
                    keyboardType: TextInputType.number,
                    validator: OnboardingValidators.pincode,
                    onSaved: (v) =>
                        controller.update((d) => d.copyWith(pincode: v ?? '')),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('onboarding-state'),
                initialValue: draft.stateCode,
                decoration: const InputDecoration(labelText: 'State'),
                isExpanded: true,
                items: [
                  for (final s in activeGstStateCodes)
                    DropdownMenuItem(
                      value: s.code,
                      child: Text('${s.name} (${s.code})'),
                    ),
                ],
                validator: (v) => v == null ? 'Pick your state' : null,
                onChanged: (v) =>
                    controller.update((d) => d.copyWith(stateCode: v)),
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(stateCode: v)),
              ),
            ],
          ),
          const FormGap(height: AppSpacing.xl),
          FormSection(
            title: 'Contact',
            children: [
              TextFormField(
                key: const ValueKey('onboarding-phone'),
                initialValue: draft.phone,
                decoration: const InputDecoration(
                  labelText: 'Clinic phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: OnboardingValidators.phone,
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(phone: v ?? '')),
              ),
              TextFormField(
                key: const ValueKey('onboarding-whatsapp'),
                initialValue: draft.whatsappPhone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number',
                  helperText: 'Optional; patients reply here',
                  prefixIcon: Icon(Icons.chat_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    OnboardingValidators.indianMobile(v, optional: true),
                onSaved: (v) => controller.update(
                  (d) => d.copyWith(whatsappPhone: v ?? ''),
                ),
              ),
              TextFormField(
                key: const ValueKey('onboarding-upi'),
                initialValue: draft.upiVpa,
                decoration: const InputDecoration(
                  labelText: 'UPI id',
                  helperText: 'Optional; prints a QR on invoices',
                  prefixIcon: Icon(Icons.qr_code_2_outlined),
                ),
                validator: OnboardingValidators.upiVpa,
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(upiVpa: v ?? '')),
              ),
              TextFormField(
                key: const ValueKey('onboarding-gstin'),
                initialValue: draft.gstin,
                decoration: const InputDecoration(
                  labelText: 'GSTIN',
                  helperText: 'Optional; leave blank if not GST registered',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: OnboardingValidators.gstin,
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(gstin: v ?? '')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
