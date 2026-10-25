import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart' show PhoneNumbers;
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/cloud_messaging.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patient_providers.dart';

/// Kind of a timeline entry.
enum TimelineKind { procedure, invoice, note, message }

/// One row of the patient timeline.
@immutable
class TimelineEvent {
  /// Creates an event.
  const TimelineEvent({
    required this.occurredAt,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.tone = BadgeTone.neutral,
    this.badge,
    this.route,
    this.id,
  });

  /// When it happened (sort key, newest first).
  final DateTime occurredAt;

  /// Entry type.
  final TimelineKind kind;

  /// Primary text.
  final String title;

  /// Secondary text.
  final String subtitle;

  /// Status badge tone.
  final BadgeTone tone;

  /// Status badge label.
  final String? badge;

  /// Where tapping goes.
  final String? route;

  /// Source row id (keys the badge for tests).
  final String? id;
}

/// Merges procedures, invoices, notes and messages into one chronological
/// list. Messages carry their delivery status as the badge.
List<TimelineEvent> buildTimeline({
  required String patientId,
  required ToothNotation notation,
  Iterable<ProcedureRecord> procedures = const [],
  Iterable<Invoice> invoices = const [],
  Iterable<ClinicalNote> notes = const [],
  Iterable<MessageLog> messages = const [],
}) {
  final events = <TimelineEvent>[
    for (final p in procedures)
      TimelineEvent(
        occurredAt: p.completedAt ?? p.startedAt ?? p.plannedAt ?? p.createdAt,
        kind: TimelineKind.procedure,
        title: p.name,
        subtitle: [
          if (p.tooth != null) notation.formatPlain(p.tooth!),
          if (p.teeth.isNotEmpty) notation.formatAll(p.teeth, plain: true),
          if (p.isMultiSitting) p.currentStageName,
          AppFormat.money(p.netFee),
        ].join('  ·  '),
        badge: AppFormat.enumLabel(p.status),
        tone: _procedureTone(p.status),
        route: '/patients/$patientId/chart',
      ),
    for (final i in invoices)
      TimelineEvent(
        occurredAt: i.issuedAt,
        kind: TimelineKind.invoice,
        title: i.number,
        subtitle:
            '${AppFormat.money(i.grandTotal)}  ·  '
            'paid ${AppFormat.money(i.amountPaid)}',
        badge: AppFormat.enumLabel(i.status),
        tone: _invoiceTone(i.status),
        route: '/patients/$patientId/billing/invoice/${i.id}',
      ),
    for (final n in notes)
      TimelineEvent(
        occurredAt: n.createdAt,
        kind: TimelineKind.note,
        title: n.chiefComplaint?.isNotEmpty == true
            ? n.chiefComplaint!
            : 'Clinical note',
        subtitle: [
          if (n.provisionalDiagnosis?.isNotEmpty == true)
            n.provisionalDiagnosis!,
          if (n.treatmentDone?.isNotEmpty == true) n.treatmentDone!,
        ].join('  ·  '),
        badge: n.isSigned ? 'Signed' : 'Draft',
        tone: n.isSigned ? BadgeTone.completed : BadgeTone.neutral,
        route: '/patients/$patientId/notes',
      ),
    for (final m in messages)
      TimelineEvent(
        occurredAt: m.deliveredAt ?? m.sentAt ?? m.createdAt,
        kind: TimelineKind.message,
        title: messageTemplateLabel(m.templateCode),
        subtitle: [
          messageChannelLabel(m.channel),
          messageProviderLabel(m),
          PhoneNumbers.mask(m.toPhone),
          if (m.error != null && m.error!.isNotEmpty) m.error!,
        ].join('  ·  '),
        badge: messageStatusLabel(m.status),
        tone: messageStatusTone(m.status),
        id: m.id,
      ),
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return events;
}

BadgeTone _procedureTone(ProcedureStatus status) => switch (status) {
  ProcedureStatus.completed => BadgeTone.completed,
  ProcedureStatus.inProgress => BadgeTone.info,
  ProcedureStatus.planned ||
  ProcedureStatus.plannedInactive ||
  ProcedureStatus.accepted => BadgeTone.planned,
  ProcedureStatus.existingCurrentProvider ||
  ProcedureStatus.existingOtherProvider => BadgeTone.existing,
  ProcedureStatus.condition => BadgeTone.caries,
  ProcedureStatus.referred || ProcedureStatus.deleted => BadgeTone.neutral,
};

BadgeTone _invoiceTone(InvoiceStatus status) => switch (status) {
  InvoiceStatus.paid => BadgeTone.success,
  InvoiceStatus.partiallyPaid => BadgeTone.warning,
  InvoiceStatus.issued => BadgeTone.info,
  InvoiceStatus.draft => BadgeTone.neutral,
  InvoiceStatus.voided => BadgeTone.danger,
};

IconData _iconFor(TimelineKind kind) => switch (kind) {
  TimelineKind.procedure => Icons.healing_outlined,
  TimelineKind.invoice => Icons.receipt_long_outlined,
  TimelineKind.note => Icons.notes_outlined,
  TimelineKind.message => Icons.chat_outlined,
};

/// Chronological list of a patient's procedures, invoices and notes.
class PatientTimeline extends ConsumerWidget {
  /// Creates the timeline for [patientId].
  const PatientTimeline({super.key, required this.patientId});

  /// The patient.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final procedures = ref.watch(patientProceduresProvider(patientId));
    final invoices = ref.watch(patientInvoicesProvider(patientId));
    final notes = ref.watch(patientNotesProvider(patientId));
    final messages = ref.watch(patientMessagesProvider(patientId));
    final notation = ref.watch(notationProvider);
    if (procedures.isLoading ||
        invoices.isLoading ||
        notes.isLoading ||
        messages.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final events = buildTimeline(
      patientId: patientId,
      notation: notation,
      procedures: procedures.value ?? const [],
      invoices: invoices.value ?? const [],
      notes: notes.value ?? const [],
      messages: messages.value ?? const [],
    );
    if (events.isEmpty) {
      return EmptyState(
        icon: Icons.timeline_outlined,
        title: s.nothingHere,
        message: 'Procedures, invoices, notes and messages will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = events[index];
        return ListTile(
          leading: Icon(_iconFor(e.kind)),
          title: Text(e.title),
          subtitle: Text(
            e.subtitle.isEmpty
                ? AppFormat.dateTime(e.occurredAt)
                : '${AppFormat.dateTime(e.occurredAt)}\n${e.subtitle}',
          ),
          isThreeLine: e.subtitle.isNotEmpty,
          trailing: e.badge == null
              ? null
              : StatusBadge(
                  key: e.id == null ? null : ValueKey('timeline-badge-${e.id}'),
                  label: e.badge!,
                  tone: e.tone,
                  dense: true,
                ),
          onTap: e.route == null ? null : () => context.push(e.route!),
        );
      },
    );
  }
}
