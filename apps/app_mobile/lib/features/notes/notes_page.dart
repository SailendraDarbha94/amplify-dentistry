import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'medical_history_model.dart';
import 'note_editor_model.dart';
import 'notes_providers.dart';
import 'photos/photo_gallery.dart';
import 'red_flags.dart';

/// Patient notes hub: red-flag banners on top, then tabs for clinical notes,
/// medical history and photos. The FAB follows the tab.
class NotesPage extends ConsumerStatefulWidget {
  /// Creates the page for [patientId].
  const NotesPage({super.key, required this.patientId});

  /// Patient.
  final String patientId;

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _base => '/patients/${widget.patientId}/notes';

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final patient = ref.watch(notesPatientProvider(widget.patientId)).value;
    final flags = ref.watch(patientRedFlagsProvider(widget.patientId));
    final fab = switch (_tabs.index) {
      0 => FloatingActionButton.extended(
        key: const ValueKey('notes-new'),
        onPressed: () => context.push('$_base/new'),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('New note'),
      ),
      1 => FloatingActionButton.extended(
        key: const ValueKey('notes-history-edit'),
        onPressed: () => context.push('$_base/history'),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Update history'),
      ),
      _ => FloatingActionButton.extended(
        key: const ValueKey('photos-add'),
        onPressed: () => context.push('$_base/photos/new'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add photo'),
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(patient == null ? s.notes : patient.displayName),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: s.notes),
            const Tab(text: 'History'),
            const Tab(text: 'Photos'),
          ],
        ),
      ),
      floatingActionButton: fab,
      body: Column(
        children: [
          if (flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: RedFlagBanners(flags: flags),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _NotesList(patientId: widget.patientId),
                _HistorySummary(patientId: widget.patientId),
                PhotoGallery(patientId: widget.patientId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesForPatientProvider(patientId));
    final members = ref.watch(clinicMembersProvider).value ?? const [];
    final names = {for (final m in members) m.id: m.displayName};
    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.notes_outlined,
            title: 'No clinical notes yet',
            message: 'Each visit gets a case-sheet note; sign it to lock it.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = list[i];
            final draft = NoteDraft.fromNote(n);
            final headline = draft['chiefComplaint'].trim().isNotEmpty
                ? draft['chiefComplaint']
                : draft['finalDiagnosis'].trim().isNotEmpty
                ? draft['finalDiagnosis']
                : draft['treatmentDone'].trim().isNotEmpty
                ? draft['treatmentDone']
                : '${draft.filledKeys.length} sections';
            return ListTile(
              key: ValueKey('note-row-${n.id}'),
              leading: Icon(
                n.isSigned ? Icons.lock_outline : Icons.edit_note,
                color: n.isSigned ? AppColors.of(context).success : null,
              ),
              title: Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${AppFormat.dateTime(n.createdAt)} · '
                '${names[n.authorId] ?? 'Unknown'}',
              ),
              trailing: StatusBadge(
                label: n.isSigned ? 'v${n.version} signed' : 'v${n.version}',
                tone: n.isSigned ? BadgeTone.success : BadgeTone.neutral,
                dense: true,
              ),
              onTap: () => context.push('/patients/$patientId/notes/${n.id}'),
            );
          },
        );
      },
    );
  }
}

class _HistorySummary extends ConsumerWidget {
  const _HistorySummary({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(medicalHistoryProvider(patientId)).value;
    if (history == null) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No medical history recorded',
        message: 'Ask the sixteen screening questions before treatment.',
      );
    }
    final theme = Theme.of(context);
    final yes = <String>[
      if (history.diabetes)
        'Diabetes${history.hba1c == null ? '' : ' (HbA1c ${history.hba1c})'}',
      if (history.hypertension) 'Hypertension',
      if (history.cardiacCondition != null) history.cardiacCondition!,
      if (history.bleedingDisorder) 'Bleeding disorder',
      if (history.anticoagulant != null) 'On ${history.anticoagulant}',
      if (history.antiresorptive != null)
        '${history.antiresorptive} (MRONJ ${mronjRiskLabel(history.mronjRisk).toLowerCase()})',
      if (history.pregnant) 'Pregnant',
      if (history.asthma) 'Asthma',
      if (history.epilepsy) 'Epilepsy',
      if (history.thyroid) 'Thyroid',
      if (history.steroids) 'Steroids',
      if (history.hepatitis) 'Hepatitis',
      if (history.hiv) 'HIV / immunocompromised',
      if (history.smoking != SmokingStatus.never)
        'Tobacco (${history.smoking.name})',
      if (history.alcohol) 'Alcohol',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        96,
      ),
      children: [
        Text(
          'Recorded ${AppFormat.dateTime(history.recordedAt)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Allergies',
          child: history.allergies.isEmpty
              ? const Text('None recorded')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in history.allergies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          '${a.substance}'
                          '${a.allergyGroup == null ? '' : ' (${allergyGroupLabel(a.allergyGroup!)})'}'
                          '${a.reaction == null ? '' : ' · ${a.reaction}'}',
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Positive answers',
          child: yes.isEmpty
              ? const Text('No systemic conditions reported')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final y in yes) Text('• $y')],
                ),
        ),
        if (history.otherNotes != null) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(title: 'Other notes', child: Text(history.otherNotes!)),
        ],
      ],
    );
  }
}
