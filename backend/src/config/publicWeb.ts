/**
 * Hosted marketing / account site (Firebase) where `/verify-email` lives.
 * Override with `PUBLIC_EMAIL_CONFIRM_WEB_URL` (no trailing slash) for self-hosting.
 */
const DEFAULT_PUBLIC_EMAIL_CONFIRM_WEB_URL = 'https://maillardmap.web.app';

export function getPublicEmailConfirmWebBase(): string {
  const raw = process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL?.trim();
  if (raw) return raw.replace(/\/$/, '');
  return DEFAULT_PUBLIC_EMAIL_CONFIRM_WEB_URL;
}
