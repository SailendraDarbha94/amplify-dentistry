// meta.ts
// Meta WhatsApp Cloud API: template payload building, sending, response parsing.
// Send contract (from the template export):
//   { messaging_product: 'whatsapp', to: '<e164 without +>', type: 'template',
//     template: { name: metaName, language: { code }, components: [ { type: 'body',
//       parameters: bodyParams.map(v => ({ type: 'text', text: vars[v] })) } ] } }

import type { ExportedTemplate } from './templates.ts';

export const GRAPH_API_VERSION = 'v21.0';
export const GRAPH_API_BASE = 'https://graph.facebook.com';

export interface TemplatePayload {
  messaging_product: 'whatsapp';
  to: string;
  type: 'template';
  template: {
    name: string;
    language: { code: string };
    components?: Array<{
      type: 'body';
      parameters: Array<{ type: 'text'; text: string }>;
    }>;
  };
}

export class MissingVariableError extends Error {
  constructor(public readonly templateCode: string, public readonly missing: string[]) {
    super(`template ${templateCode} is missing variables: ${missing.join(', ')}`);
    this.name = 'MissingVariableError';
  }
}

/** `+91 98765 43210` -> `919876543210`. Throws on anything that is not 7-15 digits. */
export function toWaRecipient(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 7 || digits.length > 15) {
    throw new RangeError(`not an E.164 phone number: ${phone}`);
  }
  return digits;
}

/**
 * Meta rejects parameters with newlines, tabs or more than four consecutive spaces and caps them at
 * 1024 characters; collapse whitespace rather than fail a reminder over a stray line break.
 */
export function sanitiseParameter(value: string): string {
  return value.replace(/[\r\n\t]+/g, ' ').replace(/ {2,}/g, ' ').trim().slice(0, 1024);
}

/** Builds the Cloud API template message for one queued row. */
export function buildTemplatePayload(
  args: { to: string; template: ExportedTemplate; variables: Record<string, string | undefined> },
): TemplatePayload {
  const { to, template, variables } = args;
  const missing = template.bodyParams.filter((name) => {
    const v = variables[name];
    return v === undefined || v === null || String(v).trim() === '';
  });
  if (missing.length > 0) throw new MissingVariableError(template.code, missing);

  const payload: TemplatePayload = {
    messaging_product: 'whatsapp',
    to: toWaRecipient(to),
    type: 'template',
    template: {
      name: template.metaName,
      language: { code: template.language },
    },
  };
  if (template.bodyParams.length > 0) {
    payload.template.components = [{
      type: 'body',
      parameters: template.bodyParams.map((name) => ({
        type: 'text',
        text: sanitiseParameter(String(variables[name])),
      })),
    }];
  }
  return payload;
}

export type SendOutcome =
  | { ok: true; providerMessageId: string; waId?: string }
  | { ok: false; code: number | null; message: string; permanent: boolean; raw?: unknown };

/**
 * Error codes after which retrying the same payload cannot succeed: bad recipient, bad template, bad
 * parameters. Everything else (rate limits, Meta outages, token expiry the owner must fix) is retried
 * with backoff by app.record_whatsapp_result until the attempt cap.
 * https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes
 */
export const PERMANENT_ERROR_CODES: ReadonlySet<number> = new Set([
  100, // invalid parameter
  131009, // parameter value not valid
  131021, // recipient is the sender
  131026, // message undeliverable (not a WhatsApp number / opted out)
  131051, // unsupported message type
  132000, // template parameter count mismatch
  132001, // template does not exist or not approved
  132005, // hydrated template text too long
  132007, // template format character policy violated
  132012, // template parameter format mismatch
  132015, // template paused
  132016, // template disabled
  133010, // phone number not registered on Cloud API
]);

/** Classifies a Graph API response body + HTTP status without any network dependency. */
export function parseSendResponse(status: number, body: unknown): SendOutcome {
  const b = (body ?? {}) as Record<string, unknown>;
  const messages = b.messages as Array<{ id?: string }> | undefined;
  if (status >= 200 && status < 300 && messages && messages.length > 0 && messages[0].id) {
    const contacts = b.contacts as Array<{ wa_id?: string }> | undefined;
    return { ok: true, providerMessageId: messages[0].id, waId: contacts?.[0]?.wa_id };
  }
  const error = (b.error ?? {}) as Record<string, unknown>;
  const code = typeof error.code === 'number' ? error.code : null;
  const details = (error.error_data as Record<string, unknown> | undefined)?.details;
  const message = [
    code !== null ? `(#${code})` : `HTTP ${status}`,
    typeof error.message === 'string' ? error.message : 'unexpected response',
    typeof details === 'string' ? details : undefined,
  ].filter(Boolean).join(' ');
  return {
    ok: false,
    code,
    message,
    permanent: code !== null && PERMANENT_ERROR_CODES.has(code),
    raw: body,
  };
}

export interface SendArgs {
  phoneNumberId: string;
  accessToken: string;
  payload: TemplatePayload;
  fetchImpl?: typeof fetch;
  graphVersion?: string;
  timeoutMs?: number;
}

/** POSTs one template message. Network failures are reported as retryable outcomes, never thrown. */
export async function sendTemplateMessage(args: SendArgs): Promise<SendOutcome> {
  const fetchImpl = args.fetchImpl ?? fetch;
  const url = `${GRAPH_API_BASE}/${
    args.graphVersion ?? GRAPH_API_VERSION
  }/${args.phoneNumberId}/messages`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), args.timeoutMs ?? 15_000);
  try {
    const res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${args.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(args.payload),
      signal: controller.signal,
    });
    let body: unknown = null;
    try {
      body = await res.json();
    } catch {
      body = null;
    }
    return parseSendResponse(res.status, body);
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return { ok: false, code: null, message: `network: ${message}`, permanent: false };
  } finally {
    clearTimeout(timer);
  }
}
