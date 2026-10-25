// whatsapp-send
// Drains the WhatsApp send queue: claims a batch through app.claim_whatsapp_batch (rows move to
// 'sending' atomically, so two overlapping invocations never send the same message), posts each as a
// Meta template message, and records the outcome through app.record_whatsapp_result.
// Invoked every minute by pg_cron via pg_net (0009) and callable by hand with the service-role key:
//   curl -X POST "$SUPABASE_URL/functions/v1/whatsapp-send" -H "Authorization: Bearer $SERVICE_ROLE_KEY"
// Environment: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (platform), optional WHATSAPP_SEND_BEARER,
// optional WHATSAPP_BATCH_SIZE (default 25).

import {
  buildTemplatePayload,
  MissingVariableError,
  sendTemplateMessage,
} from '../_shared/meta.ts';
import { findTemplate } from '../_shared/templates.ts';
import { isServiceRequest, json, maskPhone, serviceClient } from '../_shared/supabase.ts';

interface ClaimedRow {
  id: string;
  clinic_id: string;
  patient_id: string | null;
  template_code: string;
  category: string;
  to_phone: string;
  variables: Record<string, string>;
  attempts: number;
  patient_language: string;
  phone_number_id: string;
  waba_id: string;
  access_token: string;
}

interface Summary {
  claimed: number;
  sent: number;
  retried: number;
  failed: number;
  errors: string[];
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
  if (!isServiceRequest(req)) return json({ error: 'unauthorised' }, 401);

  const supabase = serviceClient();
  const limit = Number(Deno.env.get('WHATSAPP_BATCH_SIZE') ?? 25);
  const { data, error } = await supabase.rpc('claim_whatsapp_batch', { p_limit: limit });
  if (error) {
    console.error('claim_whatsapp_batch failed', error.message);
    return json({ error: error.message }, 500);
  }
  const rows = (data ?? []) as ClaimedRow[];
  const summary: Summary = { claimed: rows.length, sent: 0, retried: 0, failed: 0, errors: [] };

  for (const row of rows) {
    const outcome = await sendOne(row);
    const { error: recordError } = await supabase.rpc('record_whatsapp_result', {
      p_id: row.id,
      p_status: outcome.status,
      p_provider_message_id: outcome.providerMessageId ?? null,
      p_error: outcome.error ?? null,
    });
    if (recordError) {
      // The 10-minute lease will release the row for another attempt; say so loudly.
      console.error('record_whatsapp_result failed', row.id, recordError.message);
      summary.errors.push(`${row.id}: ${recordError.message}`);
    }
    if (outcome.status === 'sent') summary.sent++;
    else if (outcome.status === 'retry') summary.retried++;
    else summary.failed++;
    console.log(
      `whatsapp-send ${row.template_code} -> ${maskPhone(row.to_phone)} ${outcome.status}` +
        (outcome.error ? ` ${outcome.error}` : ''),
    );
  }
  return json(summary);
});

async function sendOne(row: ClaimedRow): Promise<{
  status: 'sent' | 'retry' | 'failed';
  providerMessageId?: string;
  error?: string;
}> {
  const template = findTemplate(row.template_code, row.patient_language);
  if (!template) {
    return { status: 'failed', error: `template ${row.template_code} is not in the export` };
  }
  let payload;
  try {
    payload = buildTemplatePayload({ to: row.to_phone, template, variables: row.variables ?? {} });
  } catch (e) {
    if (e instanceof MissingVariableError || e instanceof RangeError) {
      return { status: 'failed', error: e.message };
    }
    throw e;
  }
  const result = await sendTemplateMessage({
    phoneNumberId: row.phone_number_id,
    accessToken: row.access_token,
    payload,
  });
  if (result.ok) return { status: 'sent', providerMessageId: result.providerMessageId };
  return { status: result.permanent ? 'failed' : 'retry', error: result.message };
}
