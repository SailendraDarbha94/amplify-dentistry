import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'compliance_labels.dart';
import 'licence_document_store.dart';

/// Bottom sheet that creates or edits a [Licence]. Returns the unsaved
/// licence; the caller writes it through the repository.
class LicenceFormSheet extends StatefulWidget {
  /// Creates the form.
  const LicenceFormSheet({
    super.key,
    required this.clinicId,
    this.existing,
    this.documents,
    this.clock = DateTime.now,
  });

  /// Owning clinic.
  final String clinicId;

  /// Licence being edited, or null for a new one.
  final Licence? existing;

  /// Photo store; defaults to the device camera/gallery.
  final LicenceDocumentStore? documents;

  /// Clock; override in tests.
  final DateTime Function() clock;

  /// Shows the sheet; resolves to the draft licence or null when dismissed.
  static Future<Licence?> show(
    BuildContext context, {
    required String clinicId,
    Licence? existing,
    LicenceDocumentStore? documents,
    DateTime Function() clock = DateTime.now,
  }) => showModalBottomSheet<Licence>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => LicenceFormSheet(
      clinicId: clinicId,
      existing: existing,
      documents: documents,
      clock: clock,
    ),
  );

  @override
  State<LicenceFormSheet> createState() => _LicenceFormSheetState();
}

class _LicenceFormSheetState extends State<LicenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final String _id = widget.existing?.id ?? newId();
  late LicenceKind _kind =
      widget.existing?.kind ?? LicenceKind.aerbRegistration;
  late final _identifier = TextEditingController(
    text: widget.existing?.identifier ?? '',
  );
  late final _authority = TextEditingController(
    text: widget.existing?.authority ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime? _issuedAt = widget.existing?.issuedAt;
  late DateTime? _expiresAt = widget.existing?.expiresAt;
  late DateTime? _qaDueAt = widget.existing?.qaDueAt;
  late String? _documentPath = widget.existing?.documentPath;
  bool _attaching = false;

  @override
  void dispose() {
    _identifier.dispose();
    _authority.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    DateTime? current,
    ValueChanged<DateTime?> onPicked,
  ) async {
    final now = widget.clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      onPicked(DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _attaching = true);
    final store = widget.documents ?? LicenceDocumentStore(clock: widget.clock);
    final path = await store.pickAndStore(source, licenceId: _id);
    if (!mounted) return;
    setState(() {
      _attaching = false;
      if (path != null) _documentPath = path;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = widget.clock().toUtc();
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.of(context).pop(
      Licence(
        id: _id,
        clinicId: widget.clinicId,
        kind: _kind,
        identifier: _identifier.text.trim(),
        authority: text(_authority),
        issuedAt: _issuedAt,
        expiresAt: _expiresAt,
        qaDueAt: _qaDueAt,
        documentPath: _documentPath,
        note: text(_note),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final insets = MediaQuery.viewInsetsOf(context);
    final fileName = _documentPath?.split(RegExp(r'[\\/]')).last;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Add licence' : 'Edit licence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const FormGap(),
              DropdownButtonFormField<LicenceKind>(
                key: const ValueKey('licence-kind'),
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: [
                  for (final k in LicenceKind.values)
                    DropdownMenuItem(
                      value: k,
                      child: Text(licenceKindLabel(k)),
                    ),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('licence-identifier'),
                controller: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Licence / registration number',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? s.required : null,
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('licence-authority'),
                controller: _authority,
                decoration: const InputDecoration(
                  labelText: 'Issuing authority',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const FormGap(),
              _DateField(
                key: const ValueKey('licence-issued'),
                label: 'Issued',
                value: _issuedAt,
                onTap: () =>
                    _pickDate(_issuedAt, (d) => setState(() => _issuedAt = d)),
                onClear: () => setState(() => _issuedAt = null),
              ),
              _DateField(
                key: const ValueKey('licence-expires'),
                label: 'Expires',
                value: _expiresAt,
                onTap: () => _pickDate(
                  _expiresAt,
                  (d) => setState(() => _expiresAt = d),
                ),
                onClear: () => setState(() => _expiresAt = null),
              ),
              _DateField(
                key: const ValueKey('licence-qa'),
                label: 'QA test due',
                value: _qaDueAt,
                onTap: () =>
                    _pickDate(_qaDueAt, (d) => setState(() => _qaDueAt = d)),
                onClear: () => setState(() => _qaDueAt = null),
              ),
              const FormGap(),
              OutlinedButton.icon(
                key: const ValueKey('licence-attach'),
                onPressed: _attaching ? null : _attach,
                icon: Icon(
                  fileName == null
                      ? Icons.add_a_photo_outlined
                      : Icons.photo_outlined,
                ),
                label: Text(
                  fileName ?? 'Attach document photo',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const FormGap(),
              TextFormField(
                key: const ValueKey('licence-note'),
                controller: _note,
                decoration: InputDecoration(labelText: s.notes),
              ),
              const SizedBox(height: AppSpacing.lg),
              BigActionButton(
                key: const ValueKey('licence-save'),
                label: s.save,
                icon: Icons.check,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.event_outlined),
    title: Text(label),
    subtitle: Text(value == null ? 'Not set' : AppFormat.date(value!)),
    trailing: value == null
        ? null
        : IconButton(
            tooltip: context.strings.clear,
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
    onTap: onTap,
  );
}
