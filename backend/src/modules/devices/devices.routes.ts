import { Router } from 'express';
import { ZodError } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { registerApnsTokenSchema } from './devices.schemas.js';
import { registerApnsToken, unregisterApnsToken } from './devices.service.js';

export const devicesRouter = Router();

devicesRouter.post('/apns', requireAuth, async (req, res) => {
  try {
    const input = registerApnsTokenSchema.parse(req.body);
    await registerApnsToken(req.userId, input);
    return res.status(200).json({ ok: true });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid APNs token payload' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

devicesRouter.delete('/apns/:token', requireAuth, async (req, res) => {
  try {
    await unregisterApnsToken(req.userId, decodeURIComponent(req.params.token));
    return res.status(204).send();
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
