import { Router } from 'express';
import { ZodError } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { savedCreateSchema } from './saved.schemas.js';
import { savePlace, getSavedPlaces, removeSavedPlace } from './saved.service.js';

export const savedRouter = Router();

savedRouter.post('/', requireAuth, async (req, res) => {
  try {
    const { restaurant_id } = savedCreateSchema.parse(req.body);
    const result = await savePlace((req as any).userId, restaurant_id);
    if (!result.ok) return res.status(result.status).json({ error: { code: result.code, message: 'Restaurant not found' } });
    return res.status(201).json(result);
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

savedRouter.get('/', requireAuth, async (req, res) => {
  try {
    const result = await getSavedPlaces((req as any).userId);
    return res.json(result);
  } catch {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

savedRouter.delete('/:restaurant_id', requireAuth, async (req, res) => {
  try {
    await removeSavedPlace((req as any).userId, req.params.restaurant_id);
    return res.json({ ok: true });
  } catch {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
