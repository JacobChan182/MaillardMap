import { describe, expect, it, beforeAll, beforeEach, vi } from 'vitest';
import http from 'node:http';
import type { AddressInfo } from 'node:net';

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

async function httpPostWithHeaders(
  app: any,
  path: string,
  body: Record<string, unknown>,
  headers: http.OutgoingHttpHeaders,
): Promise<{ status: number; body: any }> {
  const port = await getPort(app);
  return new Promise((resolve, reject) => {
    const server = app.listen(port, () => {
      const req = http.request(
        { hostname: '127.0.0.1', port, path, method: 'POST', headers: { 'Content-Type': 'application/json', ...headers } },
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

async function httpDeleteWithHeaders(
  app: any,
  path: string,
  headers: http.OutgoingHttpHeaders,
): Promise<{ status: number; body: any }> {
  const port = await getPort(app);
  return new Promise((resolve, reject) => {
    const server = app.listen(port, () => {
      const req = http.request(
        { hostname: '127.0.0.1', port, path, method: 'DELETE', headers },
        (res) => {
          let data = '';
          res.on('data', (chunk) => {
            data += chunk;
          });
          res.on('end', () => {
            server.close();
            let parsed: any = {};
            try {
              parsed = data ? JSON.parse(data) : {};
            } catch {
              parsed = { raw: data };
            }
            resolve({ status: res.statusCode!, body: parsed });
          });
        },
      );
      req.on('error', (err) => {
        server.close();
        reject(err);
      });
      req.end();
    });
  });
}

async function httpGetWithHeaders(
  app: any,
  path: string,
  headers: http.OutgoingHttpHeaders,
): Promise<{ status: number; body: any; headers: http.IncomingHttpHeaders }> {
  const port = await getPort(app);
  return new Promise((resolve, reject) => {
    const server = app.listen(port, () => {
      const req = http.request(
        { hostname: '127.0.0.1', port, path, method: 'GET', headers },
        (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk; });
          res.on('end', () => {
            server.close();
            let parsed: any = {};
            try {
              parsed = data ? JSON.parse(data) : {};
            } catch {
              parsed = { raw: data };
            }
            resolve({ status: res.statusCode!, body: parsed, headers: res.headers });
          });
        },
      );
      req.on('error', (err) => {
        server.close();
        reject(err);
      });
      req.end();
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

  async query(sql: string | { text: string } = '') {
    if (this.mockError) throw this.mockError;
    const text = typeof sql === 'string' ? sql : sql.text;
    const normalized = text.trim().replace(/\s+/g, ' ');
    const cmd = normalized.split(/\s+/)[0]?.toLowerCase();
    if (cmd === 'begin' || cmd === 'commit' || cmd === 'rollback') {
      return { rows: [] };
    }
    if (/^select\s+1\s+from\s+users\s+where\s+id/i.test(normalized)) {
      return { rows: [{ ok: 1 }] };
    }
    if (/^delete\s+from\s+users/i.test(normalized)) {
      return { rows: [], rowCount: 1 };
    }
    return this.mockResult || { rows: [] };
  }
}

const fakePool = new FakePool();

vi.mock('../src/db/pool.js', () => ({
  getPool: () => fakePool,
}));

vi.mock('../src/services/email.js', () => ({
  sendSignupConfirmationEmail: vi.fn().mockResolvedValue(undefined),
  sendSupportInquiryEmail: vi.fn().mockResolvedValue(undefined),
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
      expect(body.service).toBe('maillardmap-api');
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
      expect(body.service).toBe('maillardmap-api');
      expect(typeof body.time).toBe('string');
    });
  });

  // ---------------------------------------------------------------------------
  // POST /auth/signup
  // ---------------------------------------------------------------------------

  describe('POST /auth/signup', () => {
    it('returns 201 and the created user on success (needs email verification)', async () => {
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440010',
        username: 'alice',
        phone_or_email: 'alice@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: 'hashed',
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: null,
      };
      fakePool.setRows([row]);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        email: 'alice@example.com',
        password: 'password123',
      });

      expect(status).toBe(201);
      expect(body.ok).toBe(true);
      expect(body.needsVerification).toBe(true);
      expect(body.token).toBeUndefined();
      expect(body.user.id).toBe(row.id);
      expect(body.user.username).toBe('alice');
      expect(body.user.createdAt).toBe(row.created_at);
      expect(typeof body.message).toBe('string');
    });

    it('returns 409 when username is taken (unique violation)', async () => {
      const err = new Error('dup') as Error & { code: string; detail?: string };
      err.code = '23505';
      err.detail = 'Key (username)=(alice) already exists.';
      fakePool.setError(err);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        email: 'new@example.com',
        password: 'password123',
      });

      expect(status).toBe(409);
      expect(body.error.code).toBe('USERNAME_TAKEN');
    });

    it('returns 409 when email is already registered', async () => {
      const err = new Error('dup') as Error & { code: string; detail?: string };
      err.code = '23505';
      err.detail = 'Key (phone_or_email)=(taken@example.com) already exists.';
      fakePool.setError(err);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'newbie',
        email: 'taken@example.com',
        password: 'password123',
      });

      expect(status).toBe(409);
      expect(body.error.code).toBe('EMAIL_TAKEN');
    });

    it('returns 400 on Zod validation error (username too short)', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'ab',
        email: 'a@b.co',
        password: 'password123',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 on Zod validation error (password too short)', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        email: 'alice@example.com',
        password: 'short',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 when username is missing', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        email: 'alice@example.com',
        password: 'password123',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 when email is missing', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        password: 'password123',
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 when password is missing', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/signup', {
        username: 'alice',
        email: 'alice@example.com',
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
        phone_or_email: 'bob@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hash,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: '2026-01-01T00:00:01Z',
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

    it('returns 403 when email is not verified', async () => {
      const bcrypt = await import('bcryptjs');
      const hash = await bcrypt.hash('password123', 12);
      fakePool.setRows([{
        id: '550e8400-e29b-41d4-a716-446655440099',
        username: 'unverified',
        phone_or_email: 'u@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hash,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: null,
      }]);

      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/login', {
        username: 'unverified',
        password: 'password123',
      });

      expect(status).toBe(403);
      expect(body.error.code).toBe('EMAIL_NOT_VERIFIED');
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
        phone_or_email: null,
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hash,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: '2026-01-01T00:00:01Z',
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
  // POST /auth/request-password-reset + POST /auth/reset-password
  // ---------------------------------------------------------------------------

  describe('password reset routes', () => {
    it('returns 200 generic message for password reset request', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/request-password-reset', {
        username: 'alice@example.com',
      });
      expect(status).toBe(200);
      expect(body.ok).toBe(true);
      expect(typeof body.message).toBe('string');
    });

    it('returns 400 for invalid or expired reset token', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/auth/reset-password', {
        token: '1234567890abcdef',
        password: 'newpassword123',
      });
      expect(status).toBe(400);
      expect(body.error?.code).toBe('INVALID_OR_EXPIRED_TOKEN');
    });
  });

  // ---------------------------------------------------------------------------
  // DELETE /users/me
  // ---------------------------------------------------------------------------

  describe('DELETE /users/me', () => {
    it('returns 204 when Bearer token is valid', async () => {
      const jwt = await import('jsonwebtoken');
      const userId = '550e8400-e29b-41d4-a716-446655440011';
      const token = jwt.default.sign(
        { sub: userId, username: 'bob' },
        process.env.JWT_SECRET!,
        { expiresIn: '1h' },
      );
      const app = createApp();
      const { status } = await httpDeleteWithHeaders(app, '/users/me', {
        Authorization: `Bearer ${token}`,
      });
      expect(status).toBe(204);
    });

    it('returns 401 without Authorization', async () => {
      const app = createApp();
      const { status, body } = await httpDeleteWithHeaders(app, '/users/me', {});
      expect(status).toBe(401);
      expect(body.error?.code).toBe('UNAUTHORIZED');
    });
  });

  // ---------------------------------------------------------------------------
  // POST/DELETE /devices/apns
  // ---------------------------------------------------------------------------

  describe('APNs device routes', () => {
    it('registers an APNs device token for the authenticated user', async () => {
      const jwt = await import('jsonwebtoken');
      const userId = '550e8400-e29b-41d4-a716-446655440011';
      const token = jwt.default.sign(
        { sub: userId, username: 'bob' },
        process.env.JWT_SECRET!,
        { expiresIn: '1h' },
      );
      const app = createApp();
      const { status, body } = await httpPostWithHeaders(
        app,
        '/devices/apns',
        { token: 'a'.repeat(64), environment: 'sandbox' },
        { Authorization: `Bearer ${token}` },
      );
      expect(status).toBe(200);
      expect(body.ok).toBe(true);
    });

    it('unregisters an APNs device token for the authenticated user', async () => {
      const jwt = await import('jsonwebtoken');
      const userId = '550e8400-e29b-41d4-a716-446655440011';
      const token = jwt.default.sign(
        { sub: userId, username: 'bob' },
        process.env.JWT_SECRET!,
        { expiresIn: '1h' },
      );
      const app = createApp();
      const { status } = await httpDeleteWithHeaders(app, `/devices/apns/${'a'.repeat(64)}`, {
        Authorization: `Bearer ${token}`,
      });
      expect(status).toBe(204);
    });
  });

  // ---------------------------------------------------------------------------
  // GET /auth/verify-email
  // ---------------------------------------------------------------------------

  describe('GET /auth/verify-email', () => {
    it('verifies then redirects browser visits to the web app (success or error query)', async () => {
      const prev = process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL;
      process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL = 'https://maillardmap.web.app';
      try {
        fakePool.setRows([]);
        const app = createApp();
        const { status, headers } = await httpGetWithHeaders(app, '/auth/verify-email?token=hello', {
          Accept: 'text/html,application/xhtml+xml',
        });
        expect(status).toBe(302);
        expect(headers.location).toBe(
          'https://maillardmap.web.app/verify-email?error=INVALID_OR_EXPIRED_TOKEN',
        );
      } finally {
        if (prev === undefined) delete process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL;
        else process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL = prev;
      }
    });

    it('returns JSON for non-HTML clients when web URL is set (SPA fetch)', async () => {
      const prev = process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL;
      process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL = 'https://maillardmap.web.app';
      try {
        fakePool.setRows([]);
        const app = createApp();
        const { status, body } = await httpGetWithHeaders(app, '/auth/verify-email?token=hello', {
          Accept: '*/*',
        });
        expect(status).toBe(400);
        expect(body.error?.code).toBe('INVALID_OR_EXPIRED_TOKEN');
      } finally {
        if (prev === undefined) delete process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL;
        else process.env.PUBLIC_EMAIL_CONFIRM_WEB_URL = prev;
      }
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
  // POST /support/contact
  // ---------------------------------------------------------------------------

  describe('POST /support/contact', () => {
    it('returns 200 on valid payload', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/support/contact', {
        name: 'Test User',
        email: 'test@example.com',
        subject: 'Hello',
        message: 'Body text',
      });
      expect(status).toBe(200);
      expect(body.ok).toBe(true);
    });

    it('returns 400 when validation fails', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/support/contact', {
        name: '',
        email: 'not-an-email',
        subject: 'x',
        message: 'y',
      });
      expect(status).toBe(400);
      expect(body.error?.code).toBe('VALIDATION_ERROR');
    });

    it('returns 204 when honeypot website is set', async () => {
      const app = createApp();
      const { status, body } = await httpPost(app, '/support/contact', {
        name: 'Bot',
        email: 'bot@example.com',
        subject: 'spam',
        message: 'spam',
        website: 'http://evil.com',
      });
      expect(status).toBe(204);
      expect(Object.keys(body).length).toBe(0);
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