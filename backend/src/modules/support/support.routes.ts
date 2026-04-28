import rateLimit from 'express-rate-limit';
import { Router } from 'express';
import { ZodError } from 'zod';
import { sendSupportInquiryEmail } from '../../services/email.js';
import { supportContactSchema } from './support.schemas.js';

export const supportRouter = Router();

supportRouter.use(
  rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 12,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        error: { code: 'RATE_LIMIT', message: 'Too many support requests. Try again later.' },
      });
    },
  }),
);

function formatZodErrors(err: ZodError): string {
  return err.issues.map((i) => i.message).join('; ');
}

supportRouter.post('/contact', async (req, res) => {
  if (req.body && typeof req.body.website === 'string' && req.body.website.length > 0) {
    return res.status(204).end();
  }

  try {
    const body = supportContactSchema.parse(req.body);
    const { name, email, subject, message } = body;
    await sendSupportInquiryEmail({ name, email, subject, message });
    return res.status(200).json({ ok: true });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: formatZodErrors(err) },
      });
    }
    const msg = err instanceof Error ? err.message : 'Internal error';
    if (msg.includes('not set')) {
      return res.status(503).json({
        error: { code: 'NOT_CONFIGURED', message: 'Support email is not configured on the server.' },
      });
    }
    console.error('[support/contact]', err);
    return res.status(500).json({
      error: { code: 'INTERNAL', message: 'Could not send message. Try again later.' },
    });
  }
});
