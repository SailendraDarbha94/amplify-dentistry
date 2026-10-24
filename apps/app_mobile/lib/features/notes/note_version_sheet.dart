import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Bottom sheet listing every version of a note chain, oldest first; tapping
/// a version returns it so the caller can open it read-only.
class NoteVersionSheet extends StatelessWidget {
  /// Creates the sheet.
  const NoteVersionSheet({
    super.key,
    required this.versions,
    required this.currentId,
    required this.authorNames,
  });

  /// Chain of versions.
  final List<ClinicalNote> versions;

  /// Id of the version currently open.
  final String currentId;

  /// Display names by member id.
  final Map<String, String> authorNames;

  /// Shows the sheet; returns the chosen version or null.
  static Future<ClinicalNote?> show(
    BuildContext context, {
    required List<ClinicalNote> versions,
    required String currentId,
    required Map<String, String> authorNames,
  }) => showModalBottomSheet<ClinicalNote>(
    context: context,
    useSafeArea: true,
    builder: (_) => NoteVersionSheet(
      versions: versions,
      currentId: currentId,
      authorNames: authorNames,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: Text('Versions', style: theme.textTheme.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final v in versions.reversed)
                  ListTile(
                    key: ValueKey('note-version-${v.version}'),
                    selected: v.id == currentId,
                    leading: CircleAvatar(child: Text('v${v.version}')),
                    title: Text(authorNames[v.authorId] ?? 'Unknown author'),
                    subtitle: Text(
                      v.isSigned
                          ? 'Signed ${AppFormat.dateTime(v.signedAt!)}'
                          : 'Unsigned · ${AppFormat.dateTime(v.updatedAt)}',
                    ),
                    trailing: v.isSigned
                        ? Icon(
                            Icons.lock_outline,
                            color: AppColors.of(context).success,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
