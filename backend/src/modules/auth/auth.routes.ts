import { Router } from 'express';
import { ZodError } from 'zod';
import { loginSchema, signupSchema } from './auth.schemas.js';
import { login, signup } from './auth.service.js';

export const authRouter = Router();

authRouter.post('/signup', async (req, res) => {
  try {
    const input = signupSchema.parse(req.body);
    const result = await signup(input);
    if (!result.ok) {
      return res.status(result.status).json({ error: { code: result.code, message: 'Username already taken' } });
    }
    return res.status(201).json(result);
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
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
      return res.status(result.status).json({ error: { code: result.code, message: 'Invalid credentials' } });
    }
    return res.status(200).json(result);
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

