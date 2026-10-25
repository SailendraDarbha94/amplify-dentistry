/// Which tables sync, in what order, and under which conflict policy.
/// Every table pages on the server-assigned `updated_at` (0008 adds it to
/// `audit_events` too).
///
/// The order follows the server foreign keys (`supabase/migrations/0001`):
/// parents before children so a batch never references a row the server has
/// not seen. Two cycles exist (`procedures` <-> `lab_cases` and
/// `treatment_plan_lines` <-> `procedures`); the referencing column is
/// deferred and written in a fix-up step once both sides exist.
library;

/// How a pulled row is reconciled with a local one.
///
/// "Append-only" in the domain rules (CLAUDE.md) means rows are never
/// deleted; it does not mean a row never changes. Tables whose server side
/// has no UPDATE policy (`0006`: payments, ledger entries, consents,
/// prescriptions, medical histories, tooth states) are [appendOnly] here as
/// well: nothing can change on the server, so a local copy is final. Tables
/// the server lets a member update (procedures, findings, notes, images,
/// data consents, adjustments) are [lastWriterWins], so a status transition
/// made on one phone (a procedure completed chairside) reaches every other
/// phone; a pending local edit is still protected until it has been pushed.
enum SyncConflictPolicy {
  /// Insert when absent, never overwrite a local row (immutable history; the
  /// server has no UPDATE policy for the table).
  appendOnly,

  /// Last writer wins by server `updated_at`, except that a local row with a
  /// pending outbox entry is kept until it has been pushed.
  lastWriterWins,
}

/// Sync description of one table.
class SyncTable {
  /// Creates a description.
  const SyncTable(
    this.name, {
    required this.policy,
    this.ignoreDuplicatesOnPush = false,
    this.keyColumns = const ['id'],
    this.scopeColumn = 'clinic_id',
    this.scopeNullable = false,
    this.deferredColumns = const {},
    this.jsonTextColumns = const {},
  });

  /// SQL table name (identical locally and on the server).
  final String name;

  /// Pull conflict policy.
  final SyncConflictPolicy policy;

  /// Pushed with `resolution=ignore-duplicates`: the server has no UPDATE
  /// policy for the table, so an existing row must not be rewritten.
  final bool ignoreDuplicatesOnPush;

  /// Conflict target of the upsert and the local primary key.
  final List<String> keyColumns;

  /// Column that scopes the pull to one clinic (`id` for `clinics`).
  final String scopeColumn;

  /// Whether [scopeColumn] may be null locally (platform-wide seed rows that
  /// are shipped in the app and never pushed).
  final bool scopeNullable;

  /// Columns left out of the main push and written in a fix-up step.
  final Set<String> deferredColumns;

  /// Plain text columns locally that are `jsonb` on the server.
  final Set<String> jsonTextColumns;

  /// Column used with `updated_at` for keyset paging.
  String get orderKey =>
      keyColumns.length == 1 ? keyColumns.first : 'setting_key';

  /// Whether rows are keyed by a single `id`.
  bool get hasIdKey => keyColumns.length == 1 && keyColumns.first == 'id';

  /// Composite key of an outbox `row_id` (`<clinic_id>:<setting_key>`).
  List<String> splitRowId(String rowId) {
    if (hasIdKey) return [rowId];
    final i = rowId.indexOf(':');
    return i < 0
        ? [rowId, '']
        : [rowId.substring(0, i), rowId.substring(i + 1)];
  }

  /// Outbox `row_id` for the key values of a row, inverse of [splitRowId].
  String rowIdOf(Map<String, Object?> row) =>
      keyColumns.map((c) => '${row[c]}').join(':');
}

const SyncConflictPolicy _append = SyncConflictPolicy.appendOnly;
const SyncConflictPolicy _lww = SyncConflictPolicy.lastWriterWins;

/// Every synced table in push and pull order.
const List<SyncTable> syncTables = [
  SyncTable('clinics', policy: _lww, scopeColumn: 'id'),
  SyncTable('clinic_members', policy: _lww),
  SyncTable('chairs', policy: _lww),
  SyncTable(
    'settings',
    policy: _lww,
    keyColumns: ['clinic_id', 'setting_key'],
    jsonTextColumns: {'value_json'},
  ),
  SyncTable('catalog_items', policy: _lww, scopeNullable: true),
  SyncTable('drugs', policy: _lww, scopeNullable: true),
  SyncTable('labs', policy: _lww),
  SyncTable('patients', policy: _lww),
  SyncTable('appointments', policy: _lww),
  SyncTable('visits', policy: _lww),
  SyncTable('medical_histories', policy: _append, ignoreDuplicatesOnPush: true),
  // Notes are versioned (a new row per version) but the sign-off lands on
  // the existing row, so the signature must propagate.
  SyncTable('clinical_notes', policy: _lww),
  SyncTable('treatment_plans', policy: _lww),
  SyncTable(
    'treatment_plan_lines',
    policy: _lww,
    deferredColumns: {'procedure_id'},
  ),
  // Status transitions (planned -> completed, deleted with a reason) made on
  // another device must be visible here; the server refuses row deletes and
  // the local outbox protects an unpushed edit.
  SyncTable('procedures', policy: _lww, deferredColumns: {'lab_case_id'}),
  SyncTable('lab_cases', policy: _lww),
  SyncTable(
    'tooth_state_records',
    policy: _append,
    ignoreDuplicatesOnPush: true,
  ),
  SyncTable('findings', policy: _lww),
  // Exams are snapshots (saveExam refuses an existing id); the puller
  // rebuilds the `perio_site_readings` index for every inserted exam.
  SyncTable('perio_exams', policy: _append),
  SyncTable('estimates', policy: _lww),
  SyncTable('consent_records', policy: _append, ignoreDuplicatesOnPush: true),
  // DPDP withdrawal is a timestamp on the existing consent row.
  SyncTable('data_consents', policy: _lww),
  SyncTable('image_records', policy: _lww),
  SyncTable('implant_records', policy: _lww),
  SyncTable('invoices', policy: _lww),
  SyncTable('payments', policy: _append, ignoreDuplicatesOnPush: true),
  SyncTable('adjustments', policy: _lww),
  SyncTable('ledger_entries', policy: _append, ignoreDuplicatesOnPush: true),
  SyncTable('prescriptions', policy: _append, ignoreDuplicatesOnPush: true),
  SyncTable('recalls', policy: _lww),
  // The server owns WhatsApp delivery state (0008): sent/delivered/failed
  // must reach every phone, so this is LWW rather than append-only. A local
  // cancel still wins until pushed, and the server never regresses a sent
  // row on replay.
  SyncTable('message_logs', policy: _lww),
  SyncTable(
    'sterilisation_cycles',
    policy: _append,
    ignoreDuplicatesOnPush: true,
  ),
  SyncTable('licences', policy: _lww),
  SyncTable('audit_events', policy: _append),
];

/// Lookup by table name.
final Map<String, SyncTable> syncTablesByName = {
  for (final t in syncTables) t.name: t,
};

/// Table names in sync order.
final List<String> syncTableOrder = [for (final t in syncTables) t.name];

/// One upsert pass over a table during push.
class PushStep {
  /// Creates a step.
  const PushStep(
    this.table, {
    this.excludeColumns = const {},
    this.onlyColumns,
    this.isFinal = true,
  });

  /// Table description.
  final SyncTable table;

  /// Columns left out of the payload (deferred to a fix-up step).
  final Set<String> excludeColumns;

  /// Fix-up step: send only these columns (plus the key) for rows where at
  /// least one of them is non-null.
  final Set<String>? onlyColumns;

  /// Whether the table's outbox entries are acknowledged after this step.
  final bool isFinal;

  /// Whether this is a fix-up pass.
  bool get isFixup => onlyColumns != null;
}

/// Fix-up steps that run once the named table has been pushed.
const Map<String, List<MapEntry<String, Set<String>>>> _fixupsAfter = {
  'procedures': [
    MapEntry('treatment_plan_lines', {'procedure_id'}),
  ],
  'lab_cases': [
    MapEntry('procedures', {'lab_case_id'}),
  ],
};

/// The push plan: main steps in [syncTables] order with deferred columns
/// removed, fix-up steps inserted after their dependency, and `isFinal`
/// set on the last step of each table.
List<PushStep> buildPushPlan() {
  final steps = <PushStep>[];
  for (final table in syncTables) {
    steps.add(PushStep(table, excludeColumns: table.deferredColumns));
    for (final fix in _fixupsAfter[table.name] ?? const []) {
      steps.add(PushStep(syncTablesByName[fix.key]!, onlyColumns: fix.value));
    }
  }
  final lastIndex = <String, int>{};
  for (var i = 0; i < steps.length; i++) {
    lastIndex[steps[i].table.name] = i;
  }
  return [
    for (var i = 0; i < steps.length; i++)
      PushStep(
        steps[i].table,
        excludeColumns: steps[i].excludeColumns,
        onlyColumns: steps[i].onlyColumns,
        isFinal: lastIndex[steps[i].table.name] == i,
      ),
  ];
}
