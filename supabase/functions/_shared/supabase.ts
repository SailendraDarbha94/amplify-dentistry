// supabase.ts
// Service-role client for the Edge Functions. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected
// by the platform into every function; nothing here is ever a hard-coded credential.

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing environment variable ${name}`);
  return value;
}

export function serviceClient(): SupabaseClient {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-ampdent-function': 'edge' } },
  });
}

/**
 * True when the request carries the service-role key (or WHATSAPP_SEND_BEARER when set) as a bearer
 * token. The gateway's verify_jwt only proves a valid project JWT; this proves it is ours.
 */
export function isServiceRequest(req: Request): boolean {
  const header = req.headers.get('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) return false;
  const accepted = [Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), Deno.env.get('WHATSAPP_SEND_BEARER')]
    .filter((v): v is string => !!v);
  return accepted.some((secret) =>
    secret.length === token.length && constantTimeEqual(secret, token)
  );
}

function constantTimeEqual(a: string, b: string): boolean {
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Last four digits only; phone numbers never go to logs in full. */
export function maskPhone(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  return digits.length <= 4 ? '****' : `${'*'.repeat(digits.length - 4)}${digits.slice(-4)}`;
}
