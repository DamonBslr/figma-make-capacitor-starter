#!/usr/bin/env node
/**
 * Generates an Apple client secret JWT for Supabase Sign in with Apple.
 *
 * Usage:
 *   node scripts/generate-apple-jwt.js /path/to/AuthKey_KEYID.p8 YOUR_TEAM_ID
 *
 * Or set env vars and omit the args:
 *   APPLE_KEY_PATH=/path/to/AuthKey_KEYID.p8 APPLE_TEAM_ID=ABCDE12345 node scripts/generate-apple-jwt.js
 *
 * The Key ID is read from the filename (AuthKey_<KEYID>.p8).
 * The Services ID is read from APPLE_SERVICES_ID env var, defaulting to com.damonbasler.muse.siwa.
 *
 * Output: the JWT to paste into Supabase → Authentication → Providers → Apple → Secret Key.
 * The JWT is valid for 180 days. Regenerate before it expires.
 */

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const keyPath = process.argv[2] || process.env.APPLE_KEY_PATH;
const teamId = process.argv[3] || process.env.APPLE_TEAM_ID;
const servicesId = process.env.APPLE_SERVICES_ID || 'com.damonbasler.muse.siwa';

if (!keyPath || !teamId) {
  console.error('Usage: node scripts/generate-apple-jwt.js <path-to-AuthKey_KEYID.p8> <TEAM_ID>');
  console.error('');
  console.error('Or via env vars:');
  console.error(
    '  APPLE_KEY_PATH=/path/to/AuthKey_KEYID.p8 APPLE_TEAM_ID=ABCDE12345 node scripts/generate-apple-jwt.js',
  );
  process.exit(1);
}

if (!fs.existsSync(keyPath)) {
  console.error(`Error: key file not found at ${keyPath}`);
  process.exit(1);
}

// Extract Key ID from filename: AuthKey_5N72N6BZJ9.p8 → 5N72N6BZJ9
const filename = path.basename(keyPath, '.p8');
const keyId = filename.startsWith('AuthKey_') ? filename.slice('AuthKey_'.length) : filename;

if (!keyId) {
  console.error('Error: could not extract Key ID from filename. Expected format: AuthKey_KEYID.p8');
  process.exit(1);
}

const privateKey = fs.readFileSync(keyPath, 'utf8');

const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: keyId })).toString('base64url');

const now = Math.floor(Date.now() / 1000);
const exp = now + 180 * 24 * 60 * 60; // 180 days

const payload = Buffer.from(
  JSON.stringify({
    iss: teamId,
    iat: now,
    exp,
    aud: 'https://appleid.apple.com',
    sub: servicesId,
  }),
).toString('base64url');

const sign = crypto.createSign('SHA256');
sign.update(`${header}.${payload}`);
const signature = sign.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' }, 'base64url');

const jwt = `${header}.${payload}.${signature}`;

const expiresAt = new Date(exp * 1000).toLocaleDateString('en-US', {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
});

console.log('');
console.log('Apple client secret JWT');
console.log('─────────────────────────────────────────────');
console.log(jwt);
console.log('─────────────────────────────────────────────');
console.log(`Key ID:      ${keyId}`);
console.log(`Team ID:     ${teamId}`);
console.log(`Services ID: ${servicesId}`);
console.log(`Expires:     ${expiresAt} (180 days)`);
console.log('');
console.log('Paste the JWT above into:');
console.log('Supabase → Authentication → Providers → Apple → Secret Key');
console.log('');
console.log('Set a reminder to regenerate before the expiry date.');
