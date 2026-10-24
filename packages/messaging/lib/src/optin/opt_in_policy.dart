import 'package:ampdent_core/ampdent_core.dart';

/// Outcome of an opt-in check: whether the send may proceed and why.
class SendDecision {
  /// Creates a decision.
  const SendDecision({required this.allowed, required this.reason});

  /// A positive decision.
  const SendDecision.allow(this.reason) : allowed = true;

  /// A negative decision.
  const SendDecision.deny(this.reason) : allowed = false;

  /// Whether the message may be sent.
  final bool allowed;

  /// Short machine-friendly explanation (`marketing_consent_missing`).
  final String reason;

  @override
  String toString() => 'SendDecision(${allowed ? 'allow' : 'deny'}: $reason)';
}

/// Latest [DataConsent] row per purpose, by `grantedAt` then `createdAt`.
///
/// The consent ledger is append-only: a grant, a decline and a later
/// withdrawal are separate rows, so only the newest row per purpose speaks.
Map<DataPurpose, DataConsent> latestConsentsByPurpose(
  Iterable<DataConsent> consents,
) {
  final latest = <DataPurpose, DataConsent>{};
  for (final c in consents) {
    final current = latest[c.purpose];
    if (current == null || _isNewer(c, current)) latest[c.purpose] = c;
  }
  return latest;
}

bool _isNewer(DataConsent a, DataConsent b) {
  final byGrant = a.grantedAt.compareTo(b.grantedAt);
  if (byGrant != 0) return byGrant > 0;
  return a.createdAt.compareTo(b.createdAt) > 0;
}

/// Whether the newest row for [purpose] is granted and not withdrawn.
bool hasActiveConsent(Iterable<DataConsent> consents, DataPurpose purpose) =>
    latestConsentsByPurpose(consents)[purpose]?.isActive ?? false;

/// DPDP opt-in rules for outbound messages, by Meta template category.
///
/// - Utility and authentication messages need an active
///   [DataPurpose.appointmentReminders] or [DataPurpose.treatmentRecords]
///   consent, or the caller's `impliedConsent` flag (see [canSend]).
/// - Marketing needs an active [DataPurpose.marketing] consent and is never
///   sent where a minor's messages are routed to a guardian.
/// - Service messages are replies inside the 24-hour customer window the
///   patient opened, so they need no stored consent.
/// - A minor whose messages are not routed to the guardian is never messaged.
abstract final class OptInPolicy {
  /// Decides whether a [category] message may be sent to this patient.
  ///
  /// [consents] is the patient's full [DataConsent] ledger (every purpose,
  /// every grant/withdrawal row); only the newest row per purpose counts.
  ///
  /// [isMinorRoutedToGuardian] is true when the patient is under 18 and the
  /// destination phone is the guardian's; marketing is then refused outright
  /// (DPDP s.9 bars targeted advertising to children). [isMinor] without
  /// routing to a guardian is refused for every category.
  ///
  /// [impliedConsent] lets the caller assert that an existing patient, on the
  /// books before the DPDP notice was introduced, has an implied consent for
  /// transactional messages about their own care (DPDP s.7(a), legitimate use
  /// for a purpose the data principal voluntarily provided data for). It
  /// applies to utility and authentication only, never marketing. Callers
  /// should set it from the clinic's migration flag and drop it once the
  /// patient has seen the notice.
  static SendDecision canSend({
    required MessageCategory category,
    required Iterable<DataConsent> consents,
    required bool isMinorRoutedToGuardian,
    bool isMinor = false,
    bool impliedConsent = false,
  }) {
    if (isMinor && !isMinorRoutedToGuardian) {
      return const SendDecision.deny('minor_not_routed_to_guardian');
    }
    final latest = latestConsentsByPurpose(consents);
    switch (category) {
      case MessageCategory.service:
        return const SendDecision.allow('service_reply_within_window');
      case MessageCategory.utility:
      case MessageCategory.authentication:
        if (_active(latest, DataPurpose.appointmentReminders)) {
          return const SendDecision.allow('appointment_reminders_consent');
        }
        if (_active(latest, DataPurpose.treatmentRecords)) {
          return const SendDecision.allow('treatment_records_consent');
        }
        if (impliedConsent) {
          return const SendDecision.allow('implied_consent_existing_patient');
        }
        return const SendDecision.deny('transactional_consent_missing');
      case MessageCategory.marketing:
        if (isMinorRoutedToGuardian) {
          return const SendDecision.deny('marketing_to_minor_forbidden');
        }
        final marketing = latest[DataPurpose.marketing];
        if (marketing == null || !marketing.granted) {
          return const SendDecision.deny('marketing_consent_missing');
        }
        if (marketing.withdrawnAt != null) {
          return const SendDecision.deny('marketing_consent_withdrawn');
        }
        return const SendDecision.allow('marketing_consent');
    }
  }

  static bool _active(Map<DataPurpose, DataConsent> latest, DataPurpose p) =>
      latest[p]?.isActive ?? false;
}
