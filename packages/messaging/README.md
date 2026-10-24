# ampdent_messaging

Patient communication for AmpDent, with no network code yet.

- `MessageTemplate` and `defaultTemplates`: the approved WhatsApp/SMS
  template catalogue (English; Hindi and Telugu follow under the same codes).
  Bodies never carry clinical content; anything clinical sits behind an
  authenticated `{link}`.
- `OptInPolicy.canSend`: DPDP purpose-scoped opt-in rules by Meta category.
- `PhoneNumbers`: E.164 normalisation, validation and masking for Indian
  mobiles.
- `estimateCostPaise`: Meta India rate card snapshot (re-read quarterly).
- `MessagingProvider` with `OutboxMessagingProvider` (queues to an injected
  sink) and `DeepLinkMessagingProvider` (wa.me / sms: URIs for the solo-clinic
  v1 fallback).

Depends only on `ampdent_core`.
