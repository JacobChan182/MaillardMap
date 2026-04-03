import { Resend } from 'resend';

function confirmLink(token: string): string {
  const base = (process.env.PUBLIC_API_BASE_URL ?? process.env.API_PUBLIC_URL ?? 'http://localhost:3000').replace(/\/$/, '');
  return `${base}/auth/verify-email?token=${encodeURIComponent(token)}`;
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
  const { error } = await resend.emails.send({
    from,
    to: toEmail,
    subject: 'Confirm your MaillardMap account',
    html: `
      <p>Thanks for signing up.</p>
      <p><a href="${href}">Confirm your email</a></p>
      <p>If you did not create an account, ignore this message.</p>
    `,
  });
  if (error) {
    throw new Error(error.message);
  }
}
