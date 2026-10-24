/// Patient communication for AmpDent without any network code: WhatsApp/SMS
/// template catalogue, DPDP opt-in policy, E.164 phone handling, Meta India
/// cost estimates, and provider interfaces with a local outbox and a wa.me
/// deep-link implementation.
///
/// No message body ever carries clinical content; anything clinical sits
/// behind an authenticated `{link}`.
library;

export 'src/cost/message_cost.dart';
export 'src/optin/opt_in_policy.dart';
export 'src/phone/phone_numbers.dart';
export 'src/providers/deep_link_messaging_provider.dart';
export 'src/providers/messaging_provider.dart';
export 'src/providers/outbox_messaging_provider.dart';
export 'src/templates/message_template.dart';
export 'src/templates/message_templates.dart';
export 'src/templates/post_op_templates.dart';
