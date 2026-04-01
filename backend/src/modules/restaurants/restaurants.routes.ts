import { Router } from 'express';
import { getRestaurantById, searchRestaurants } from './restaurants.service.js';

export const restaurantsRouter = Router();

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
