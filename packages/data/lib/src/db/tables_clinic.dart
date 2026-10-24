/// Tenant, staff, settings, audit and sync-outbox tables.
///
/// Every table maps straight onto its `ampdent_core` entity through
/// `@UseRowClass`, so there is no second data class to keep in sync; the
/// deprecated `generateInsertable` flag is the only way to get a
/// `toInsertable()` for a row class that lives in another package (the
/// replacement `write_to_columns_mixins` option needs the entity to mix a
/// generated mixin in, which `ampdent_core` cannot do).
///
/// Column Dart names equal entity field names; SQL names are drift's
/// snake_case. See `converters.dart` for the storage conventions.
library;

// ignore_for_file: deprecated_member_use

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import 'converters.dart';

/// Base for every table keyed by a client-generated UUID string.
abstract class IdTable extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Base for tenant-scoped tables: `clinic_id` is NOT NULL and references the
/// clinic row. Each concrete table also declares a `(clinic_id)` index.
abstract class TenantTable extends IdTable {
  /// Owning clinic.
  TextColumn get clinicId => text().references(Clinics, #id)();
}

/// Clinics (tenants).
@UseRowClass(Clinic, generateInsertable: true)
class Clinics extends IdTable {
  TextColumn get name => text()();
  TextColumn get legalName => text().nullable()();
  TextColumn get addressLines => text().map(const StringListConverter())();
  TextColumn get city => text()();
  TextColumn get stateCode => text()();
  TextColumn get pincode => text()();
  TextColumn get phone => text()();
  TextColumn get whatsappPhone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get defaultNotation => textEnum<ToothNotation>()();
  TextColumn get timeZone => text()();
  TextColumn get upiVpa => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Dental chairs.
@TableIndex(name: 'chairs_clinic', columns: {#clinicId})
@UseRowClass(Chair, generateInsertable: true)
class Chairs extends TenantTable {
  TextColumn get name => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isActive => boolean()();
}

/// Clinic staff.
@TableIndex(name: 'clinic_members_clinic', columns: {#clinicId})
@UseRowClass(ClinicMember, generateInsertable: true)
class ClinicMembers extends TenantTable {
  TextColumn get displayName => text()();
  TextColumn get role => textEnum<ClinicRole>()();
  TextColumn get registrationNumber => text().nullable()();
  TextColumn get registrationCouncil => text().nullable()();
  TextColumn get qualifications => text().map(const StringListConverter())();
  TextColumn get hprId => text().nullable()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  RealColumn get feeSharePercent =>
      real().map(const NumConverter()).nullable()();
  BoolColumn get isActive => boolean()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Key/value settings per clinic. Values are JSON text. Known keys are the
/// constants on `SettingKeys` (GST rate table, notation, numbering counters).
@DataClassName('SettingRow')
class Settings extends Table {
  /// Owning clinic.
  TextColumn get clinicId => text().references(Clinics, #id)();

  /// Setting key (see `SettingKeys`).
  TextColumn get settingKey => text()();

  /// JSON-encoded value.
  TextColumn get valueJson => text()();

  /// Last write time.
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {clinicId, settingKey};
}

/// Kind of row change queued for sync. There is deliberately no `delete`:
/// rows are never hard-deleted, so soft deletes travel as updates.
enum OutboxOperation { insert, update }

/// Append-only queue of local writes awaiting upload. One row per entity
/// write, carrying the full JSON payload of the row after the write.
@TableIndex(
  name: 'sync_outbox_clinic_created',
  columns: {#clinicId, #createdAt},
)
@DataClassName('OutboxEntry')
class SyncOutbox extends IdTable {
  /// Owning clinic.
  TextColumn get clinicId => text()();

  /// SQL table name of the changed row.
  TextColumn get targetTable => text()();

  /// Primary key of the changed row.
  TextColumn get rowId => text()();

  /// Insert or update.
  TextColumn get operation => textEnum<OutboxOperation>()();

  /// Row JSON after the write.
  TextColumn get payload => text().map(const JsonObjectConverter())();

  /// Queue time.
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();

  /// Upload attempts so far.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last upload error, if any.
  TextColumn get lastError => text().nullable()();

  /// When the server acknowledged this row; null while pending.
  TextColumn get ackedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
}

/// Immutable audit log.
@TableIndex(name: 'audit_events_clinic', columns: {#clinicId})
@TableIndex(
  name: 'audit_events_entity',
  columns: {#clinicId, #entityType, #entityId},
)
@TableIndex(name: 'audit_events_actor', columns: {#clinicId, #actorId})
@TableIndex(name: 'audit_events_occurred', columns: {#clinicId, #occurredAt})
@UseRowClass(AuditEvent, generateInsertable: true)
class AuditEvents extends TenantTable {
  TextColumn get actorId => text()();
  TextColumn get action => textEnum<AuditAction>()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get before => text().map(const JsonObjectConverter()).nullable()();
  TextColumn get after => text().map(const JsonObjectConverter()).nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get deviceId => text()();
  TextColumn get occurredAt => text().map(const IsoUtcDateTimeConverter())();
}
