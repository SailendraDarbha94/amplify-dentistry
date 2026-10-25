import { assert, assertEquals, assertFalse } from '@std/assert';
import { hmacSha256Hex, signBody, timingSafeEqual, verifySignature } from './signature.ts';

const secret = 'app-secret-for-tests';
const body = JSON.stringify({ object: 'whatsapp_business_account', entry: [] });

Deno.test('hmacSha256Hex matches a known vector', async () => {
  // HMAC-SHA256("key", "The quick brown fox jumps over the lazy dog")
  assertEquals(
    await hmacSha256Hex('The quick brown fox jumps over the lazy dog', 'key'),
    'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8',
  );
});

Deno.test('a body signed with the app secret verifies', async () => {
  const header = await signBody(body, secret);
  assert(header.startsWith('sha256='));
  assert(await verifySignature(body, header, secret));
  assert(await verifySignature(new TextEncoder().encode(body), header, secret));
  assert(await verifySignature(body, header.toUpperCase().replace('SHA256', 'sha256'), secret));
});

Deno.test('tampered body, wrong secret, missing header or secret never verify', async () => {
  const header = await signBody(body, secret);
  assertFalse(await verifySignature(body + ' ', header, secret));
  assertFalse(await verifySignature(body, header, 'another-secret'));
  assertFalse(await verifySignature(body, null, secret));
  assertFalse(await verifySignature(body, header, undefined));
  assertFalse(await verifySignature(body, header, ''));
  assertFalse(await verifySignature(body, 'sha1=' + header.slice(7), secret));
  assertFalse(await verifySignature(body, 'sha256=nothex', secret));
});

Deno.test('timingSafeEqual compares whole strings', () => {
  assert(timingSafeEqual('abc', 'abc'));
  assertFalse(timingSafeEqual('abc', 'abd'));
  assertFalse(timingSafeEqual('abc', 'ab'));
});
