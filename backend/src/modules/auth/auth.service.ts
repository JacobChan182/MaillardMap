import bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import type { DatabaseError } from 'pg';
import type { LoginInput, ResendConfirmationInput, SignupInput } from './auth.schemas.js';
import { getPool } from '../../db/pool.js';
import { rewritePublicMediaUrl } from '../../services/s3.js';
import { sendSignupConfirmationEmail } from '../../services/email.js';

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
  email_verified_at: string | null;
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

function publicUserFromRow(user: UserRow) {
  return {
    id: user.id,
    username: user.username,
    phoneOrEmail: user.phone_or_email,
    displayName: user.display_name,
    avatarUrl: rewritePublicMediaUrl(user.avatar_url),
    bio: user.bio,
    createdAt: user.created_at,
    profilePrivate: user.profile_private,
  };
}

export type SignupResult =
  | {
      ok: true;
      needsVerification: true;
      user: ReturnType<typeof publicUserFromRow>;
      message: string;
    }
  | { ok: false; status: number; code: string; message: string };

export async function signup(input: SignupInput): Promise<SignupResult> {
  const pool = getPool();
  const passwordHash = await bcrypt.hash(input.password, 12);
  const email = input.email.trim().toLowerCase();
  const plainToken = randomBytes(32).toString('hex');
  const tokenHash = createHash('sha256').update(plainToken).digest('hex');
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  try {
    await pool.query('begin');
    try {
      const res = await pool.query<UserRow>(
        `
          insert into users (username, password_hash, phone_or_email, email_verified_at, email_confirm_token_hash, email_confirm_expires_at)
          values ($1, $2, $3, null, $4, $5)
          returning id, username, phone_or_email, display_name, avatar_url, bio, created_at, password_hash, profile_private,
                    email_verified_at
        `,
        [input.username, passwordHash, email, tokenHash, expiresAt.toISOString()],
      );

      const user = res.rows[0]!;
      await sendSignupConfirmationEmail(email, plainToken);
      await pool.query('commit');

      return {
        ok: true,
        needsVerification: true,
        user: publicUserFromRow(user),
        message: 'Check your email to confirm your account before logging in.',
      };
    } catch (e) {
      await pool.query('rollback');
      throw e;
    }
  } catch (e) {
    const err = e as Partial<DatabaseError>;
    if (err.code === '23505') {
      const detail = (err as { detail?: string }).detail;
      if (detail?.includes('phone_or_email')) {
        return {
          ok: false,
          status: 409,
          code: 'EMAIL_TAKEN',
          message: 'That email is already registered',
        };
      }
      return { ok: false, status: 409, code: 'USERNAME_TAKEN', message: 'That username is already taken' };
    }
    throw e;
  }
}

export async function login(input: LoginInput) {
  const pool = getPool();
  const raw = input.username.trim();
  const phoneOrEmailLookup = raw.includes('@') ? raw.toLowerCase() : raw;

  const res = await pool.query<UserRow>(
    `select id, username, phone_or_email, display_name, avatar_url, bio, password_hash, created_at, profile_private,
            email_verified_at
     from users where username = $1 or phone_or_email = $2`,
    [raw, phoneOrEmailLookup],
  );

  const user = res.rows[0];
  if (!user) {
    return { ok: false as const, status: 401, code: 'INVALID_CREDENTIALS' as const, message: 'No account found with that username or email' };
  }

  const valid = await bcrypt.compare(input.password, user.password_hash);
  if (!valid) {
    return { ok: false as const, status: 401, code: 'INVALID_CREDENTIALS' as const, message: 'Incorrect password' };
  }

  if (!user.email_verified_at) {
    return {
      ok: false as const,
      status: 403,
      code: 'EMAIL_NOT_VERIFIED' as const,
      message: 'Please confirm your email before logging in. Check your inbox for the link we sent.',
    };
  }

  const token = jwt.sign({ sub: user.id, username: user.username }, getJwtSecret(), { expiresIn: '7d' });

  return {
    ok: true as const,
    token,
    user: publicUserFromRow(user),
  };
}

export type VerifyEmailResult =
  | { ok: true; token: string; user: ReturnType<typeof publicUserFromRow> }
  | { ok: false; status: number; code: string; message: string };

export async function verifyEmail(plainToken: string): Promise<VerifyEmailResult> {
  const trimmed = plainToken.trim();
  if (!trimmed) {
    return { ok: false, status: 400, code: 'MISSING_TOKEN', message: 'Confirmation token is required' };
  }
  const tokenHash = createHash('sha256').update(trimmed).digest('hex');
  const pool = getPool();
  const res = await pool.query<UserRow>(
    `update users
       set email_verified_at = now(),
           email_confirm_token_hash = null,
           email_confirm_expires_at = null
     where email_confirm_token_hash = $1
       and (email_confirm_expires_at is null or email_confirm_expires_at > now())
     returning id, username, phone_or_email, display_name, avatar_url, bio, created_at, password_hash, profile_private,
               email_verified_at`,
    [tokenHash],
  );

  const user = res.rows[0];
  if (!user) {
    return {
      ok: false,
      status: 400,
      code: 'INVALID_OR_EXPIRED_TOKEN',
      message: 'This confirmation link is invalid or has expired. Sign up again or request a new email.',
    };
  }

  const token = jwt.sign({ sub: user.id, username: user.username }, getJwtSecret(), { expiresIn: '7d' });
  return { ok: true, token, user: publicUserFromRow(user) };
}

const resendGenericMessage =
  'If an account exists and still needs email confirmation, we sent a new message.';

export type ResendConfirmationResult =
  | { ok: true; message: string }
  | { ok: false; status: number; code: string; message: string };

export async function resendConfirmationEmail(input: ResendConfirmationInput): Promise<ResendConfirmationResult> {
  const raw = input.username.trim();
  const phoneOrEmailLookup = raw.includes('@') ? raw.toLowerCase() : raw;

  const pool = getPool();
  const res = await pool.query<Pick<UserRow, 'id' | 'phone_or_email' | 'email_verified_at'>>(
    `select id, phone_or_email, email_verified_at from users where username = $1 or phone_or_email = $2`,
    [raw, phoneOrEmailLookup],
  );

  const user = res.rows[0];
  if (!user) {
    return { ok: true, message: resendGenericMessage };
  }

  if (user.email_verified_at) {
    return {
      ok: false,
      status: 400,
      code: 'ALREADY_VERIFIED',
      message: 'This account is already confirmed. Try logging in.',
    };
  }

  const email = user.phone_or_email;
  if (!email) {
    return { ok: true, message: resendGenericMessage };
  }

  const plainToken = randomBytes(32).toString('hex');
  const tokenHash = createHash('sha256').update(plainToken).digest('hex');
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  const upd = await pool.query(
    `update users
       set email_confirm_token_hash = $1,
           email_confirm_expires_at = $2
     where id = $3 and email_verified_at is null`,
    [tokenHash, expiresAt.toISOString(), user.id],
  );

  if (upd.rowCount === 0) {
    return { ok: true, message: resendGenericMessage };
  }

  await sendSignupConfirmationEmail(email, plainToken);
  return { ok: true, message: 'Check your email for a new confirmation link.' };
}
