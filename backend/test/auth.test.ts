import { describe, expect, it, beforeEach, vi, beforeAll } from 'vitest';
import bcrypt from 'bcryptjs';
import type { Pool } from 'pg';

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

  async query(_sql: string, _params: unknown[]) {
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
    it('creates a user and returns user object with ok=true', async () => {
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        username: 'alice',
        password_hash: '$2a$12$dummy',
        created_at: '2026-01-01T00:00:00Z',
      };
      fakePool.setRows([row]);

      const result = await signup({ username: 'alice', password: 'password123' });

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

      const result = await signup({ username: 'alice', password: 'password123' });

      expect(result.ok).toBe(false);
      if (result.ok === false) {
        expect(result.status).toBe(409);
        expect(result.code).toBe('USERNAME_TAKEN');
      }
    });

    it('rethrows non-duplicate database errors', async () => {
      const err = new Error('connection refused');
      fakePool.setError(err);

      await expect(signup({ username: 'alice', password: 'password123' })).rejects.toThrow('connection refused');
    });
  });

  describe('login', () => {
    it('returns token and user on valid credentials', async () => {
      const hashed = await bcrypt.hash('password123', 12);
      const row = {
        id: '550e8400-e29b-41d4-a716-446655440001',
        username: 'bob',
        password_hash: hashed,
        created_at: '2026-01-01T00:00:00Z',
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
        password_hash: hashed,
        created_at: '2026-01-01T00:00:00Z',
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