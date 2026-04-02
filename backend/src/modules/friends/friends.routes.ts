import { Router } from 'express';
import { ZodError } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { friendIdBodySchema, friendRequestSchema } from './friends.schemas.js';
import { acceptFriendRequest, getFriendsList, removeFriendship, sendFriendRequest } from './friends.service.js';

export const friendsRouter = Router();

friendsRouter.post('/request', requireAuth, async (req, res) => {
  try {
    const input = friendRequestSchema.parse(req.body);
    const userId = req.userId!;
    const result = await sendFriendRequest(userId, input);
    if (!result.ok) return res.status(result.status).json({ error: { code: result.code, message: 'Could not send request' } });
    return res.status(201).json({ ok: true });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

friendsRouter.post('/accept', requireAuth, async (req, res) => {
  try {
    let friendId: string;
    try {
      friendId = friendIdBodySchema.parse(req.body).friendId;
    } catch (e) {
      if (e instanceof ZodError) {
        return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
      }
      throw e;
    }
    const userId = req.userId!;
    const result = await acceptFriendRequest(userId, friendId);
    if (!result.ok) return res.status(result.status).json({ error: { code: result.code, message: 'Could not accept request' } });
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

friendsRouter.get('/list', requireAuth, async (req, res) => {
  try {
    const userId = req.userId!;
    const friends = await getFriendsList(userId);
    return res.json({ friends });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

friendsRouter.delete('/:friendId', requireAuth, async (req, res) => {
  try {
    const result = await removeFriendship(req.userId!, req.params.friendId);
    if (!result.ok) {
      return res.status(result.status).json({
        error: { code: result.code, message: 'Could not remove friendship' },
      });
    }
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
