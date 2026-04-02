import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { DatabaseError } from 'pg';
import type { LoginInput, SignupInput } from './auth.schemas.js';
import { getPool } from '../../db/pool.js';
import { rewritePublicMediaUrl } from '../../services/s3.js';

type UserRow = {
  id: string;
  username: string;
  phone_or_email: string | null;
  display_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  password_hash: string;
  created_at: string;
  profile_private: boolean;
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
  const phoneOrEmail = input.phoneOrEmail?.trim() || null;
  try {
    const res = await pool.query<UserRow>(
      `
        insert into users (username, password_hash, phone_or_email)
        values ($1, $2, $3)
        returning id, username, phone_or_email, display_name, avatar_url, bio, created_at, password_hash, profile_private
      `,
      [input.username, passwordHash, phoneOrEmail],
    );

    const user = res.rows[0]!;
    const token = jwt.sign(
      { sub: user.id, username: user.username },
      getJwtSecret(),
      { expiresIn: '7d' },
    );
    return {
      ok: true as const,
      token,
      user: {
        id: user.id,
        username: user.username,
        phoneOrEmail: user.phone_or_email,
        displayName: user.display_name,
        avatarUrl: rewritePublicMediaUrl(user.avatar_url),
        bio: user.bio,
        createdAt: user.created_at,
        profilePrivate: user.profile_private,
      },
    };
  } catch (e) {
    const err = e as Partial<DatabaseError>;
    if (err.code === '23505') {
      const detail = (err as any).detail as string | undefined;
      if (detail?.includes('phone_or_email')) {
        return { ok: false as const, status: 409, code: 'EMAIL_OR_PHONE_TAKEN' as const, message: 'That email or phone is already in use' };
      }
      return { ok: false as const, status: 409, code: 'USERNAME_TAKEN' as const, message: 'That username is already taken' };
    }
    throw e;
  }
}

export async function login(input: LoginInput) {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    `select id, username, phone_or_email, display_name, avatar_url, bio, password_hash, created_at, profile_private
     from users where username = $1 or phone_or_email = $1`,
    [input.username],
  );

  const user = res.rows[0];
  if (!user) {
    return { ok: false as const, status: 401, code: 'INVALID_CREDENTIALS' as const, message: 'No account found with that username or email' };
  }

  const valid = await bcrypt.compare(input.password, user.password_hash);
  if (!valid) {
    return { ok: false as const, status: 401, code: 'INVALID_CREDENTIALS' as const, message: 'Incorrect password' };
  }

  const token = jwt.sign(
    { sub: user.id, username: user.username },
    getJwtSecret(),
    { expiresIn: '7d' },
  );

  return {
    ok: true as const,
    token,
    user: {
      id: user.id,
      username: user.username,
      phoneOrEmail: user.phone_or_email,
      displayName: user.display_name,
      avatarUrl: rewritePublicMediaUrl(user.avatar_url),
      bio: user.bio,
      createdAt: user.created_at,
      profilePrivate: user.profile_private,
    },
  };
}

