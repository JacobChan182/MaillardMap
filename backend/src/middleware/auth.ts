/* eslint-disable no-unused-vars */
import type { NextFunction, Response, Request } from 'express';
import jwt from 'jsonwebtoken';
import { getPool } from '../db/pool.js';

type JwtPayload = { sub: string; username: string };

declare module 'express-serve-static-core' {
  interface Request {
    userId: string;
    username: string;
  }
}

/** Verifies JWT, then ensures `users.id` still exists (avoids 500s after DB reset / stale apps). */
export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } });
  }

  const token = header.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Server misconfiguration' } });
  }

  let decoded: JwtPayload;
  try {
    decoded = jwt.verify(token, secret) as JwtPayload;
  } catch {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } });
  }

  (req as any).userId = decoded.sub;
  (req as any).username = decoded.username;

  try {
    const pool = getPool();
    const exists = await pool.query('select 1 from users where id = $1 limit 1', [decoded.sub]);
    if (exists.rows.length === 0) {
      return res.status(401).json({
        error: {
          code: 'SESSION_STALE',
          message: 'This account was not found. Please sign in again.',
        },
      });
    }
  } catch (e) {
    next(e);
    return;
  }

  next();
}

/** Sets `userId` / `username` when a valid Bearer token is present; otherwise continues without auth. */
export function optionalAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next();
  }

  const token = header.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, secret) as JwtPayload;
    (req as any).userId = decoded.sub;
    (req as any).username = decoded.username;
  } catch {
    /* treat as anonymous */
  }
  next();
}
