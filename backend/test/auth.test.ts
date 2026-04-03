import { describe, expect, it, beforeEach, vi } from 'vitest';
import bcrypt from 'bcryptjs';

vi.mock('../src/services/email.js', () => ({
  sendSignupConfirmationEmail: vi.fn().mockResolvedValue(undefined),
}));

// ---------------------------------------------------------------------------
// Mock the DB pool so we can unit-test auth services in isolation
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

  async query(sql: string | unknown, params?: unknown[]) {
    if (typeof sql === 'string') {
      const t = sql.trim().toLowerCase();
      if (t === 'begin' || t === 'commit' || t === 'rollback') {
        return { rows: [] };
      }
      if (sql.includes('phone_or_email = $2') && params && params.length >= 2) {
        if (this.mockError) throw this.mockError;
        const raw = String(params[0]);
        const emailKey = String(params[1]);
        const rows = this.mockResult?.rows ?? [];
        const user = rows[0];
        if (!user) return { rows: [] };
        const match =
          user.username === raw ||
          (user.phone_or_email != null && user.phone_or_email === emailKey);
        return { rows: match ? [user] : [] };
      }
    }
    if (this.mockError) throw this.mockError;
    return this.mockResult || { rows: [] };
  }
}

const fakePool = new FakePool();

vi.mock('../src/db/pool.js', () => ({
  getPool: () => fakePool,
}));

// Import after mock is registered
import { signup, login } from '../src/modules/auth/auth.service.js';

describe('auth service', () => {
  beforeEach(() => {
    process.env.JWT_SECRET = 'a'.repeat(32);
    fakePool.setRows([]);
    fakePool.setError(null as any);
  });

  describe('signup', () => {
    it('creates a user and returns needsVerification with user object', async () => {
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        username: 'alice',
        password_hash: '$2a$12$dummy',
        phone_or_email: 'alice@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: null,
      };
      fakePool.setRows([row]);

      const result = await signup({
        username: 'alice',
        email: 'alice@example.com',
        password: 'password123',
      });

      expect(result.ok).toBe(true);
      if (result.ok === true) {
        expect(result.user.id).toBe(row.id);
        expect(result.user.username).toBe('alice');
        expect(result.user.createdAt).toBe(row.created_at);
      }
    });

    it('returns USERNAME_TAKEN on duplicate constraint violation', async () => {
      const err = new Error('duplicate') as Error & { code: string };
      err.code = '23505';
      fakePool.setError(err);

      const result = await signup({
        username: 'alice',
        email: 'alice@example.com',
        password: 'password123',
      });

      expect(result.ok).toBe(false);
      if (result.ok === false) {
        expect(result.status).toBe(409);
        expect(result.code).toBe('USERNAME_TAKEN');
      }
    });

    it('rethrows non-duplicate database errors', async () => {
      const err = new Error('connection refused');
      fakePool.setError(err);

      await expect(
        signup({ username: 'alice', email: 'a@b.com', password: 'password123' }),
      ).rejects.toThrow('connection refused');
    });
  });

  describe('login', () => {
    it('returns token and user on valid credentials', async () => {
      const hashed = await bcrypt.hash('password123', 12);
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440001',
        username: 'bob',
        phone_or_email: 'bob@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hashed,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: '2026-01-01T00:00:00Z',
      };
      fakePool.setRows([row]);

      const result = await login({ username: 'bob', password: 'password123' });

      expect(result.ok).toBe(true);
      if (result.ok === true) {
        expect(result.token).toBeDefined();
        expect(typeof result.token).toBe('string');
        expect(result.user.id).toBe(row.id);
        expect(result.user.username).toBe('bob');
      }
    });

    it('matches email case-insensitively (stored lowercase)', async () => {
      const hashed = await bcrypt.hash('password123', 12);
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440003',
        username: 'bob',
        phone_or_email: 'bob@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hashed,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: '2026-01-01T00:00:00Z',
      };
      fakePool.setRows([row]);

      const result = await login({ username: 'Bob@EXAMPLE.COM', password: 'password123' });

      expect(result.ok).toBe(true);
      if (result.ok === true) {
        expect(result.user.username).toBe('bob');
      }
    });

    it('returns EMAIL_NOT_VERIFIED when email not confirmed', async () => {
      const hashed = await bcrypt.hash('password123', 12);
      fakePool.setRows([{
        id: '550e8400-e29b-41d4-a716-446655440001',
        username: 'bob',
        phone_or_email: 'bob@example.com',
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hashed,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: null,
      }]);

      const result = await login({ username: 'bob', password: 'password123' });

      expect(result.ok).toBe(false);
      if (result.ok === false) {
        expect(result.status).toBe(403);
        expect(result.code).toBe('EMAIL_NOT_VERIFIED');
      }
    });

    it('returns INVALID_CREDENTIALS when user not found', async () => {
      fakePool.setRows([]);

      const result = await login({ username: 'nobody', password: 'password123' });

      expect(result.ok).toBe(false);
      if (result.ok === false) {
        expect(result.status).toBe(401);
        expect(result.code).toBe('INVALID_CREDENTIALS');
      }
    });

    it('returns INVALID_CREDENTIALS when password is wrong', async () => {
      const hashed = await bcrypt.hash('correct', 12);
      fakePool.setRows([{
        id: '550e8400-e29b-41d4-a716-446655440002',
        username: 'bob',
        phone_or_email: null,
        display_name: null,
        avatar_url: null,
        bio: null,
        password_hash: hashed,
        created_at: '2026-01-01T00:00:00Z',
        profile_private: false,
        email_verified_at: '2026-01-01T00:00:00Z',
      }]);

      const result = await login({ username: 'bob', password: 'wrong' });

      expect(result.ok).toBe(false);
      if (result.ok === false) {
        expect(result.status).toBe(401);
        expect(result.code).toBe('INVALID_CREDENTIALS');
      }
    });
  });
});
