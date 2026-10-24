import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'note_editor_model.dart';
import 'note_section_tiles.dart';
import 'note_version_sheet.dart';
import 'notes_providers.dart';
import 'red_flags.dart';

/// Case-sheet editor. A new note gets the author and time automatically;
/// saving writes it against the patient's open visit (started if needed).
/// Signing locks the note; "Amend" unlocks a copy and the next save creates
/// version n+1 that supersedes the signed one.
class NoteEditorPage extends ConsumerStatefulWidget {
  /// Creates the editor; [noteId] null starts a new note.
  const NoteEditorPage({super.key, required this.patientId, this.noteId});

  /// Patient.
  final String patientId;

  /// Existing note to open.
  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final s in caseSheetSections) s.key: TextEditingController(),
  };
  ClinicalNote? _note;
  bool _loading = true;
  bool _amending = false;
  bool _dirty = false;
  bool _busy = false;

  bool get _locked => (_note?.isSigned ?? false) && !_amending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.noteId;
    if (id != null) {
      final note = await ref.read(clinicalRepositoryProvider).getNote(id);
      if (!mounted) return;
      if (note != null) _apply(note);
    }
    setState(() => _loading = false);
  }

  void _apply(ClinicalNote note) {
    _note = note;
    final draft = NoteDraft.fromNote(note);
    for (final e in _controllers.entries) {
      e.value.text = draft[e.key];
    }
    _dirty = false;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  NoteDraft get _draft => NoteDraft(
    sections: {for (final e in _controllers.entries) e.key: e.value.text},
  );

  NoteSaver get _saver => NoteSaver(
    clinical: ref.read(clinicalRepositoryProvider),
    appointments: ref.read(appointmentRepositoryProvider),
    ctx: ref.read(actorContextProvider),
  );

  Future<ClinicalNote?> _save({bool quiet = false}) async {
    if (_busy) return null;
    final draft = _draft;
    if (draft.isEmpty) {
      _toast('Write something before saving');
      return null;
    }
    setState(() => _busy = true);
    try {
      final saved = await _saver.save(
        patientId: widget.patientId,
        draft: draft,
        existing: _note,
        now: ref.read(clockProvider)(),
      );
      if (!mounted) return saved;
      final versioned = _note != null && saved.id != _note!.id;
      setState(() {
        _apply(saved);
        _amending = false;
      });
      if (!quiet) {
        _toast(versioned ? 'Saved as version ${saved.version}' : 'Note saved');
      }
      return saved;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sign() async {
    final saved = _dirty || _note == null ? await _save(quiet: true) : _note;
    if (saved == null || !mounted) return;
    final ok = await ConfirmSheet.show(
      context,
      title: 'Sign this note?',
      message: 'Later edits create a new version.',
      confirmLabel: 'Sign',
      icon: Icons.lock_outline,
    );
    if (!ok || !mounted) return;
    final signed = await _saver.sign(saved.id, now: ref.read(clockProvider)());
    if (!mounted) return;
    setState(() => _apply(signed));
    _toast('Note signed and locked');
  }

  Future<void> _showVersions() async {
    final note = _note;
    if (note == null) return;
    final versions = await ref
        .read(clinicalRepositoryProvider)
        .noteVersions(note.id);
    if (!mounted) return;
    final members = ref.read(clinicMembersProvider).value ?? const [];
    final chosen = await NoteVersionSheet.show(
      context,
      versions: versions,
      currentId: note.id,
      authorNames: {for (final m in members) m.id: m.displayName},
    );
    if (chosen != null && chosen.id != note.id && mounted) {
      context.pushReplacement(
        '/patients/${widget.patientId}/notes/${chosen.id}',
      );
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final s = context.strings;
    return ConfirmSheet.show(
      context,
      title: s.discardChangesTitle,
      message: s.discardChangesMessage,
      confirmLabel: s.discard,
      cancelLabel: s.keepEditing,
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    if (_loading) {
      return LoadingScaffold(appBar: AppBar(title: Text(s.notes)));
    }
    final note = _note;
    final member = ref.watch(currentMemberProvider).value;
    final members = ref.watch(clinicMembersProvider).value ?? const [];
    final authorName = note == null
        ? (member?.displayName ?? '-')
        : members
                  .where((m) => m.id == note.authorId)
                  .map((m) => m.displayName)
                  .firstOrNull ??
              member?.displayName ??
              '-';
    final flags = ref.watch(patientRedFlagsProvider(widget.patientId));
    final now = ref.watch(clockProvider)();
    final draft = _draft;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(note == null ? 'New clinical note' : 'Clinical note'),
          actions: [
            if (note != null)
              IconButton(
                key: const ValueKey('note-versions'),
                tooltip: 'Versions',
                icon: const Icon(Icons.history),
                onPressed: _showVersions,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            RedFlagBanners(flags: flags, compact: true),
            NoteMetaCard(
              authorName: authorName,
              dateTimeLabel: AppFormat.dateTime(note?.createdAt ?? now),
              version: note?.version ?? 1,
              signedLabel: note?.signedAt == null
                  ? null
                  : AppFormat.dateTime(note!.signedAt!),
              isNew: note == null,
            ),
            if (_locked)
              Padding(
                padding: AppSpacing.horizontalGutter,
                child: Text(
                  'Signed ${AppFormat.dateTime(note!.signedAt!)}. '
                  'Tap Amend to write version ${note.version + 1}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (var i = 0; i < caseSheetTopLevelSections.length; i++)
              NoteSectionTile(
                section: caseSheetTopLevelSections[i],
                controllers: _controllers,
                locked: _locked,
                initiallyExpanded:
                    i < 2 ||
                    draft[caseSheetTopLevelSections[i].key].isNotEmpty ||
                    caseSheetSubSections(caseSheetTopLevelSections[i].key)
                        .any((sub) => draft[sub.key].isNotEmpty),
                onChanged: () {
                  if (!_dirty) setState(() => _dirty = true);
                },
                onIcd10Picked: (key, code) {
                  final c = _controllers[key]!;
                  final current = c.text.trimRight();
                  final line = icd10Label(code);
                  c.text = current.isEmpty ? line : '$current\n$line';
                  setState(() => _dirty = true);
                },
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: AppSpacing.screenPadding,
          child: _locked
              ? BigActionButton(
                  key: const ValueKey('note-amend'),
                  label: 'Amend (new version)',
                  icon: Icons.edit_outlined,
                  tonal: true,
                  onPressed: () => setState(() => _amending = true),
                )
              : Row(
                  children: [
                    Expanded(
                      child: BigActionButton(
                        key: const ValueKey('note-save'),
                        label: s.save,
                        tonal: true,
                        loading: _busy,
                        onPressed: _busy ? null : _save,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: BigActionButton(
                        key: const ValueKey('note-sign'),
                        label: 'Sign',
                        icon: Icons.lock_outline,
                        onPressed: _busy ? null : _sign,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
