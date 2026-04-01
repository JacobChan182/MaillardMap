import { describe, expect, it } from 'vitest';
import { signupSchema, loginSchema } from '../src/modules/auth/auth.schemas.js';

// ---------------------------------------------------------------------------
// signupSchema
// ---------------------------------------------------------------------------

describe('signupSchema', () => {
  it('accepts valid input', () => {
    const result = signupSchema.safeParse({ username: 'validuser', password: 'password123' });
    expect(result.success).toBe(true);
  });

  it('accepts minimum-allowed username length (3 chars)', () => {
    const result = signupSchema.safeParse({ username: 'abc', password: 'password123' });
    expect(result.success).toBe(true);
  });

  it('accepts maximum-allowed username length (32 chars)', () => {
    const result = signupSchema.safeParse({
      username: 'a'.repeat(32),
      password: 'password123',
    });
    expect(result.success).toBe(true);
  });

  it('rejects username shorter than 3 characters', () => {
    const result = signupSchema.safeParse({ username: 'ab', password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects username longer than 32 characters', () => {
    const result = signupSchema.safeParse({
      username: 'a'.repeat(33),
      password: 'password123',
    });
    expect(result.success).toBe(false);
  });

  it('rejects password shorter than 8 characters', () => {
    const result = signupSchema.safeParse({ username: 'validuser', password: 'short' });
    expect(result.success).toBe(false);
  });

  it('rejects password longer than 200 characters', () => {
    const result = signupSchema.safeParse({
      username: 'validuser',
      password: 'a'.repeat(201),
    });
    expect(result.success).toBe(false);
  });

  it('rejects missing username', () => {
    const result = signupSchema.safeParse({ password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects missing password', () => {
    const result = signupSchema.safeParse({ username: 'validuser' });
    expect(result.success).toBe(false);
  });

  it('rejects empty string username', () => {
    const result = signupSchema.safeParse({ username: '', password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects empty string password', () => {
    const result = signupSchema.safeParse({ username: 'validuser', password: '' });
    expect(result.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// loginSchema
// ---------------------------------------------------------------------------

describe('loginSchema', () => {

  it('accepts valid input', () => {
    const result = loginSchema.safeParse({ username: 'validuser', password: 'password123' });
    expect(result.success).toBe(true);
  });

  it('rejects username shorter than 3 characters', () => {
    const result = loginSchema.safeParse({ username: 'ab', password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects missing username', () => {
    const result = loginSchema.safeParse({ password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects missing password', () => {
    const result = loginSchema.safeParse({ username: 'validuser' });
    expect(result.success).toBe(false);
  });

  it('rejects password shorter than 8 characters', () => {
    const result = loginSchema.safeParse({ username: 'validuser', password: 'short' });
    expect(result.success).toBe(false);
  });

  it('rejects username longer than 32', () => {
    const result = loginSchema.safeParse({
      username: 'a'.repeat(33),
      password: 'password123',
    });
    expect(result.success).toBe(false);
  });
});