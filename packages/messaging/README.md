# ampdent_messaging

Patient communication for AmpDent, with no network code.

- `MessageTemplate` and `defaultTemplates`: the approved WhatsApp/SMS
  template catalogue (English; Hindi and Telugu follow under the same codes).
  Bodies never carry clinical content; anything clinical sits behind an
  authenticated `{link}`.
- `OptInPolicy.canSend`: DPDP purpose-scoped opt-in rules by Meta category.
- `PhoneNumbers`: E.164 normalisation, validation and masking for Indian
  mobiles.
- `estimateCostPaise`: Meta India rate card snapshot (re-read quarterly).
- `MessagingProvider` with `OutboxMessagingProvider` (queues to an injected
  sink), `DeepLinkMessagingProvider` (wa.me / sms: URIs for the solo-clinic
  v1 fallback) and `CloudQueueMessagingProvider` (opt-in checked, queued for
  the Meta Cloud API via sync).
- `src/cloud/`: `buildMetaTemplatePayload` (the exact Cloud API send body),
  `parseMetaWebhook` / `MetaStatusEvent` / `MetaInboundMessage` (delivery
  statuses and patient replies), `parseMetaSendResponse` / `MetaApiError`,
  and `TemplateExport` (the `supabase/functions/_shared/templates.json`
  contract).
- `MessageLogKeys`: reserved `_provider` (`cloud_api` | `deeplink`) and
  `_opt_in_reason` keys carried in `MessageLog.variables` until `MessageLog`
  grows first-class fields.

## Template export

```bash
cd packages/messaging && dart run tool/export_templates.dart
```

Rewrites `supabase/functions/_shared/templates.json` from `defaultTemplates`
(WhatsApp templates only). `metaName` is the lower_snake_case code,
`bodyParams` are the variables in body order, `metaBody` is the `{{n}}` form
to paste into Meta's template submission. `test/template_export_test.dart`
fails when the committed file is stale.

## Meta send payload

```json
{ "messaging_product": "whatsapp", "to": "919876543210", "type": "template",
  "template": { "name": "appt_reminder_24h", "language": { "code": "en" },
    "components": [ { "type": "body", "parameters": [
      { "type": "text", "text": "Ravi" }, ... ] } ] } }
```

`to` is E.164 without the `+`; parameters follow `bodyParams` order.
Parameter text is cleaned of newlines, tabs and runs of four spaces (Meta
rejects them). Nothing clinical is ever a parameter value: `{link}` is an
authenticated URL, the body names at most the procedure.

Depends only on `ampdent_core`.
