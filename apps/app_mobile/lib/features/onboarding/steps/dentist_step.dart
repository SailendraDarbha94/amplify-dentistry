import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_controller.dart';
import '../onboarding_draft.dart';

/// Step 2: the owner dentist whose registration number goes on every
/// prescription, certificate and receipt.
class DentistStep extends ConsumerWidget {
  /// Creates the step bound to [formKey].
  const DentistStep({super.key, required this.formKey});

  /// Form key the page validates and saves through.
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final councilHint =
        OnboardingService.defaultCouncilName(draft.stateCode) ?? 'Council';
    return Form(
      key: formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          FormSection(
            title: 'Owner dentist',
            description:
                'Your registration number is printed on prescriptions, '
                'certificates and receipts (DCI Code 3.4.1).',
            children: [
              TextFormField(
                key: const ValueKey('onboarding-dentist-name'),
                initialValue: draft.dentistName,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Dr. A. Rao',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => OnboardingValidators.required(v, 'Name'),
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(dentistName: v ?? '')),
              ),
              TextFormField(
                key: const ValueKey('onboarding-qualifications'),
                initialValue: draft.qualifications,
                decoration: const InputDecoration(
                  labelText: 'Qualifications',
                  hintText: 'BDS, MDS (Endodontics)',
                  helperText: 'Comma separated',
                ),
                textCapitalization: TextCapitalization.characters,
                onSaved: (v) => controller.update(
                  (d) => d.copyWith(qualifications: v ?? ''),
                ),
              ),
              TextFormField(
                key: const ValueKey('onboarding-registration'),
                initialValue: draft.registrationNumber,
                decoration: const InputDecoration(
                  labelText: 'State dental council registration number',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: OnboardingValidators.registrationNumber,
                onSaved: (v) => controller.update(
                  (d) => d.copyWith(registrationNumber: v ?? ''),
                ),
              ),
              TextFormField(
                key: const ValueKey('onboarding-council'),
                initialValue: draft.registrationCouncil,
                decoration: InputDecoration(
                  labelText: 'Registering council',
                  hintText: councilHint,
                  helperText: 'Optional; defaults to your state council',
                ),
                textCapitalization: TextCapitalization.words,
                onSaved: (v) => controller.update(
                  (d) => d.copyWith(registrationCouncil: v ?? ''),
                ),
              ),
              TextFormField(
                key: const ValueKey('onboarding-hpr'),
                initialValue: draft.hprId,
                decoration: const InputDecoration(
                  labelText: 'HPR id',
                  helperText:
                      'Optional (ABDM Healthcare Professional Registry)',
                ),
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(hprId: v ?? '')),
              ),
              TextFormField(
                key: const ValueKey('onboarding-dentist-phone'),
                initialValue: draft.dentistPhone,
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  helperText: 'Optional; defaults to the clinic phone',
                  prefixIcon: Icon(Icons.smartphone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    OnboardingValidators.indianMobile(v, optional: true),
                onSaved: (v) =>
                    controller.update((d) => d.copyWith(dentistPhone: v ?? '')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
