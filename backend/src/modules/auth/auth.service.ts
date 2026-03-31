import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { DatabaseError } from 'pg';
import type { LoginInput, SignupInput } from './auth.schemas.js';
import { getPool } from '../../db/pool.js';

type UserRow = {
  id: string;
  username: string;
  password_hash: string;
  created_at: string;
};

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is required');
  }
  if (secret.length < 32) {
    throw new Error('JWT_SECRET must be at least 32 characters');
  }
  return secret;
}

export async function signup(input: SignupInput) {
  const pool = getPool();
  const passwordHash = await bcrypt.hash(input.password, 12);
  try {
    const res = await pool.query<UserRow>(
      `
        insert into users (username, password_hash)
        values ($1, $2)
        returning id, username, created_at, password_hash
      `,
      [input.username, passwordHash],
    );

    const user = res.rows[0]!;
    return { ok: true as const, user: { id: user.id, username: user.username, createdAt: user.created_at } };
  } catch (e) {
    const err = e as Partial<DatabaseError>;
    if (err.code === '23505') {
      return { ok: false as const, status: 409, code: 'USERNAME_TAKEN' as const };
    }
    throw e;
  }
}

export async function login(input: LoginInput) {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    'select id, username, password_hash, created_at from users where username = $1',
    [input.username],
  );

  const user = res.rows[0];
  if (!user) {
    return { ok: false as const, status: 401, code: 'INVALID_CREDENTIALS' as const };
  }

  const valid = await bcrypt.compare(input.password, user.password_hash);
  if (!valid) {
    return { ok: false as const, status: 401, code: 'INVALID_CREDENTIALS' as const };
  }

  const token = jwt.sign(
    { sub: user.id, username: user.username },
    getJwtSecret(),
    { expiresIn: '7d' },
  );

  return { ok: true as const, token, user: { id: user.id, username: user.username, createdAt: user.created_at } };
}

