import cors from 'cors';
import express from 'express';
import morgan from 'morgan';
import { healthRouter } from '../modules/health/health.routes.js';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use(morgan('dev'));

  app.get('/', (_req, res) => {
    res.json({ ok: true, service: 'bigback-api' });
  });

  app.use('/health', healthRouter);

  return app;
}

