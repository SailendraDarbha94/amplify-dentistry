import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'appointment_status.dart';

/// Reason, source and notes.
class DetailsSection extends StatelessWidget {
  /// Creates the section.
  const DetailsSection({
    super.key,
    required this.reason,
    required this.notes,
    required this.source,
    required this.onReasonChanged,
    required this.onNotesChanged,
    required this.onSourceChanged,
  });

  /// Current reason.
  final String reason;

  /// Current notes.
  final String notes;

  /// Current source.
  final AppointmentSource source;

  /// Reason edited.
  final ValueChanged<String> onReasonChanged;

  /// Notes edited.
  final ValueChanged<String> onNotesChanged;

  /// Source chosen.
  final ValueChanged<AppointmentSource> onSourceChanged;

  @override
  Widget build(BuildContext context) => FormSection(
    title: 'Details',
    children: [
      TextFormField(
        key: const ValueKey('appointment-reason'),
        initialValue: reason,
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Chief complaint or planned work',
        ),
        textCapitalization: TextCapitalization.sentences,
        onChanged: onReasonChanged,
      ),
      Text('Booked via', style: Theme.of(context).textTheme.labelLarge),
      ToggleChipGroup<AppointmentSource>(
        options: [
          for (final v in AppointmentSource.values)
            ToggleChipOption(value: v, label: appointmentSourceLabel(v)),
        ],
        selected: {source},
        multiSelect: false,
        allowEmpty: false,
        onChanged: (set) {
          if (set.isNotEmpty) onSourceChanged(set.first);
        },
      ),
      TextFormField(
        key: const ValueKey('appointment-notes'),
        initialValue: notes,
        decoration: InputDecoration(labelText: context.strings.notes),
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        onChanged: onNotesChanged,
      ),
    ],
  );
}
