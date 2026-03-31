import { Router } from 'express';
import { getHealth } from './health.service.js';

export const healthRouter = Router();

healthRouter.get('/', (_req, res) => {
  res.json(getHealth());
});

