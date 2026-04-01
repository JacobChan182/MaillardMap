import { Router } from 'express';
import { ZodError } from 'zod';
import { loginSchema, signupSchema } from './auth.schemas.js';
import { login, signup } from './auth.service.js';

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
    return res.status(201).json(result);
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

