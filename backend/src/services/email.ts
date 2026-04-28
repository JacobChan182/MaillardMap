import { Resend } from 'resend';

import { getPublicEmailConfirmWebBase } from '../config/publicWeb.js';

/**
 * Prefer the API verify URL so a single tap confirms in the browser before redirecting to the hosted SPA.
 * Falls back to opening the SPA with `token` when no public API base is configured (typical local dev).
 */
function confirmLink(token: string): string {
  const apiBase = (
    process.env.PUBLIC_API_BASE_URL ??
    process.env.API_PUBLIC_URL ??
    ''
  )
    .trim()
    .replace(/\/$/, '');
  if (apiBase) {
    return `${apiBase}/auth/verify-email?token=${encodeURIComponent(token)}`;
  }
  const webBase = getPublicEmailConfirmWebBase();
  return `${webBase}/verify-email?token=${encodeURIComponent(token)}`;
}

function escapeHtmlAttr(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
}

function signupConfirmationBodies(href: string): { text: string; html: string } {
  const text = [
    'Thanks for signing up for MaillardMap.',
    '',
    `Confirm your email by opening this link in your browser:`,
    href,
    '',
    'If you did not create an account, you can ignore this message.',
  ].join('\n');

  const safeHref = escapeHtmlAttr(href);
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Confirm your email</title>
</head>
<body style="margin:0;padding:24px;font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.5;color:#111827;background:#f9fafb;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;margin:0 auto;background:#ffffff;border-radius:12px;padding:24px;border:1px solid #e5e7eb;">
    <tr>
      <td>
        <p style="margin:0 0 16px;">Thanks for signing up.</p>
        <p style="margin:0 0 16px;">
          <a href="${safeHref}" style="color:#ea580c;font-weight:600;">Confirm your email</a>
        </p>
        <p style="margin:0;font-size:14px;color:#6b7280;">If you did not create an account, ignore this message.</p>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { text, html };
}

/** Resend `from`: inbox shows `RESEND_FROM_NAME` (default MaillardMap) with your verified sender email. */
function resendFromHeader(): string {
  const raw = process.env.RESEND_FROM?.trim();
  if (!raw) {
    throw new Error(
      'RESEND_FROM is required when RESEND_API_KEY is set (email or "Name <email>", e.g. onboarding@yourdomain.com)',
    );
  }
  const displayName = (process.env.RESEND_FROM_NAME ?? 'MaillardMap').trim() || 'MaillardMap';
  const angle = raw.match(/^(.+?)\s*<\s*([^>]+)\s*>$/);
  const email = (angle ? angle[2] : raw).trim();
  if (!email.includes('@')) {
    throw new Error('RESEND_FROM must be a valid email or "Name <email>"');
  }
  return `${displayName} <${email}>`;
}

export async function sendSignupConfirmationEmail(toEmail: string, plainToken: string): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.warn('[email] RESEND_API_KEY not set; skipping confirmation email (dev only)');
    return;
  }
  const from = resendFromHeader();
  const resend = new Resend(apiKey);
  const href = confirmLink(plainToken);
  const { text, html } = signupConfirmationBodies(href);
  const { error } = await resend.emails.send({
    from,
    to: [toEmail],
    subject: 'Confirm your MaillardMap account',
    text,
    html,
  });
  if (error) {
    throw new Error(error.message);
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Public support form (e.g. Firebase-hosted marketing site). Requires RESEND_* and SUPPORT_INBOX_EMAIL. */
export async function sendSupportInquiryEmail(input: {
  name: string;
  email: string;
  subject: string;
  message: string;
}): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    throw new Error('RESEND_API_KEY not set');
  }
  const to = process.env.SUPPORT_INBOX_EMAIL?.trim();
  if (!to) {
    throw new Error('SUPPORT_INBOX_EMAIL not set');
  }
  const from = resendFromHeader();
  const resend = new Resend(apiKey);
  const { error } = await resend.emails.send({
    from,
    to: [to],
    replyTo: input.email,
    subject: `[MaillardMap] ${input.subject}`,
    html: `
      <p><strong>From:</strong> ${escapeHtml(input.name)} &lt;${escapeHtml(input.email)}&gt;</p>
      <p><strong>Subject:</strong> ${escapeHtml(input.subject)}</p>
      <hr />
      <pre style="white-space:pre-wrap;font-family:system-ui,sans-serif">${escapeHtml(input.message)}</pre>
    `,
  });
  if (error) {
    throw new Error(error.message);
  }
}
