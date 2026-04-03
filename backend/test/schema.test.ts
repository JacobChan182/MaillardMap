import { describe, expect, it } from 'vitest';
import { signupSchema, loginSchema } from '../src/modules/auth/auth.schemas.js';

// ---------------------------------------------------------------------------
// signupSchema
// ---------------------------------------------------------------------------

const validSignup = {
  username: 'validuser',
  email: 'valid@example.com',
  password: 'password123',
};

describe('signupSchema', () => {
  it('accepts valid input', () => {
    const result = signupSchema.safeParse(validSignup);
    expect(result.success).toBe(true);
  });

  it('accepts minimum-allowed username length (3 chars)', () => {
    const result = signupSchema.safeParse({ ...validSignup, username: 'abc' });
    expect(result.success).toBe(true);
  });

  it('accepts maximum-allowed username length (32 chars)', () => {
    const result = signupSchema.safeParse({
      ...validSignup,
      username: 'a'.repeat(32),
    });
    expect(result.success).toBe(true);
  });

  it('rejects username shorter than 3 characters', () => {
    const result = signupSchema.safeParse({ ...validSignup, username: 'ab' });
    expect(result.success).toBe(false);
  });

  it('rejects username longer than 32 characters', () => {
    const result = signupSchema.safeParse({
      ...validSignup,
      username: 'a'.repeat(33),
    });
    expect(result.success).toBe(false);
  });

  it('rejects invalid email', () => {
    const result = signupSchema.safeParse({ ...validSignup, email: 'not-an-email' });
    expect(result.success).toBe(false);
  });

  it('rejects missing email', () => {
    const result = signupSchema.safeParse({ username: 'validuser', password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects password shorter than 8 characters', () => {
    const result = signupSchema.safeParse({ ...validSignup, password: 'short' });
    expect(result.success).toBe(false);
  });

  it('rejects password longer than 200 characters', () => {
    const result = signupSchema.safeParse({
      ...validSignup,
      password: 'a'.repeat(201),
    });
    expect(result.success).toBe(false);
  });

  it('rejects missing username', () => {
    const result = signupSchema.safeParse({ email: 'a@b.co', password: 'password123' });
    expect(result.success).toBe(false);
  });

  it('rejects missing password', () => {
    const result = signupSchema.safeParse({ username: 'validuser', email: 'a@b.co' });
    expect(result.success).toBe(false);
  });

  it('rejects empty string username', () => {
    const result = signupSchema.safeParse({ ...validSignup, username: '' });
    expect(result.success).toBe(false);
  });

  it('rejects empty string password', () => {
    const result = signupSchema.safeParse({ ...validSignup, password: '' });
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

  it('rejects username or email longer than 254 characters', () => {
    const result = loginSchema.safeParse({
      username: 'a'.repeat(255),
      password: 'password123',
    });
    expect(result.success).toBe(false);
  });
});