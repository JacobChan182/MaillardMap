import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { getNotifications } from './notifications.service.js';

export const notificationsRouter = Router();

notificationsRouter.get('/', requireAuth, async (req, res) => {
  try {
    const items = await getNotifications(req.userId);
    return res.json({ notifications: items });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
