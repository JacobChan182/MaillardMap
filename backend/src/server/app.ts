import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import morgan from 'morgan';
import { authRouter } from '../modules/auth/auth.routes.js';
import { healthRouter } from '../modules/health/health.routes.js';

export function createApp() {
  const app = express();

  app.disable('x-powered-by');

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
    res.json({ ok: true, service: 'bigback-api' });
  });

  app.use('/auth', authRouter);
  app.use('/health', healthRouter);

  return app;
}

