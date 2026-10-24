import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// About page: version, data ownership statement and the export link.
class AboutPage extends StatelessWidget {
  /// Creates the page.
  const AboutPage({super.key});

  /// Shown under the app name.
  static const String version = '0.1.0';

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(s.appName, style: theme.textTheme.headlineMedium),
          Text('Version $version', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            title: 'Your data is yours',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(MobileStrings.dataOwnership),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Records are stored on this device first and work with no '
                  'network. Clinical rows are never deleted, only marked; '
                  'every change is written to an audit log you can read.',
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonalIcon(
                  key: const ValueKey('about-export'),
                  onPressed: () => context.push('/export'),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Open export'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: 'Compliance notes',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '- Registration number on every prescription, certificate '
                  'and receipt (DCI Code of Ethics 3.4.1).',
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '- Purpose-scoped data consent and a grievance route per '
                  'the Digital Personal Data Protection Act 2023.',
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '- GST classification on every invoice line; health-care '
                  'services under SAC 999312 are exempt.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
