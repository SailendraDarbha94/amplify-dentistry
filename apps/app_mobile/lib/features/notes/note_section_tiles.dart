import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'icd10_picker_sheet.dart';
import 'note_editor_model.dart';

/// Callback when the ICD-10 picker returns a code for a section.
typedef Icd10Picked = void Function(String sectionKey, Icd10Code code);

/// One collapsible case-sheet section with its multiline field, the
/// terminology sub-sections (intraoral soft/hard tissue) and an ICD-10 picker
/// for the diagnosis sections.
class NoteSectionTile extends StatelessWidget {
  /// Creates the tile for [section].
  const NoteSectionTile({
    super.key,
    required this.section,
    required this.controllers,
    required this.locked,
    required this.initiallyExpanded,
    required this.onChanged,
    required this.onIcd10Picked,
  });

  /// Top-level section.
  final CaseSheetSection section;

  /// Controllers keyed by section key (includes sub-sections).
  final Map<String, TextEditingController> controllers;

  /// Read-only when the note is signed.
  final bool locked;

  /// Open on first build (sections with text, or the first two).
  final bool initiallyExpanded;

  /// Any field in the tile changed.
  final VoidCallback onChanged;

  /// An ICD-10 code was chosen for a diagnosis section.
  final Icd10Picked onIcd10Picked;

  @override
  Widget build(BuildContext context) {
    final subs = caseSheetSubSections(section.key);
    final controller = controllers[section.key]!;
    final hasText =
        controller.text.trim().isNotEmpty ||
        subs.any((s) => controllers[s.key]!.text.trim().isNotEmpty);
    return ExpansionTile(
      key: PageStorageKey('note-section-${section.key}'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: AppSpacing.horizontalGutter,
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      title: Text(section.title),
      leading: Icon(
        hasText ? Icons.check_circle : Icons.radio_button_unchecked,
        color: hasText
            ? AppColors.of(context).success
            : Theme.of(context).colorScheme.outline,
      ),
      children: [
        _field(
          context,
          key: section.key,
          controller: controller,
          hint: section.hint,
        ),
        for (final sub in subs) ...[
          const FormGap(height: AppSpacing.sm),
          _field(
            context,
            key: sub.key,
            controller: controllers[sub.key]!,
            label: sub.title,
            hint: sub.hint,
          ),
        ],
        if (diagnosisSectionKeys.contains(section.key) && !locked)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('note-icd10-${section.key}'),
              icon: const Icon(Icons.manage_search),
              label: const Text('Add ICD-10 code'),
              onPressed: () async {
                final code = await Icd10PickerSheet.show(context);
                if (code != null) onIcd10Picked(section.key, code);
              },
            ),
          ),
      ],
    );
  }

  Widget _field(
    BuildContext context, {
    required String key,
    required TextEditingController controller,
    required String hint,
    String? label,
  }) => TextField(
    key: ValueKey('note-$key'),
    controller: controller,
    readOnly: locked,
    minLines: 2,
    maxLines: 8,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
    ),
    onChanged: (_) => onChanged(),
  );
}

/// Author, date/time, version and signed state shown above the sections.
class NoteMetaCard extends StatelessWidget {
  /// Creates the card.
  const NoteMetaCard({
    super.key,
    required this.authorName,
    required this.dateTimeLabel,
    required this.version,
    required this.signedLabel,
    required this.isNew,
  });

  /// Display name of the author.
  final String authorName;

  /// Formatted creation date/time.
  final String dateTimeLabel;

  /// Version number.
  final int version;

  /// `Signed 18 Oct 2026, 2:05 PM` or null when unsigned.
  final String? signedLabel;

  /// Not yet saved.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$authorName  ·  $dateTimeLabel',
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(
            key: const ValueKey('note-version-badge'),
            label: isNew ? 'Draft' : 'v$version',
            tone: BadgeTone.neutral,
            dense: true,
          ),
          if (signedLabel != null) ...[
            const SizedBox(width: AppSpacing.xs),
            StatusBadge(
              key: const ValueKey('note-signed-badge'),
              label: 'Signed',
              tone: BadgeTone.success,
              icon: Icons.lock_outline,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}
