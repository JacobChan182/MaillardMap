import { Router } from 'express';
import { ZodError } from 'zod';
import { getPublicEmailConfirmWebBase } from '../../config/publicWeb.js';
import { loginSchema, resendConfirmationSchema, signupSchema } from './auth.schemas.js';
import { login, resendConfirmationEmail, signup, verifyEmail } from './auth.service.js';

export const authRouter = Router();

function formatZodErrors(err: ZodError): string {
  return err.issues.map((i) => {
    const field = i.path.join('.');
    if (i.code === 'too_small' && 'minimum' in i) return `${field} must be at least ${i.minimum} characters`;
    if (i.code === 'too_big' && 'maximum' in i) return `${field} must be at most ${i.maximum} characters`;
    return `${field}: ${i.message}`;
  }).join('; ');
}

authRouter.post('/signup', async (req, res) => {
  try {
    const input = signupSchema.parse(req.body);
    const result = await signup(input);
    if (!result.ok) {
      return res.status(result.status).json({ error: { code: result.code, message: result.message } });
    }
    return res.status(201).json({
      ok: true,
      needsVerification: true,
      user: result.user,
      message: result.message,
    });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: formatZodErrors(err) } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

authRouter.post('/login', async (req, res) => {
  try {
    const input = loginSchema.parse(req.body);
    const result = await login(input);
    if (!result.ok) {
      return res.status(result.status).json({ error: { code: result.code, message: result.message } });
    }
    return res.status(200).json(result);
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: formatZodErrors(err) } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

authRouter.post('/resend-confirmation', async (req, res) => {
  try {
    const resendInput = resendConfirmationSchema.parse(req.body);
    const result = await resendConfirmationEmail(resendInput);
    if (!result.ok) {
      return res.status(result.status).json({ error: { code: result.code, message: result.message } });
    }
    return res.status(200).json({ ok: true, message: result.message });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: formatZodErrors(err) } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

authRouter.get('/verify-email', async (req, res) => {
  try {
    const token = typeof req.query.token === 'string' ? req.query.token : '';
    const webBase = getPublicEmailConfirmWebBase();
    const accept = req.get('Accept') ?? '';
    // Browsers opening the API link send text/html. Confirm email *before* redirecting to the SPA so the
    // one-time token is not wasted on a redirect page that may fail to fetch the API (CORS/offline).
    // fetch() from the SPA uses */* — JSON response path below.
    if (token && accept.includes('text/html')) {
      const result = await verifyEmail(token);
      const dest = new URL('/verify-email', `${webBase}/`);
      if (result.ok) {
        dest.searchParams.set('confirmed', '1');
      } else {
        dest.searchParams.set('error', result.code);
      }
      return res.redirect(302, dest.toString());
    }
    const result = await verifyEmail(token);
    if (!result.ok) {
      return res.status(result.status).json({ error: { code: result.code, message: result.message } });
    }
    return res.status(200).json({ ok: true, token: result.token, user: result.user });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
