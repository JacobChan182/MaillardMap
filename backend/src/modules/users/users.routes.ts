import { Router } from 'express';
import { ZodError } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { getUserById, searchUsers } from './users.service.js';

export const usersRouter = Router();

usersRouter.get('/:id', async (req, res) => {
  const user = await getUserById(req.params.id);
  if (!user) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'User not found' } });
  return res.json(user);
});

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
