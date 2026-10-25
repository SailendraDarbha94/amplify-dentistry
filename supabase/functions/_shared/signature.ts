// signature.ts
// Meta signs every webhook POST with X-Hub-Signature-256: 'sha256=' + hex(HMAC-SHA256(app_secret, raw body)).
// Verify against the raw bytes, before JSON parsing, with a constant-time comparison.

const encoder = new TextEncoder();

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function toHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Hex HMAC-SHA256 of `body` under `secret`, without the `sha256=` prefix. */
export async function hmacSha256Hex(body: string | Uint8Array, secret: string): Promise<string> {
  const data = typeof body === 'string' ? encoder.encode(body) : body;
  const key = await hmacKey(secret);
  return toHex(await crypto.subtle.sign('HMAC', key, data as BufferSource));
}

/** Produces the header value Meta would send for `body` (used by tests and local tooling). */
export async function signBody(body: string | Uint8Array, secret: string): Promise<string> {
  return `sha256=${await hmacSha256Hex(body, secret)}`;
}

/** Constant-time string equality (same length required). */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * True when `header` (the X-Hub-Signature-256 value) matches `body` under `appSecret`.
 * A missing header, a header without the sha256= prefix or an empty secret never verifies.
 */
export async function verifySignature(
  body: string | Uint8Array,
  header: string | null | undefined,
  appSecret: string | undefined,
): Promise<boolean> {
  if (!header || !appSecret) return false;
  const [scheme, provided] = header.split('=', 2);
  if (scheme !== 'sha256' || !provided || !/^[0-9a-f]{64}$/i.test(provided)) return false;
  const expected = await hmacSha256Hex(body, appSecret);
  return timingSafeEqual(expected, provided.toLowerCase());
}
