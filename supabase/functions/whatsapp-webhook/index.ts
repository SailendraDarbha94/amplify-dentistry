// whatsapp-webhook
// Meta calls this URL for every delivery status and inbound message of the WABA.
//   GET  ?hub.mode=subscribe&hub.verify_token=...&hub.challenge=...  -> echo the challenge when the
//        token is WHATSAPP_VERIFY_TOKEN (project level) or any clinic's verify token.
//   POST signed with X-Hub-Signature-256 (HMAC-SHA256 of the raw body under WHATSAPP_APP_SECRET):
//        statuses -> app.apply_whatsapp_status; replies ("1") -> app.confirm_appointment_from_reply.
// Deployed with verify_jwt = false (Meta sends no Supabase JWT); the HMAC is the authentication.
// Always answers 200 to a well-signed POST, otherwise Meta retries and eventually disables the webhook.
// No message bodies are logged; phone numbers are masked.

import { verifySignature } from '../_shared/signature.ts';
import { json, maskPhone, serviceClient } from '../_shared/supabase.ts';
import { isConfirmation, parseWebhook } from './parse.ts';

Deno.serve(async (req) => {
  const url = new URL(req.url);
  if (req.method === 'GET') return await handleVerification(url);
  if (req.method !== 'POST') return json({ error: 'GET or POST only' }, 405);

  const appSecret = Deno.env.get('WHATSAPP_APP_SECRET');
  if (!appSecret) {
    console.error('WHATSAPP_APP_SECRET is not set; refusing webhook');
    return json({ error: 'webhook not configured' }, 503);
  }
  const raw = new Uint8Array(await req.arrayBuffer());
  if (!(await verifySignature(raw, req.headers.get('x-hub-signature-256'), appSecret))) {
    return json({ error: 'bad signature' }, 401);
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder().decode(raw));
  } catch {
    return json({ error: 'bad json' }, 400);
  }

  const parsed = parseWebhook(body);
  const supabase = serviceClient();
  let applied = 0;
  let confirmed = 0;

  for (const s of parsed.statuses) {
    const { data, error } = await supabase.rpc('apply_whatsapp_status', {
      p_provider_message_id: s.providerMessageId,
      p_status: s.status,
      p_timestamp: s.timestamp.toISOString(),
      p_error: s.error ?? null,
      p_payload: Object.keys(s.payload).length > 0 ? s.payload : null,
    });
    if (error) console.error('apply_whatsapp_status failed', s.providerMessageId, error.message);
    else if (data === true) applied++;
  }

  for (const r of parsed.replies) {
    if (!isConfirmation(r.text)) {
      console.log(`whatsapp-webhook reply from ${maskPhone(r.from)} ignored (not a confirmation)`);
      continue;
    }
    const { data, error } = await supabase.rpc('confirm_appointment_from_reply', {
      p_phone: r.from,
      p_text: r.text,
      p_phone_number_id: r.phoneNumberId || null,
      p_context_message_id: r.contextMessageId ?? null,
    });
    if (error) console.error('confirm_appointment_from_reply failed', error.message);
    else if (data) {
      confirmed++;
      console.log(`whatsapp-webhook appointment ${data} confirmed by ${maskPhone(r.from)}`);
    }
  }

  return json({
    statuses: parsed.statuses.length,
    applied,
    replies: parsed.replies.length,
    confirmed,
    ignoredFields: parsed.ignoredFields,
  });
});

async function handleVerification(url: URL): Promise<Response> {
  const mode = url.searchParams.get('hub.mode');
  const token = url.searchParams.get('hub.verify_token') ?? '';
  const challenge = url.searchParams.get('hub.challenge') ?? '';
  if (mode !== 'subscribe' || !token || !challenge) {
    return json({ error: 'bad verification request' }, 400);
  }

  const projectToken = Deno.env.get('WHATSAPP_VERIFY_TOKEN');
  let ok = !!projectToken && projectToken.length === token.length && projectToken === token;
  if (!ok) {
    const { data, error } = await serviceClient().rpc('whatsapp_verify_token_matches', {
      p_token: token,
    });
    if (error) console.error('whatsapp_verify_token_matches failed', error.message);
    ok = data === true;
  }
  if (!ok) return json({ error: 'verify token mismatch' }, 403);
  return new Response(challenge, { status: 200, headers: { 'Content-Type': 'text/plain' } });
}
