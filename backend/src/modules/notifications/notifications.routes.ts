import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { dismissNotification, getNotifications } from './notifications.service.js';

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

notificationsRouter.delete('/:id', requireAuth, async (req, res) => {
  try {
    const notificationId = decodeURIComponent(req.params.id);
    if (!notificationId) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Notification id is required' } });
    }
    await dismissNotification(req.userId, notificationId);
    return res.status(204).send();
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal error' } });
  }
});
