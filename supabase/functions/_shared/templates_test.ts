import { assert, assertEquals } from '@std/assert';
import {
  allTemplates,
  findTemplate,
  metaBody,
  metaNameFor,
  validateTemplate,
} from './templates.ts';

const required = [
  'APPT_CONFIRM',
  'APPT_REMINDER_24H',
  'APPT_REMINDER_MORNING',
  'APPT_RESCHEDULED',
  'APPT_CANCELLED',
  'POST_OP_INSTRUCTIONS',
  'INVOICE_LINK',
  'RECEIPT_LINK',
  'PRESCRIPTION_LINK',
  'ESTIMATE_LINK',
  'CONSENT_LINK',
  'RECALL_DUE',
  'RECALL_OVERDUE',
  'TREATMENT_INCOMPLETE',
  'LAB_READY_SEAT_APPT',
  'REVIEW_REQUEST',
  'OTP_AUTH',
  'WELCOME_NEW_PATIENT',
];

Deno.test('the export contains every template code the app sends', () => {
  const codes = new Set(allTemplates().map((t) => t.code));
  for (const code of required) assert(codes.has(code), `missing ${code}`);
});

Deno.test('every exported template is valid for Meta submission', () => {
  for (const t of allTemplates()) {
    assertEquals(validateTemplate(t), [], t.code);
    assertEquals(t.metaName, metaNameFor(t.code));
  }
});

Deno.test('findTemplate falls back to English and returns undefined for unknown codes', () => {
  assertEquals(findTemplate('APPT_REMINDER_24H', 'te')?.language, 'en');
  assertEquals(findTemplate('APPT_REMINDER_24H')?.metaName, 'appt_reminder_24h');
  assertEquals(findTemplate('NOT_A_TEMPLATE'), undefined);
});

Deno.test('reminders carry the quick-reply "1" button and OTP is an authentication template', () => {
  assertEquals(findTemplate('APPT_REMINDER_24H')?.buttons, [{ type: 'QUICK_REPLY', text: '1' }]);
  assertEquals(findTemplate('APPT_REMINDER_MORNING')?.buttons, [{
    type: 'QUICK_REPLY',
    text: '1',
  }]);
  assertEquals(findTemplate('OTP_AUTH')?.category, 'AUTHENTICATION');
});

Deno.test('metaBody numbers placeholders in bodyParams order', () => {
  const t = findTemplate('PRESCRIPTION_LINK')!;
  assertEquals(
    metaBody(t),
    'Hi {{1}}, Dr. {{2}} at {{3}} has issued your prescription. View it securely here: {{4}}.',
  );
});

Deno.test('validateTemplate flags mismatched params, bad names and forbidden text', () => {
  const problems = validateTemplate({
    code: 'X_Y',
    metaName: 'xy',
    language: 'en',
    category: 'UTILITY',
    bodyParams: ['a'],
    buttons: [],
    body: 'AI detects {b}\nline',
  });
  assert(problems.some((p) => p.includes('metaName must be x_y')));
  assert(problems.some((p) => p.includes('do not match body placeholders')));
  assert(problems.some((p) => p.includes('newlines')));
  assert(problems.some((p) => p.includes('AI detects')));
});
