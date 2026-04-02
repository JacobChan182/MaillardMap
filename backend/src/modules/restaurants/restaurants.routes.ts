import { Router } from 'express';
import { ZodError, z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { createRestaurantShare, getRestaurantById, searchRestaurants } from './restaurants.service.js';

export const restaurantsRouter = Router();

const shareBodySchema = z
  .object({
    recipientId: z.string().uuid().optional(),
    recipient_id: z.string().uuid().optional(),
    restaurantId: z.string().uuid().optional(),
    restaurant_id: z.string().uuid().optional(),
  })
  .transform((b) => {
    const recipientId = b.recipientId ?? b.recipient_id;
    const restaurantId = b.restaurantId ?? b.restaurant_id;
    return { recipientId, restaurantId };
  })
  .pipe(
    z.object({
      recipientId: z.string().uuid(),
      restaurantId: z.string().uuid(),
    }),
  );

restaurantsRouter.post('/share', requireAuth, async (req, res) => {
  try {
    const body = shareBodySchema.parse(req.body);
    const result = await createRestaurantShare(req.userId!, body.recipientId, body.restaurantId);
    if (!result.ok) {
      return res
        .status(result.status)
        .json({ error: { code: result.code, message: result.message } });
    }
    return res.status(201).json({ ok: true });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

restaurantsRouter.get('/search', async (req, res) => {
  const q = req.query.q;
  if (typeof q !== 'string' || q.length === 0) {
    return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'q parameter is required' } });
  }
  const lat = req.query.lat ? parseFloat(req.query.lat as string) : undefined;
  const lng = req.query.lng ? parseFloat(req.query.lng as string) : undefined;
  const results = await searchRestaurants(q, lat, lng);
  return res.json(results);
});

restaurantsRouter.get('/:id', async (req, res) => {
  const restaurant = await getRestaurantById(req.params.id);
  if (!restaurant) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Restaurant not found' } });
  return res.json(restaurant);
});
