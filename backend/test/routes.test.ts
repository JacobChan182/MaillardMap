import { describe, expect, it, beforeAll, beforeEach, vi } from 'vitest';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import type { Pool } from 'pg';

// ---------------------------------------------------------------------------
// Minimal test HTTP helper (avoids adding supertest dependency)
// ---------------------------------------------------------------------------

function getPort(app: any): Promise<number> {
  return new Promise((resolve) => {
    const server = app.listen(0, () => {
      const addr = server.address() as AddressInfo;
      resolve(addr.port);
      server.close();
    });
  });
}

async function httpPost(app: any, path: string, body: Record<string, unknown>): Promise<{ status: number; body: any }> {
  const port = await getPort(app);
  return new Promise((resolve, reject) => {
    const server = app.listen(port, () => {
      const req = http.request(
        { hostname: '127.0.0.1', port, path, method: 'POST', headers: { 'Content-Type': 'application/json' } },
        (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk; });
          res.on('end', () => {
            server.close();
            resolve({ status: res.statusCode!, body: data ? JSON.parse(data) : {} });
          });
        },
      );
      req.on('error', (err) => { server.close(); reject(err); });
      req.write(JSON.stringify(body));
      req.end();
    });
  });
}

async function httpGet(app: any, path: string): Promise<{ status: number; body: any; headers: http.IncomingHttpHeaders }> {
  const port = await getPort(app);
  return new Promise((resolve, reject) => {
    const server = app.listen(port, () => {
      const req = http.get({ hostname: '127.0.0.1', port, path }, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          server.close();
          let parsed: any = {};
          try { parsed = data ? JSON.parse(data) : {}; } catch { parsed = { raw: data }; }
          resolve({ status: res.statusCode!, body: parsed, headers: res.headers });
        });
      });
      req.on('error', (err) => { server.close(); reject(err); });
    });
  });
}

// ---------------------------------------------------------------------------
// Pool mock
// ---------------------------------------------------------------------------

class FakePool {
  private mockResult: { rows: any[] } | null = null;
  private mockError: Error | null = null;

  setRows(rows: any[]) {
    this.mockResult = { rows };
    this.mockError = null;
  }

  setError(err: Error & { code?: string }) {
    this.mockError = err;
    this.mockResult = null;
  }

  async query(_sql: string, _params: unknown[]) {
    if (this.mockError) throw this.mockError;
    return this.mockResult || { rows: [] };
  }
}

const fakePool = new FakePool();

vi.mock('../src/db/pool.js', () => ({
  getPool: () => fakePool,
}));

import { createApp } from '../src/server/app.js';

describe('HTTP routes', () => {
  beforeAll(() => {
    process.env.JWT_SECRET = 'a'.repeat(32);
  });

  beforeEach(() => {
    fakePool.setRows([]);
    fakePool.setError(null as any);
  });

  // ---------------------------------------------------------------------------
  // GET /
  // ---------------------------------------------------------------------------

  describe('GET /', () => {
    it('returns 200 with service info', async () => {
      const app = createApp();
      const { status, body } = await httpGet(app, '/');
      expect(status).toBe(200);
      expect(body.ok).toBe(true);
      expect(body.service).toBe('bigback-api');
    });
  });

  // ---------------------------------------------------------------------------
  // GET /health
  // ---------------------------------------------------------------------------

  describe('GET /health', () => {
    it('returns 200 with health data including timestamp', async () => {
      const app = createApp();
      const { status, body } = await httpGet(app, '/health');
      expect(status).toBe(200);
      expect(body.ok).toBe(true);
      expect(body.service).toBe('bigback-api');
      expect(typeof body.time).toBe('string');
    });
  });

  // ---------------------------------------------------------------------------
  // POST /auth/signup
  // ---------------------------------------------------------------------------

  describe('POST /auth/signup', () => {
    it('returns 201 and the created user on success', async () => {
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440010',
        username: 'alice',
        password_hash: 'hashed',
        created_at: '2026-01-01T00:00:00Z',
      };
      fakePool.setRows([row]);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        password: 'password123',
      });

      expect(status).toBe(201);
      expect(body.ok).toBe(true);
      expect(body.user.id).toBe(row.id);
      expect(body.user.username).toBe('alice');
      expect(body.user.createdAt).toBe(row.created_at);
    });

    it('returns 409 when username is taken (unique violation)', async () => {
      const err = new Error('dup') as Error & { code: string };
      err.code = '23505';
      fakePool.setError(err);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        password: 'password123',
      });

      expect(status).toBe(409);
      expect(body.error.code).toBe('USERNAME_TAKEN');
    });

    it('returns 400 on Zod validation error (username too short)', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'ab',
        password: 'password123',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 on Zod validation error (password too short)', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        password: 'short',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 when username is missing', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        password: 'password123',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 when password is missing', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  // ---------------------------------------------------------------------------
  // POST /auth/login
  // ---------------------------------------------------------------------------

  describe('POST /auth/login', () => {
    it('returns 200 with a JWT token on valid credentials', async () => {
      const bcrypt = await import('bcryptjs');
      const hash = await bcrypt.hash('password123', 12);
      fakePool.setRows([{
        id: '550e8400-e29b-41d4-a716-446655440011',
        username: 'bob',
        password_hash: hash,
        created_at: '2026-01-01T00:00:00Z',
      }]);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/login', {
        username: 'bob',
        password: 'password123',
      });

      expect(status).toBe(200);
      expect(body.ok).toBe(true);
      expect(typeof body.token).toBe('string');
      expect(body.user.username).toBe('bob');
    });

    it('returns 401 for non-existent user', async () => {
      fakePool.setRows([]);
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/login', {
        username: 'ghost',
        password: 'password123',
      });

      expect(status).toBe(401);
      expect(body.error.code).toBe('INVALID_CREDENTIALS');
    });

    it('returns 401 for wrong password', async () => {
      const bcrypt = await import('bcryptjs');
      const hash = await bcrypt.hash('correctpassword', 12);
      fakePool.setRows([{
        id: '550e8400-e29b-41d4-a716-446655440012',
        username: 'bob',
        password_hash: hash,
        created_at: '2026-01-01T00:00:00Z',
      }]);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/login', {
        username: 'bob',
        password: 'wrongpassword',
      });

      expect(status).toBe(401);
      expect(body.error.code).toBe('INVALID_CREDENTIALS');
    });

    it('returns 400 on Zod validation error (missing password)', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/login', {
        username: 'bob',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  // ---------------------------------------------------------------------------
  // Security: helmet headers
  // ---------------------------------------------------------------------------

  describe('security headers', () => {
    it('includes helmet headers on responses', async () => {
      const app = createApp();
      const { headers } = await httpGet(app, '/health');
      expect(headers['x-frame-options']).toBe('SAMEORIGIN');
      expect(headers['x-dns-prefetch-control']).toBe('off');
    });

    it('does not leak x-powered-by header', async () => {
      const app = createApp();
      const { headers } = await httpGet(app, '/health');
      expect(headers['x-powered-by']).toBeUndefined();
    });
  });

  // ---------------------------------------------------------------------------
  // Malformed input: Express body parser
  // ---------------------------------------------------------------------------

  describe('malformed JSON body', () => {
    it('returns 400 for invalid JSON on signup', async () => {
      const app = createApp();
      const port = await getPort(app);

      const result = await new Promise<{ status: number; body: string }>((resolve, reject) => {
        const server = app.listen(port, () => {
          const req = http.request(
            { hostname: '127.0.0.1', port, path: '/auth/signup', method: 'POST', headers: { 'Content-Type': 'application/json' } },
            (res) => {
              let data = '';
              res.on('data', (chunk) => { data += chunk; });
              res.on('end', () => {
                server.close();
                resolve({ status: res.statusCode!, body: data });
              });
            },
          );
          req.on('error', (err) => { server.close(); reject(err); });
          req.write('{ "username": bad json }');
          req.end();
        });
      });

      expect(result.status).toBe(400);
    });
  });

  // ---------------------------------------------------------------------------
  // 404 for unrecognised routes
  // ---------------------------------------------------------------------------

  describe('unknown routes', () => {
    it('returns 404 for an unrecognised path', async () => {
      const app = createApp();
      const { status } = await httpGet(app, '/nonexistent');
      expect(status).toBe(404);
    });
  });
});