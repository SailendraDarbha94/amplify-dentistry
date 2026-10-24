import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'medical_history_model.dart';
import 'medical_history_sections.dart';
import 'red_flags.dart';

/// Medical history questionnaire: the sixteen terminology questions as
/// yes/no switches with detail inputs, a live red-flag preview, and a save
/// that appends a new immutable snapshot.
class MedicalHistoryPage extends ConsumerStatefulWidget {
  /// Creates the page for [patientId].
  const MedicalHistoryPage({super.key, required this.patientId});

  /// Patient whose history is recorded.
  final String patientId;

  @override
  ConsumerState<MedicalHistoryPage> createState() => _MedicalHistoryPageState();
}

class _MedicalHistoryPageState extends ConsumerState<MedicalHistoryPage> {
  MedicalHistoryDraft? _draft;
  final Set<String> _yes = {};
  bool _saving = false;
  late final TextEditingController _otherNotes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final latest = await ref
        .read(clinicalRepositoryProvider)
        .latestMedicalHistory(widget.patientId);
    if (!mounted) return;
    final draft = MedicalHistoryDraft.fromHistory(latest);
    setState(() {
      _draft = draft;
      _yes.addAll(medicalHistoryFieldKeys.where(draft.isYes));
      _otherNotes.text = draft.otherNotes;
    });
  }

  @override
  void dispose() {
    _otherNotes.dispose();
    super.dispose();
  }

  void _update(MedicalHistoryDraft next) => setState(() => _draft = next);

  void _toggle(String key, bool yes) {
    setState(() {
      yes ? _yes.add(key) : _yes.remove(key);
      _draft = _draft!.answer(key, yes);
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      final ctx = ref.read(actorContextProvider);
      final now = ref.read(clockProvider)();
      await ref
          .read(clinicalRepositoryProvider)
          .recordMedicalHistory(
            ctx,
            draft
                .copyWith(otherNotes: _otherNotes.text)
                .toHistory(
                  id: newId(),
                  clinicId: ctx.clinicId,
                  patientId: widget.patientId,
                  recordedBy: ctx.actorId,
                  now: now,
                ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Medical history saved')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/patients/${widget.patientId}/notes');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final draft = _draft;
    if (draft == null) {
      return LoadingScaffold(
        appBar: AppBar(title: const Text('Medical history')),
      );
    }
    final now = ref.watch(clockProvider)();
    final flags = redFlagInfos(draft.preview(now));
    return Scaffold(
      appBar: AppBar(title: const Text('Medical history')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (flags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            RedFlagBanners(flags: flags, compact: true),
          ],
          Padding(
            padding: AppSpacing.screenPadding,
            child: Text(
              'Ask every question; answers are stored as a dated snapshot '
              'and never overwritten.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (var i = 0; i < medicalHistoryFieldKeys.length; i++)
            _QuestionTile(
              fieldKey: medicalHistoryFieldKeys[i],
              question: medicalHistoryQuestions[i],
              yes: _yes.contains(medicalHistoryFieldKeys[i]),
              onChanged: (v) => _toggle(medicalHistoryFieldKeys[i], v),
              detail: _yes.contains(medicalHistoryFieldKeys[i])
                  ? MedicalHistoryDetail(
                      fieldKey: medicalHistoryFieldKeys[i],
                      draft: draft,
                      onChanged: _update,
                      now: now,
                    )
                  : null,
            ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: TextField(
              key: const ValueKey('mh-other-notes'),
              controller: _otherNotes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Other notes (${s.optional})',
                hintText: 'Current medications, hospital admissions...',
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.screenPadding,
        child: BigActionButton(
          key: const ValueKey('mh-save'),
          label: s.save,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.fieldKey,
    required this.question,
    required this.yes,
    required this.onChanged,
    required this.detail,
  });

  final String fieldKey;
  final String question;
  final bool yes;
  final ValueChanged<bool> onChanged;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: ValueKey('mh-$fieldKey'),
          title: Text(question),
          value: yes,
          activeThumbColor: colors.danger,
          onChanged: onChanged,
        ),
        ?detail,
        const Divider(height: 1),
      ],
    );
  }
}
