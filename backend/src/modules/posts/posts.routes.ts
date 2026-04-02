import { Router } from 'express';
import { ZodError } from 'zod';
import { optionalAuth, requireAuth } from '../../middleware/auth.js';
import { createPostSchema } from './posts.schemas.js';
import {
  addComment,
  createPost,
  getCommentsByPost,
  getFeed,
  getFeedPostsByRestaurant,
  getPostsByUser,
  toggleLike,
} from './posts.service.js';
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
      address: restaurant.address ?? undefined,
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

postsRouter.get('/restaurant/:restaurantId', requireAuth, async (req, res) => {
  try {
    const posts = await getFeedPostsByRestaurant((req as any).userId, req.params.restaurantId);
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

postsRouter.get('/:id/comments', requireAuth, async (req, res) => {
  try {
    const comments = await getCommentsByPost(req.params.id);
    return res.json({ comments });
  } catch {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

postsRouter.post('/:id/comments', requireAuth, async (req, res) => {
  try {
    const raw = req.body as { text?: string; parentCommentId?: string; parent_comment_id?: string };
    const text = raw.text?.trim();
    if (!text) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'text is required' } });
    }
    const parentCommentId = raw.parentCommentId ?? raw.parent_comment_id ?? null;
    const comment = await addComment((req as any).userId, req.params.id, text, parentCommentId);
    return res.status(201).json({ comment });
  } catch (err) {
    const anyErr = err as { statusCode?: number; message?: string; code?: string };
    if (anyErr.statusCode === 400) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: anyErr.message ?? 'Invalid reply target' },
      });
    }
    const zErr = err as { code?: string; message?: string };
    if (zErr.code === '23503') {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Post not found' } });
    }
    if (zErr.code === '23514') {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Comment text is invalid' } });
    }
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
