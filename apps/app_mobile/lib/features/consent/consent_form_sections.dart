import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'consent_model.dart';

/// Header card: which template, which procedures and teeth, position in the
/// queue when several consents are being taken in a row.
class ConsentGroupHeader extends StatelessWidget {
  /// Creates the header.
  const ConsentGroupHeader({
    super.key,
    required this.group,
    required this.notation,
    required this.index,
    required this.count,
  });

  /// The group being signed.
  final ConsentGroup group;

  /// Clinic display notation.
  final ToothNotation notation;

  /// 0-based position in the queue.
  final int index;

  /// Queue length.
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teeth = group.teeth;
    return SectionCard(
      title: group.template.title,
      subtitle: count > 1 ? 'Consent ${index + 1} of $count' : null,
      trailing: StatusBadge(label: 'v${group.template.version}', dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.procedures.isEmpty)
            Text('No specific procedure', style: theme.textTheme.bodyMedium)
          else
            for (final p in group.procedures)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  p.tooth == null && p.teeth.isEmpty
                      ? p.name
                      : '${p.name}  (${notation.formatAll([if (p.tooth != null) p.tooth!, ...p.teeth])})',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          if (teeth.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${context.strings.teeth}: ${notation.formatAll(teeth)}',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ],
      ),
    );
  }
}

/// Language chips; languages without shipped templates are disabled.
class ConsentLanguageSelector extends StatelessWidget {
  /// Creates the selector.
  const ConsentLanguageSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Selected language code.
  final String value;

  /// Called with the new code.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (code, label) in consentLanguages)
          ChoiceChip(
            key: ValueKey('consent-language-$code'),
            label: Text(
              consentLanguageAvailable(code)
                  ? label
                  : '$label (${ConsentStrings.languageComing})',
            ),
            selected: value == code,
            onSelected: consentLanguageAvailable(code)
                ? (_) => onChanged(code)
                : null,
          ),
      ],
    );
  }
}

/// The full rendered consent text in a bordered, scrollable box.
class ConsentTextView extends StatelessWidget {
  /// Creates the view.
  const ConsentTextView({super.key, required this.text, this.maxHeight = 280});

  /// Rendered text.
  final String text;

  /// Box height cap so the rest of the form stays reachable.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadii.mdAll,
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Text(
          text,
          key: const ValueKey('consent-text'),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ),
    );
  }
}

/// Signer capacity chips with the under-18 self-consent block.
class SignerRelationSelector extends StatelessWidget {
  /// Creates the selector.
  const SignerRelationSelector({
    super.key,
    required this.value,
    required this.isMinor,
    required this.onChanged,
  });

  /// Selected relation.
  final SignerRelation value;

  /// Whether the patient is under 18.
  final bool isMinor;

  /// Called with the new relation.
  final ValueChanged<SignerRelation> onChanged;

  @override
  Widget build(BuildContext context) {
    final blocked = isMinor && value == SignerRelation.self;
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final r in SignerRelation.values)
              ChoiceChip(
                key: ValueKey('consent-relation-${r.name}'),
                label: Text(signerRelationLabel(r)),
                selected: value == r,
                onSelected: (_) => onChanged(r),
              ),
          ],
        ),
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              key: const ValueKey('consent-minor-block'),
              children: [
                Icon(Icons.block, color: colors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    ConsentStrings.minorCannotSelfSign,
                    style: TextStyle(color: colors.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Short summary line for a saved consent (list tiles, detail header).
String consentSummary(ConsentRecord c, ToothNotation notation) {
  final template = consentTemplateByCode(c.templateCode);
  final title = template?.title ?? c.templateCode;
  final teeth = c.teeth.isEmpty ? '' : '  |  ${notation.formatAll(c.teeth)}';
  return '$title$teeth';
}

/// `Signed by Name (Parent) on 18 Oct 2026, 2:05 PM`.
String consentSignedLine(ConsentRecord c) =>
    'Signed by ${c.signerName} (${signerRelationLabel(c.signerRelation)}) '
    'on ${AppFormat.dateTime(c.signedAt)}';
