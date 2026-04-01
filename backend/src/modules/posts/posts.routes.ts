import { Router } from 'express';
import { ZodError } from 'zod';
import { optionalAuth, requireAuth } from '../../middleware/auth.js';
import { createPostSchema } from './posts.schemas.js';
import { createPost, getFeed, getPostsByUser, toggleLike } from './posts.service.js';
import { getRestaurantByFoursquareId } from '../restaurants/restaurants.service.js';

export const postsRouter = Router();

postsRouter.post('/', requireAuth, async (req, res) => {
  try {
    const input = createPostSchema.parse(req.body);

    // Look up restaurant from DB (must exist from prior Foursquare search)
    const restaurant = await getRestaurantByFoursquareId(input.foursquareId);
    if (!restaurant) {
      return res.status(404).json({
        error: { code: 'RESTAURANT_NOT_FOUND', message: 'Restaurant not found. Search for it first.' },
      });
    }

    const postId = await createPost((req as any).userId, {
      ...input,
      name: restaurant.name,
      lat: restaurant.lat,
      lng: restaurant.lng,
      cuisine: restaurant.cuisine ?? undefined,
    });
    return res.status(201).json({ ok: true, post: { id: postId } });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

postsRouter.get('/feed', requireAuth, async (req, res) => {
  try {
    const posts = await getFeed((req as any).userId);
    return res.json({ posts });
  } catch {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

postsRouter.get('/user/:id', optionalAuth, async (req, res) => {
  try {
    const likerId = (req as any).userId as string | undefined;
    const posts = await getPostsByUser(req.params.id, likerId ?? '');
    return res.json({ posts });
  } catch {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

postsRouter.post('/:id/like', requireAuth, async (req, res) => {
  try {
    const liked = await toggleLike((req as any).userId, req.params.id);
    return res.json({ ok: true, liked });
  } catch {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
