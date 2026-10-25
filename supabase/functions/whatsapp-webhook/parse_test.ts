import { assert, assertEquals, assertFalse } from '@std/assert';
import { isConfirmation, parseWebhook, replyText } from './parse.ts';

function envelope(value: Record<string, unknown>, field = 'messages') {
  return {
    object: 'whatsapp_business_account',
    entry: [{ id: '123456789012345', changes: [{ field, value }] }],
  };
}

const metadata = { display_phone_number: '914000000001', phone_number_id: '109876543210987' };

Deno.test('status updates are parsed with timestamps, errors and pricing', () => {
  const parsed = parseWebhook(envelope({
    messaging_product: 'whatsapp',
    metadata,
    statuses: [
      {
        id: 'wamid.SENT',
        status: 'sent',
        timestamp: '1761350400',
        recipient_id: '919876543210',
        conversation: { id: 'conv1', origin: { type: 'utility' } },
        pricing: { billable: true, pricing_model: 'PMP', category: 'utility' },
      },
      {
        id: 'wamid.FAILED',
        status: 'failed',
        timestamp: '1761350460',
        recipient_id: '919876543210',
        errors: [{
          code: 131026,
          title: 'Message undeliverable',
          error_data: { details: 'Not a WhatsApp user' },
        }],
      },
      { id: 'wamid.ODD', status: 'bounced', timestamp: '1761350460' },
    ],
  }));
  assertEquals(parsed.replies, []);
  assertEquals(parsed.statuses.length, 2);
  const [sent, failed] = parsed.statuses;
  assertEquals(sent.providerMessageId, 'wamid.SENT');
  assertEquals(sent.status, 'sent');
  assertEquals(sent.timestamp.toISOString(), '2025-10-25T00:00:00.000Z');
  assertEquals(sent.recipient, '919876543210');
  assertEquals(sent.payload.pricing, { billable: true, pricing_model: 'PMP', category: 'utility' });
  assertEquals(failed.status, 'failed');
  assertEquals(failed.error, '(#131026) Message undeliverable: Not a WhatsApp user');
});

Deno.test('inbound text, quick-reply button and interactive replies become InboundReply', () => {
  const parsed = parseWebhook(envelope({
    messaging_product: 'whatsapp',
    metadata,
    contacts: [{ profile: { name: 'Asha' }, wa_id: '919111111111' }],
    messages: [
      {
        from: '919111111111',
        id: 'wamid.IN1',
        timestamp: '1761350500',
        type: 'text',
        text: { body: '1' },
        context: { from: '914000000001', id: 'wamid.SENT' },
      },
      {
        from: '919111111111',
        id: 'wamid.IN2',
        timestamp: '1761350501',
        type: 'button',
        button: { payload: '1', text: '1' },
      },
      {
        from: '919111111111',
        id: 'wamid.IN3',
        timestamp: '1761350502',
        type: 'interactive',
        interactive: { type: 'button_reply', button_reply: { id: 'confirm', title: 'Yes' } },
      },
      {
        from: '919111111111',
        id: 'wamid.IN4',
        timestamp: '1761350503',
        type: 'image',
        image: { id: 'img' },
      },
    ],
  }));
  assertEquals(parsed.statuses, []);
  assertEquals(parsed.replies.map((r) => r.text), ['1', '1', 'Yes']);
  assertEquals(parsed.replies[0].contextMessageId, 'wamid.SENT');
  assertEquals(parsed.replies[1].contextMessageId, undefined);
  assertEquals(parsed.replies[0].phoneNumberId, '109876543210987');
  assertEquals(parsed.replies[0].from, '919111111111');
  assertEquals(replyText({ type: 'sticker' }), undefined);
});

Deno.test('other change fields are reported as ignored; foreign objects yield nothing', () => {
  const parsed = parseWebhook(
    envelope(
      { event: 'APPROVED', message_template_name: 'appt_confirm' },
      'message_template_status_update',
    ),
  );
  assertEquals(parsed.ignoredFields, ['message_template_status_update']);
  assertEquals(parsed.statuses, []);
  assertEquals(parseWebhook({ object: 'page', entry: [] }), {
    statuses: [],
    replies: [],
    ignoredFields: [],
  });
  assertEquals(parseWebhook(null).statuses, []);
  assertEquals(parseWebhook('garbage').replies, []);
});

Deno.test('isConfirmation mirrors the SQL accept list', () => {
  for (const t of ['1', ' 1 ', 'Yes', 'y', 'CONFIRM', 'ok', 'haan']) assert(isConfirmation(t), t);
  for (const t of ['2', 'no', 'cancel', '', '11']) assertFalse(isConfirmation(t), t);
});
