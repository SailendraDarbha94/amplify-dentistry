import { assert, assertEquals, assertFalse, assertThrows } from '@std/assert';
import {
  buildTemplatePayload,
  MissingVariableError,
  parseSendResponse,
  sanitiseParameter,
  sendTemplateMessage,
  toWaRecipient,
} from './meta.ts';
import type { ExportedTemplate } from './templates.ts';

const reminder: ExportedTemplate = {
  code: 'APPT_REMINDER_24H',
  metaName: 'appt_reminder_24h',
  language: 'en',
  category: 'UTILITY',
  bodyParams: ['patient_name', 'clinic_name', 'date', 'time'],
  buttons: [{ type: 'QUICK_REPLY', text: '1' }],
  body: 'Reminder: {patient_name} at {clinic_name} on {date} at {time}. Reply 1 to confirm.',
};

Deno.test('buildTemplatePayload follows the Meta send contract', () => {
  const payload = buildTemplatePayload({
    to: '+91 98765 43210',
    template: reminder,
    variables: {
      patient_name: 'Asha',
      clinic_name: 'Smile Dental',
      date: 'Tue 27 Oct',
      time: '10:00 am',
    },
  });
  assertEquals(payload, {
    messaging_product: 'whatsapp',
    to: '919876543210',
    type: 'template',
    template: {
      name: 'appt_reminder_24h',
      language: { code: 'en' },
      components: [{
        type: 'body',
        parameters: [
          { type: 'text', text: 'Asha' },
          { type: 'text', text: 'Smile Dental' },
          { type: 'text', text: 'Tue 27 Oct' },
          { type: 'text', text: '10:00 am' },
        ],
      }],
    },
  });
});

Deno.test('buildTemplatePayload names every missing variable and ignores extras', () => {
  const err = assertThrows(
    () =>
      buildTemplatePayload({
        to: '919876543210',
        template: reminder,
        variables: { patient_name: 'Asha', extra: 'x' },
      }),
    MissingVariableError,
  );
  assertEquals(err.missing, ['clinic_name', 'date', 'time']);
});

Deno.test('buildTemplatePayload omits components for a template without parameters', () => {
  const payload = buildTemplatePayload({
    to: '919876543210',
    template: { ...reminder, bodyParams: [], body: 'Hello.' },
    variables: {},
  });
  assertEquals(payload.template.components, undefined);
});

Deno.test('parameters are sanitised for Meta (no newlines, no long space runs, 1024 max)', () => {
  assertEquals(sanitiseParameter(' Dr.\nRao\t  Clinic   '), 'Dr. Rao Clinic');
  assertEquals(sanitiseParameter('x'.repeat(2000)).length, 1024);
});

Deno.test('toWaRecipient strips the plus and rejects garbage', () => {
  assertEquals(toWaRecipient('+919876543210'), '919876543210');
  assertEquals(toWaRecipient('91-98765-43210'), '919876543210');
  assertThrows(() => toWaRecipient('12'), RangeError);
  assertThrows(() => toWaRecipient('not a number'), RangeError);
});

Deno.test('parseSendResponse: success returns the wamid', () => {
  const out = parseSendResponse(200, {
    messaging_product: 'whatsapp',
    contacts: [{ input: '919876543210', wa_id: '919876543210' }],
    messages: [{ id: 'wamid.HBgLOTE5ODc2NTQzMjEwFQIAERgS' }],
  });
  assert(out.ok);
  assertEquals(out.providerMessageId, 'wamid.HBgLOTE5ODc2NTQzMjEwFQIAERgS');
  assertEquals(out.waId, '919876543210');
});

Deno.test('parseSendResponse: permanent vs retryable Graph errors', () => {
  const undeliverable = parseSendResponse(400, {
    error: {
      message: 'Message Undeliverable.',
      type: 'OAuthException',
      code: 131026,
      error_data: { messaging_product: 'whatsapp', details: 'Message Undeliverable.' },
      fbtrace_id: 'A1',
    },
  });
  assertFalse(undeliverable.ok);
  if (!undeliverable.ok) {
    assertEquals(undeliverable.code, 131026);
    assert(undeliverable.permanent);
    assert(undeliverable.message.startsWith('(#131026) Message Undeliverable.'));
  }

  const rateLimited = parseSendResponse(400, {
    error: { message: 'Rate limit hit', code: 130429 },
  });
  assertFalse(rateLimited.ok);
  if (!rateLimited.ok) assertFalse(rateLimited.permanent);

  const tokenExpired = parseSendResponse(401, {
    error: { message: 'Error validating access token', code: 190 },
  });
  assertFalse(tokenExpired.ok);
  if (!tokenExpired.ok) assertFalse(tokenExpired.permanent);

  const noBody = parseSendResponse(502, null);
  assertFalse(noBody.ok);
  if (!noBody.ok) {
    assertEquals(noBody.code, null);
    assertFalse(noBody.permanent);
    assertEquals(noBody.message, 'HTTP 502 unexpected response');
  }
});

Deno.test('sendTemplateMessage posts to the phone number endpoint with the bearer token', async () => {
  let seenUrl = '';
  let seenInit: RequestInit | undefined;
  const fetchImpl = ((input: string | URL | Request, init?: RequestInit) => {
    seenUrl = String(input);
    seenInit = init;
    return Promise.resolve(
      new Response(JSON.stringify({ messages: [{ id: 'wamid.X' }] }), { status: 200 }),
    );
  }) as typeof fetch;
  const payload = buildTemplatePayload({
    to: '919876543210',
    template: reminder,
    variables: { patient_name: 'A', clinic_name: 'B', date: 'C', time: 'D' },
  });
  const out = await sendTemplateMessage({
    phoneNumberId: '1098765',
    accessToken: 'tok',
    payload,
    fetchImpl,
  });
  assert(out.ok);
  assertEquals(seenUrl, 'https://graph.facebook.com/v21.0/1098765/messages');
  assertEquals((seenInit?.headers as Record<string, string>).Authorization, 'Bearer tok');
  assertEquals(JSON.parse(String(seenInit?.body)).template.name, 'appt_reminder_24h');
});

Deno.test('sendTemplateMessage reports network failures as retryable', async () => {
  const fetchImpl = (() => Promise.reject(new TypeError('connection reset'))) as typeof fetch;
  const payload = buildTemplatePayload({
    to: '919876543210',
    template: { ...reminder, bodyParams: [] },
    variables: {},
  });
  const out = await sendTemplateMessage({
    phoneNumberId: '1',
    accessToken: 't',
    payload,
    fetchImpl,
  });
  assertFalse(out.ok);
  if (!out.ok) {
    assertFalse(out.permanent);
    assert(out.message.includes('connection reset'));
  }
});
