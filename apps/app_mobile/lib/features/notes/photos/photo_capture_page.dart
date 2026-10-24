import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../notes_providers.dart';
import 'photo_source.dart';
import 'photo_store.dart';
import 'tooth_picker_sheet.dart';

/// Image kinds offered in the capture flow, in tap order.
const List<ImageKind> captureImageKinds = [
  ImageKind.photoIntraoral,
  ImageKind.photoExtraoral,
  ImageKind.periapical,
  ImageKind.bitewing,
  ImageKind.occlusal,
  ImageKind.opg,
  ImageKind.cbct,
  ImageKind.scan,
  ImageKind.document,
  ImageKind.other,
];

/// Short label for an image kind.
String imageKindLabel(ImageKind kind) => switch (kind) {
  ImageKind.photoIntraoral => 'Intraoral photo',
  ImageKind.photoExtraoral => 'Extraoral photo',
  ImageKind.periapical => 'Periapical (IOPA)',
  ImageKind.bitewing => 'Bitewing',
  ImageKind.occlusal => 'Occlusal',
  ImageKind.opg => 'OPG',
  ImageKind.cbct => 'CBCT',
  ImageKind.scan => 'Scan',
  ImageKind.document => 'Document',
  ImageKind.other => 'Other',
};

/// Capture or pick a photo, then tag it: kind, teeth (clinic notation),
/// pre-operative flag, linked procedure and note. Saving compresses the file
/// into the patient's image folder and writes the record.
class PhotoCapturePage extends ConsumerStatefulWidget {
  /// Creates the page for [patientId].
  const PhotoCapturePage({super.key, required this.patientId});

  /// Patient.
  final String patientId;

  @override
  ConsumerState<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends ConsumerState<PhotoCapturePage> {
  File? _file;
  ImageKind _kind = ImageKind.photoIntraoral;
  final Set<ToothId> _teeth = {};
  bool _preOp = false;
  String? _procedureId;
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(PhotoOrigin origin) async {
    final file = await ref.read(photoSourceProvider).pick(origin);
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _pickTeeth() async {
    final picked = await ToothPickerSheet.show(
      context,
      notation: ref.read(notationProvider),
      initial: _teeth,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _teeth
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saver = PhotoSaver(
        store: ref.read(photoStoreProvider),
        clinical: ref.read(clinicalRepositoryProvider),
        ctx: ref.read(actorContextProvider),
      );
      final visit = await ref
          .read(appointmentRepositoryProvider)
          .openVisit(widget.patientId);
      await saver.save(
        source: file,
        patientId: widget.patientId,
        kind: _kind,
        teeth: _teeth.toList(),
        isPreOperative: _preOp,
        procedureId: _procedureId,
        visitId: visit?.id,
        note: _note.text,
        now: ref.read(clockProvider)(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Photo saved')));
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
    final notation = ref.watch(notationProvider);
    final procedures =
        ref.watch(linkableProceduresProvider(widget.patientId)).value ??
        const <ProcedureRecord>[];
    final file = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('Add photo')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: file == null
                ? Row(
                    children: [
                      Expanded(
                        child: QuickActionTile(
                          key: const ValueKey('photo-camera'),
                          icon: Icons.photo_camera_outlined,
                          label: 'Camera',
                          onTap: () => _pick(PhotoOrigin.camera),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: QuickActionTile(
                          key: const ValueKey('photo-gallery'),
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          onTap: () => _pick(PhotoOrigin.gallery),
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: AppRadii.mdAll,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(
                          file,
                          key: const ValueKey('photo-preview'),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 220,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_outlined, size: 48),
                          ),
                        ),
                        IconButton.filledTonal(
                          key: const ValueKey('photo-retake'),
                          tooltip: 'Retake',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => setState(() => _file = null),
                        ),
                      ],
                    ),
                  ),
          ),
          FormSection(
            title: 'Kind',
            children: [
              ToggleChipGroup<ImageKind>(
                options: [
                  for (final k in captureImageKinds)
                    ToggleChipOption(value: k, label: imageKindLabel(k)),
                ],
                selected: {_kind},
                multiSelect: false,
                allowEmpty: false,
                onChanged: (set) => setState(() => _kind = set.first),
              ),
            ],
          ),
          FormSection(
            title: s.teeth,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('photo-teeth'),
                icon: const Icon(Icons.grid_on),
                label: Text(
                  _teeth.isEmpty
                      ? 'Tag teeth'
                      : notation.formatAll(
                          _teeth.toList()..sort(),
                          plain: true,
                        ),
                ),
                onPressed: _pickTeeth,
              ),
            ],
          ),
          SwitchListTile(
            key: const ValueKey('photo-preop'),
            title: const Text('Pre-operative'),
            subtitle: const Text('Pairs with a later photo of the same tooth'),
            value: _preOp,
            onChanged: (v) => setState(() => _preOp = v),
          ),
          Padding(
            padding: AppSpacing.horizontalGutter,
            child: DropdownButtonFormField<String?>(
              key: const ValueKey('photo-procedure'),
              initialValue: _procedureId,
              decoration: InputDecoration(
                labelText: 'Linked procedure (${s.optional})',
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('None')),
                for (final p in procedures)
                  DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(
                      p.tooth == null
                          ? p.name
                          : '${p.name} · ${notation.formatPlain(p.tooth!)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _procedureId = v),
            ),
          ),
          const FormGap(),
          Padding(
            padding: AppSpacing.horizontalGutter,
            child: TextField(
              key: const ValueKey('photo-note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Note (${s.optional})'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.screenPadding,
        child: BigActionButton(
          key: const ValueKey('photo-save'),
          label: s.save,
          loading: _saving,
          onPressed: file == null || _saving ? null : _save,
        ),
      ),
    );
  }
}
