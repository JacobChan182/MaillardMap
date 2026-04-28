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

function resetPasswordLink(token: string): string {
  const webBase = getPublicEmailConfirmWebBase();
  return `${webBase}/reset-password?token=${encodeURIComponent(token)}`;
}

function escapeHtmlAttr(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
}

function accountActionEmailBodies(input: {
  title: string;
  preview: string;
  intro: string;
  buttonText: string;
  href: string;
  note: string;
  fallbackIntro: string;
}): { text: string; html: string } {
  const text = [
    input.title,
    '',
    input.intro,
    '',
    `${input.buttonText}:`,
    input.href,
    '',
    input.note,
    '',
    'MaillardMap',
  ].join('\n');

  const safeTitle = escapeHtml(input.title);
  const safePreview = escapeHtml(input.preview);
  const safeIntro = escapeHtml(input.intro);
  const safeButtonText = escapeHtml(input.buttonText);
  const safeNote = escapeHtml(input.note);
  const safeFallbackIntro = escapeHtml(input.fallbackIntro);
  const safeHref = escapeHtmlAttr(input.href);
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${safeTitle}</title>
</head>
<body style="margin:0;padding:0;background:#fff7ed;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;color:#1f2937;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#fff7ed;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;border:1px solid #fed7aa;box-shadow:0 16px 40px rgba(154,52,18,0.12);overflow:hidden;">
          <tr>
            <td style="padding:28px 28px 18px;background:linear-gradient(135deg,#fb923c,#ea580c);color:#ffffff;">
              <p style="margin:0 0 8px;font-size:13px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;">MaillardMap</p>
              <h1 style="margin:0;font-size:28px;line-height:1.15;font-weight:800;">${safeTitle}</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:26px 28px 28px;">
              <p style="margin:0 0 18px;font-size:17px;line-height:1.55;color:#374151;">${safePreview}</p>
              <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#4b5563;">${safeIntro}</p>
              <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 0 24px;">
                <tr>
                  <td bgcolor="#ea580c" style="border-radius:999px;">
                    <a href="${safeHref}" style="display:inline-block;padding:13px 22px;border-radius:999px;color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;">${safeButtonText}</a>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 10px;font-size:13px;line-height:1.55;color:#6b7280;">${safeFallbackIntro}</p>
              <p style="margin:0 0 22px;font-size:13px;line-height:1.55;word-break:break-all;">
                <a href="${safeHref}" style="color:#c2410c;text-decoration:underline;">${safeHref}</a>
              </p>
              <div style="border-top:1px solid #ffedd5;padding-top:18px;">
                <p style="margin:0;font-size:13px;line-height:1.55;color:#78716c;">${safeNote}</p>
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { text, html };
}

function signupConfirmationBodies(href: string): { text: string; html: string } {
  return accountActionEmailBodies({
    title: 'Confirm your email',
    preview: 'Welcome to MaillardMap. Confirm your email to finish setting up your account.',
    intro: 'Once confirmed, you can log in and start sharing restaurant visits with friends.',
    buttonText: 'Confirm email',
    href,
    fallbackIntro: 'If the button does not open, copy and paste this link into your browser:',
    note: 'This link expires soon. If you did not create a MaillardMap account, you can ignore this email.',
  });
}

function resetPasswordBodies(href: string): { text: string; html: string } {
  return accountActionEmailBodies({
    title: 'Reset your password',
    preview: 'We received a request to reset your MaillardMap password.',
    intro: 'Choose a new password on the MaillardMap website. The link is single-use and expires in about one hour.',
    buttonText: 'Reset password',
    href,
    fallbackIntro: 'If the button does not open, copy and paste this link into your browser:',
    note: 'If you did not request this reset, you can safely ignore this email and your password will stay the same.',
  });
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
    headers: {
      'X-Entity-Ref-ID': `confirm-${plainToken.slice(0, 16)}`,
    },
    text,
    html,
  });
  if (error) {
    throw new Error(error.message);
  }
}

export async function sendPasswordResetEmail(toEmail: string, plainToken: string): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.warn('[email] RESEND_API_KEY not set; skipping password reset email (dev only)');
    return;
  }
  const from = resendFromHeader();
  const resend = new Resend(apiKey);
  const href = resetPasswordLink(plainToken);
  const { text, html } = resetPasswordBodies(href);
  const { error } = await resend.emails.send({
    from,
    to: [toEmail],
    subject: 'Reset your MaillardMap password',
    headers: {
      'X-Entity-Ref-ID': `reset-${plainToken.slice(0, 16)}`,
    },
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
