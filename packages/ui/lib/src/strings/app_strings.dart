import 'package:flutter/widgets.dart';

import 'app_strings_en.dart';
import 'app_strings_scope.dart';

/// User-facing strings. English lives in `app_strings_en.dart` as
/// [appStringsEn]; Hindi and Telugu will be further const tables selected
/// through [AppStringsScope]. No codegen, no ARB files.
@immutable
class AppStrings {
  /// Creates a string table; see [appStringsEn] for the English values.
  const AppStrings({
    required this.localeCode,
    required this.appName,
    required this.save,
    required this.cancel,
    required this.next,
    required this.back,
    required this.done,
    required this.confirm,
    required this.delete,
    required this.edit,
    required this.add,
    required this.close,
    required this.retry,
    required this.skip,
    required this.clear,
    required this.ok,
    required this.yes,
    required this.no,
    required this.patients,
    required this.patient,
    required this.newPatient,
    required this.schedule,
    required this.today,
    required this.appointment,
    required this.chart,
    required this.findings,
    required this.procedures,
    required this.plan,
    required this.treatmentPlan,
    required this.estimate,
    required this.consent,
    required this.notes,
    required this.prescription,
    required this.bill,
    required this.invoice,
    required this.payment,
    required this.receipt,
    required this.ledger,
    required this.recall,
    required this.lab,
    required this.labCase,
    required this.settings,
    required this.more,
    required this.offline,
    required this.online,
    required this.syncing,
    required this.synced,
    required this.pendingChanges,
    required this.notSyncedYet,
    required this.changeWaiting,
    required this.changesWaiting,
    required this.syncFailed,
    required this.search,
    required this.searchHint,
    required this.searchPatientsHint,
    required this.noResults,
    required this.nothingHere,
    required this.loading,
    required this.somethingWentWrong,
    required this.tryAgain,
    required this.required,
    required this.optional,
    required this.invalidPhone,
    required this.invalidValue,
    required this.name,
    required this.phone,
    required this.age,
    required this.gender,
    required this.dateOfBirth,
    required this.guardian,
    required this.address,
    required this.amount,
    required this.total,
    required this.discount,
    required this.gst,
    required this.paid,
    required this.due,
    required this.balance,
    required this.cash,
    required this.upi,
    required this.card,
    required this.planned,
    required this.inProgress,
    required this.completed,
    required this.existing,
    required this.accepted,
    required this.cancelled,
    required this.overdue,
    required this.draft,
    required this.tooth,
    required this.teeth,
    required this.surface,
    required this.selectAll,
    required this.deselectAll,
    required this.deleteConfirmTitle,
    required this.deleteConfirmMessage,
    required this.discardChangesTitle,
    required this.discardChangesMessage,
    required this.discard,
    required this.keepEditing,
  });

  /// Returns the strings for the nearest [AppStringsScope], or English.
  static AppStrings of(BuildContext context) =>
      AppStringsScope.maybeOf(context) ?? appStringsEn;

  /// English table shortcut.
  static const AppStrings en = appStringsEn;

  /// BCP-47 language code of this table (`en`, later `hi`, `te`).
  final String localeCode;

  /// Product name.
  final String appName;

  // Common actions.
  /// Primary save action.
  final String save;

  /// Cancel action.
  final String cancel;

  /// Advance one step.
  final String next;

  /// Go back one step.
  final String back;

  /// Finish a flow or close a keypad.
  final String done;

  /// Confirm a sheet.
  final String confirm;

  /// Soft-delete action.
  final String delete;

  /// Edit action.
  final String edit;

  /// Add action.
  final String add;

  /// Close action.
  final String close;

  /// Retry after an error.
  final String retry;

  /// Skip an optional step.
  final String skip;

  /// Clear a field or filter.
  final String clear;

  /// Acknowledge.
  final String ok;

  /// Affirmative.
  final String yes;

  /// Negative.
  final String no;

  // Navigation and features.
  /// Patients tab.
  final String patients;

  /// A single patient.
  final String patient;

  /// New patient action.
  final String newPatient;

  /// Schedule tab.
  final String schedule;

  /// Today label.
  final String today;

  /// Appointment noun.
  final String appointment;

  /// Odontogram tab.
  final String chart;

  /// Findings section.
  final String findings;

  /// Procedures section.
  final String procedures;

  /// Treatment-plan tab (short).
  final String plan;

  /// Treatment plan (long).
  final String treatmentPlan;

  /// Estimate noun.
  final String estimate;

  /// Consent tab.
  final String consent;

  /// Clinical notes.
  final String notes;

  /// Prescription noun.
  final String prescription;

  /// Billing tab (short).
  final String bill;

  /// Invoice noun.
  final String invoice;

  /// Payment noun.
  final String payment;

  /// Receipt noun.
  final String receipt;

  /// Patient ledger.
  final String ledger;

  /// Recall tab.
  final String recall;

  /// Lab tab.
  final String lab;

  /// A lab case.
  final String labCase;

  /// Settings tab.
  final String settings;

  /// Overflow destination.
  final String more;

  // Connectivity.
  /// Offline state.
  final String offline;

  /// Online state.
  final String online;

  /// Sync in progress.
  final String syncing;

  /// Everything synced.
  final String synced;

  /// Suffix after a count: "3 changes waiting to sync".
  final String pendingChanges;

  /// Banner lead while no sync backend exists: nothing has left the device.
  final String notSyncedYet;

  /// Singular suffix after a count: "1 change waiting".
  final String changeWaiting;

  /// Plural suffix after a count: "3 changes waiting".
  final String changesWaiting;

  /// Sync failure.
  final String syncFailed;

  // Search and lists.
  /// Search verb.
  final String search;

  /// Generic search hint.
  final String searchHint;

  /// Patient search hint.
  final String searchPatientsHint;

  /// Empty search result.
  final String noResults;

  /// Empty list.
  final String nothingHere;

  /// Loading indicator label.
  final String loading;

  /// Generic error title.
  final String somethingWentWrong;

  /// Generic error retry label.
  final String tryAgain;

  // Validation.
  /// Required field.
  final String required;

  /// Optional field.
  final String optional;

  /// Phone validation.
  final String invalidPhone;

  /// Generic validation.
  final String invalidValue;

  // Patient fields.
  /// Name field.
  final String name;

  /// Phone field.
  final String phone;

  /// Age field.
  final String age;

  /// Gender field.
  final String gender;

  /// Date of birth field.
  final String dateOfBirth;

  /// Guardian field.
  final String guardian;

  /// Address field.
  final String address;

  // Money.
  /// Amount label.
  final String amount;

  /// Total label.
  final String total;

  /// Discount label.
  final String discount;

  /// GST label.
  final String gst;

  /// Paid label.
  final String paid;

  /// Due label.
  final String due;

  /// Balance label.
  final String balance;

  /// Cash payment mode.
  final String cash;

  /// UPI payment mode.
  final String upi;

  /// Card payment mode.
  final String card;

  // Statuses.
  /// Planned status.
  final String planned;

  /// In-progress status.
  final String inProgress;

  /// Completed status.
  final String completed;

  /// Existing work status.
  final String existing;

  /// Accepted status.
  final String accepted;

  /// Cancelled status.
  final String cancelled;

  /// Overdue status.
  final String overdue;

  /// Draft status.
  final String draft;

  // Dental.
  /// Tooth singular.
  final String tooth;

  /// Tooth plural.
  final String teeth;

  /// Surface label.
  final String surface;

  /// Select-all action.
  final String selectAll;

  /// Deselect-all action.
  final String deselectAll;

  // Confirmations.
  /// Delete confirmation title.
  final String deleteConfirmTitle;

  /// Delete confirmation body.
  final String deleteConfirmMessage;

  /// Discard confirmation title.
  final String discardChangesTitle;

  /// Discard confirmation body.
  final String discardChangesMessage;

  /// Discard action.
  final String discard;

  /// Keep-editing action.
  final String keepEditing;

  /// "3 changes waiting to sync" style sentence.
  String pendingChangesCount(int count) => '$count $pendingChanges';

  /// "1 change waiting" / "3 changes waiting".
  String changesWaitingCount(int count) =>
      '$count ${count == 1 ? changeWaiting : changesWaiting}';
}
