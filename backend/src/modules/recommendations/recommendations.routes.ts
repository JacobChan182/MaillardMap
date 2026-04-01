import { Router } from 'express';
import { z, ZodError } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { blendTastes } from './recommendations.service.js';

export const recommendationsRouter = Router();

const blendSchema = z.object({
  user_ids: z.array(z.string().min(1)).nonempty(),
});

recommendationsRouter.post('/blend', requireAuth, async (req, res) => {
  try {
    const { user_ids } = blendSchema.parse(req.body);
    const result = await blendTastes(user_ids);
    return res.json(result);
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
