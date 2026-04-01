/* eslint-disable no-unused-vars */
import type { NextFunction, Response, Request } from 'express';
import jwt from 'jsonwebtoken';

type JwtPayload = { sub: string; username: string };

declare module 'express-serve-static-core' {
  interface Request {
    userId: string;
    username: string;
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } });
  }

  const token = header.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Server misconfiguration' } });
  }

  try {
    const decoded = jwt.verify(token, secret) as JwtPayload;
    (req as any).userId = decoded.sub;
    (req as any).username = decoded.username;
    next();
  } catch {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } });
  }
}
