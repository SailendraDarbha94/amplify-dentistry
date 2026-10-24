import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_controller.dart';
import 'steps/chairs_step.dart';
import 'steps/clinic_step.dart';
import 'steps/dentist_step.dart';

/// Three-step first-run flow: clinic, owner dentist, chairs. Writes the
/// clinic, member, chairs and default settings, then goes to `/today`.
class OnboardingPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const OnboardingPage({super.key});

  /// Step titles in order.
  static const List<String> stepTitles = ['Clinic', 'Dentist', 'Chairs'];

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const Logger _log = Logger('onboarding');

  final GlobalKey<FormState> _clinicForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _dentistForm = GlobalKey<FormState>();
  int _step = 0;
  bool _busy = false;

  bool get _isLast => _step == OnboardingPage.stepTitles.length - 1;

  GlobalKey<FormState>? get _currentForm => switch (_step) {
    0 => _clinicForm,
    1 => _dentistForm,
    _ => null,
  };

  Future<void> _next() async {
    final form = _currentForm?.currentState;
    if (form != null) {
      if (!form.validate()) return;
      form.save();
    }
    if (!_isLast) {
      setState(() => _step += 1);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).submit();
      _log.info('onboarding complete');
      if (mounted) context.go(homeLocation);
    } on Object catch (error, stackTrace) {
      _log.error('onboarding failed', error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(MobileStrings.setUpYourClinic),
        leading: _step > 0
            ? IconButton(
                onPressed: _busy ? null : _back,
                icon: const Icon(Icons.arrow_back),
                tooltip: s.back,
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (_step + 1) / OnboardingPage.stepTitles.length,
                  borderRadius: AppRadii.pillAll,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Step ${_step + 1} of ${OnboardingPage.stepTitles.length}: '
                  '${OnboardingPage.stepTitles[_step]}',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_step) {
              0 => ClinicStep(formKey: _clinicForm),
              1 => DentistStep(formKey: _dentistForm),
              _ => const ChairsStep(),
            },
          ),
          SafeArea(
            minimum: AppSpacing.screenPadding,
            child: BigActionButton(
              key: const ValueKey('onboarding-next'),
              label: _isLast ? 'Create clinic' : s.next,
              icon: _isLast ? Icons.check : Icons.arrow_forward,
              loading: _busy,
              onPressed: _busy ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}
