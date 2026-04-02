import { Router } from 'express';
import { ZodError } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { getUserById, searchUsers, updateMyProfile } from './users.service.js';
import { patchMeSchema } from './users.schemas.js';

export const usersRouter = Router();

usersRouter.get('/search', async (req, res) => {
  try {
    const q = req.query.q;
    if (typeof q !== 'string' || q.length === 0) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'q parameter is required' } });
    }
    const results = await searchUsers(q);
    return res.json(results);
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

usersRouter.patch('/me', requireAuth, async (req, res) => {
  try {
    const input = patchMeSchema.parse(req.body);
    if (input.displayName === undefined && input.avatarUrl === undefined && input.bio === undefined) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: 'Provide displayName, avatarUrl, and/or bio' },
      });
    }
    let displayName: string | null | undefined = input.displayName;
    if (displayName !== undefined && displayName !== null) {
      const t = displayName.trim();
      displayName = t.length === 0 ? null : t;
    }
    let bio: string | null | undefined = input.bio;
    if (bio !== undefined && bio !== null) {
      const t = bio.trim();
      bio = t.length === 0 ? null : t;
    }
    const userId = (req as { userId: string }).userId;
    const result = await updateMyProfile(userId, {
      displayName,
      avatarUrl: input.avatarUrl,
      bio,
    });
    if (!result.ok) {
      return res.status(result.status).json({ error: { code: result.code, message: result.message } });
    }
    return res.json({ user: result.user });
  } catch (err) {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid request' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});

usersRouter.get('/:id', async (req, res) => {
  const user = await getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'User not found' } });
  return res.json(user);
});
