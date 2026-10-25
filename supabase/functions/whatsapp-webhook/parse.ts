// parse.ts
// Pure parsing of the Meta webhook body (object 'whatsapp_business_account') into the two things the
// platform acts on: delivery statuses for messages we sent, and inbound replies.
// https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/payload-examples

export type DeliveryStatus = 'sent' | 'delivered' | 'read' | 'failed';

export interface StatusUpdate {
  providerMessageId: string;
  status: DeliveryStatus;
  /** Meta sends unix seconds as a string. */
  timestamp: Date;
  recipient?: string;
  error?: string;
  /** pricing / conversation objects, kept for cost reporting. */
  payload: Record<string, unknown>;
}

export interface InboundReply {
  /** Sender's number, digits only (`919876543210`). */
  from: string;
  /** Text of the reply: message body, quick-reply button text or interactive reply title. */
  text: string;
  /** Our phone_number_id that received it (identifies the clinic). */
  phoneNumberId: string;
  /** wamid of the message the patient replied to, when it was a reply. */
  contextMessageId?: string;
  inboundMessageId: string;
  timestamp: Date;
}

export interface ParsedWebhook {
  statuses: StatusUpdate[];
  replies: InboundReply[];
  /** Change fields we received but do not handle (template status updates, account alerts). */
  ignoredFields: string[];
}

type AnyRecord = Record<string, unknown>;

function asRecord(v: unknown): AnyRecord {
  return typeof v === 'object' && v !== null ? v as AnyRecord : {};
}

function asArray(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

function toDate(ts: unknown): Date {
  const seconds = typeof ts === 'string' ? Number(ts) : typeof ts === 'number' ? ts : NaN;
  return Number.isFinite(seconds) && seconds > 0 ? new Date(seconds * 1000) : new Date();
}

export function isDeliveryStatus(s: unknown): s is DeliveryStatus {
  return s === 'sent' || s === 'delivered' || s === 'read' || s === 'failed';
}

function errorText(errors: unknown): string | undefined {
  const first = asRecord(asArray(errors)[0]);
  if (Object.keys(first).length === 0) return undefined;
  const code = first.code !== undefined ? `(#${first.code}) ` : '';
  const title = typeof first.title === 'string'
    ? first.title
    : typeof first.message === 'string'
    ? first.message
    : '';
  const details = asRecord(first.error_data).details;
  return `${code}${title}${typeof details === 'string' ? `: ${details}` : ''}`.trim() || undefined;
}

function parseStatus(raw: unknown): StatusUpdate | undefined {
  const s = asRecord(raw);
  if (typeof s.id !== 'string' || !isDeliveryStatus(s.status)) return undefined;
  const payload: Record<string, unknown> = {};
  if (s.pricing) payload.pricing = s.pricing;
  if (s.conversation) payload.conversation = s.conversation;
  return {
    providerMessageId: s.id,
    status: s.status,
    timestamp: toDate(s.timestamp),
    recipient: typeof s.recipient_id === 'string' ? s.recipient_id : undefined,
    error: s.status === 'failed' ? (errorText(s.errors) ?? 'failed') : undefined,
    payload,
  };
}

/** The text a patient typed or tapped; undefined for media, reactions, locations and the like. */
export function replyText(message: AnyRecord): string | undefined {
  switch (message.type) {
    case 'text':
      return typeof asRecord(message.text).body === 'string'
        ? asRecord(message.text).body as string
        : undefined;
    case 'button': {
      const b = asRecord(message.button);
      return typeof b.text === 'string'
        ? b.text
        : typeof b.payload === 'string'
        ? b.payload
        : undefined;
    }
    case 'interactive': {
      const i = asRecord(message.interactive);
      const reply = asRecord(i.button_reply ?? i.list_reply);
      return typeof reply.title === 'string'
        ? reply.title
        : typeof reply.id === 'string'
        ? reply.id
        : undefined;
    }
    default:
      return undefined;
  }
}

function parseMessage(raw: unknown, phoneNumberId: string): InboundReply | undefined {
  const m = asRecord(raw);
  const text = replyText(m);
  if (typeof m.from !== 'string' || typeof m.id !== 'string' || text === undefined) {
    return undefined;
  }
  const context = asRecord(m.context);
  return {
    from: m.from.replace(/\D/g, ''),
    text,
    phoneNumberId,
    contextMessageId: typeof context.id === 'string' ? context.id : undefined,
    inboundMessageId: m.id,
    timestamp: toDate(m.timestamp),
  };
}

/** Parses a webhook body. Unknown shapes produce empty lists, never exceptions. */
export function parseWebhook(body: unknown): ParsedWebhook {
  const result: ParsedWebhook = { statuses: [], replies: [], ignoredFields: [] };
  const root = asRecord(body);
  if (root.object !== 'whatsapp_business_account') return result;
  for (const entry of asArray(root.entry)) {
    for (const change of asArray(asRecord(entry).changes)) {
      const c = asRecord(change);
      if (c.field !== 'messages') {
        if (typeof c.field === 'string') result.ignoredFields.push(c.field);
        continue;
      }
      const value = asRecord(c.value);
      const phoneNumberId = String(asRecord(value.metadata).phone_number_id ?? '');
      for (const s of asArray(value.statuses)) {
        const parsed = parseStatus(s);
        if (parsed) result.statuses.push(parsed);
      }
      for (const m of asArray(value.messages)) {
        const parsed = parseMessage(m, phoneNumberId);
        if (parsed) result.replies.push(parsed);
      }
    }
  }
  return result;
}

/** Whether a reply text is one of the confirmations the SQL side accepts (mirrors confirm_appointment_from_reply). */
export function isConfirmation(text: string): boolean {
  return ['1', 'yes', 'y', 'confirm', 'confirmed', 'ok', 'haan', 'ha'].includes(
    text.trim().toLowerCase(),
  );
}
