import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import morgan from 'morgan';
import { authRouter } from '../modules/auth/auth.routes.js';
import { devicesRouter } from '../modules/devices/devices.routes.js';
import { friendsRouter } from '../modules/friends/friends.routes.js';
import { healthRouter } from '../modules/health/health.routes.js';
import { notificationsRouter } from '../modules/notifications/notifications.routes.js';
import { postsRouter } from '../modules/posts/posts.routes.js';
import { recommendationsRouter } from '../modules/recommendations/recommendations.routes.js';
import { restaurantsRouter } from '../modules/restaurants/restaurants.routes.js';
import { savedRouter } from '../modules/saved/saved.routes.js';
import { supportRouter } from '../modules/support/support.routes.js';
import { uploadsRouter } from '../modules/uploads/uploads.routes.js';
import { usersRouter } from '../modules/users/users.routes.js';

function trustProxySetting(): number | boolean {
  const tp = process.env.TRUST_PROXY;
  if (tp === '0' || tp === 'false') return false;
  if (tp != null && tp !== '') {
    const n = Number(tp);
    if (Number.isFinite(n) && n >= 0) return n === 0 ? false : n;
    return 1;
  }
  // Docker/production images set NODE_ENV=production; hosts behind nginx, Railway, etc. send X-Forwarded-For.
  if (process.env.NODE_ENV === 'production') return 1;
  return false;
}

export function createApp() {
  const app = express();

  app.disable('x-powered-by');
  // Avoid 304 + empty body on JSON APIs (Express etag breaks clients that expect a body every time).
  app.set('etag', false);
  app.set('trust proxy', trustProxySetting());

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  app.use(
    rateLimit({
      windowMs: 60_000,
      limit: 300,
      standardHeaders: 'draft-7',
      legacyHeaders: false,
    }),
  );

  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use(morgan('dev'));

  app.get('/', (_req, res) => {
    res.json({ ok: true, service: 'maillardmap-api' });
  });

  app.use('/auth', authRouter);
  app.use('/devices', devicesRouter);
  app.use('/friends', friendsRouter);
  app.use('/health', healthRouter);
  app.use('/notifications', notificationsRouter);
  app.use('/posts', postsRouter);
  app.use('/recommendations', recommendationsRouter);
  app.use('/restaurants', restaurantsRouter);
  app.use('/saved', savedRouter);
  app.use('/support', supportRouter);
  app.use('/uploads', uploadsRouter);
  app.use('/users', usersRouter);

  return app;
}
