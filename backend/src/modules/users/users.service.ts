import { getPool } from '../../db/pool.js';
import { rewritePublicMediaUrl } from '../../services/s3.js';

type UserRow = {
  id: string;
  username: string;
  phone_or_email: string | null;
  display_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  created_at: string;
};

export type PublicUser = {
  id: string;
  username: string;
  phoneOrEmail?: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  createdAt: string;
};

function rowToPublic(r: UserRow, includeContact: boolean): PublicUser {
  const base: PublicUser = {
    id: r.id,
    username: r.username,
    displayName: r.display_name,
    avatarUrl: rewritePublicMediaUrl(r.avatar_url),
    bio: r.bio,
    createdAt: r.created_at,
  };
  if (includeContact) {
    base.phoneOrEmail = r.phone_or_email;
  }
  return base;
}

export function isAvatarUrlFromOurStorage(url: string): boolean {
  const base = process.env.S3_PUBLIC_URL?.replace(/\/$/, '');
  const legacy = process.env.S3_PUBLIC_URL_LEGACY?.replace(/\/$/, '');
  if (base && (url === base || url.startsWith(`${base}/`))) return true;
  if (legacy && (url === legacy || url.startsWith(`${legacy}/`))) return true;
  return false;
}

export async function getUserById(id: string): Promise<PublicUser | null> {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    `select id, username, phone_or_email, display_name, avatar_url, bio, created_at
     from users where id = $1`,
    [id],
  );
  const user = res.rows[0];
  if (!user) return null;
  return rowToPublic(user, false);
}

export async function getUserByIdWithContact(id: string): Promise<PublicUser | null> {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    `select id, username, phone_or_email, display_name, avatar_url, bio, created_at
     from users where id = $1`,
    [id],
  );
  const user = res.rows[0];
  if (!user) return null;
  return rowToPublic(user, true);
}

export async function searchUsers(q: string): Promise<PublicUser[]> {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    `select id, username, phone_or_email, display_name, avatar_url, bio, created_at
     from users
     where username ilike $1
     limit 30`,
    [`%${q}%`],
  );
  return res.rows.map((r) => rowToPublic(r, false));
}

export async function updateMyProfile(
  userId: string,
  input: { displayName?: string | null; avatarUrl?: string | null; bio?: string | null },
): Promise<{ ok: true; user: PublicUser } | { ok: false; status: number; code: string; message: string }> {
  const pool = getPool();

  let normalizedDisplay: string | null | undefined;
  if (input.displayName !== undefined) {
    if (input.displayName === null) {
      normalizedDisplay = null;
    } else {
      const t = input.displayName.trim();
      if (t.length === 0) {
        normalizedDisplay = null;
      } else if (t.length > 50) {
        return { ok: false, status: 400, code: 'VALIDATION_ERROR', message: 'displayName must be at most 50 characters' };
      } else {
        normalizedDisplay = t;
      }
    }
  }

  if (input.avatarUrl !== undefined && input.avatarUrl !== null && !isAvatarUrlFromOurStorage(input.avatarUrl)) {
    return { ok: false, status: 400, code: 'INVALID_AVATAR_URL', message: 'avatarUrl must be from this app storage' };
  }

  let normalizedBio: string | null | undefined;
  if (input.bio !== undefined) {
    if (input.bio === null) {
      normalizedBio = null;
    } else {
      const b = input.bio.trim();
      if (b.length === 0) {
        normalizedBio = null;
      } else if (b.length > 200) {
        return { ok: false, status: 400, code: 'VALIDATION_ERROR', message: 'bio must be at most 200 characters' };
      } else {
        normalizedBio = b;
      }
    }
  }

  const sets: string[] = [];
  const values: unknown[] = [];
  let i = 1;

  if (normalizedDisplay !== undefined) {
    sets.push(`display_name = $${i++}`);
    values.push(normalizedDisplay);
  }
  if (input.avatarUrl !== undefined) {
    sets.push(`avatar_url = $${i++}`);
    values.push(input.avatarUrl);
  }
  if (normalizedBio !== undefined) {
    sets.push(`bio = $${i++}`);
    values.push(normalizedBio);
  }

  if (sets.length === 0) {
    const u = await getUserById(userId);
    if (!u) return { ok: false, status: 404, code: 'NOT_FOUND', message: 'User not found' };
    return { ok: true, user: u };
  }

  values.push(userId);
  await pool.query(`update users set ${sets.join(', ')} where id = $${i}`, values);

  const u = await getUserById(userId);
  if (!u) return { ok: false, status: 404, code: 'NOT_FOUND', message: 'User not found' };
  return { ok: true, user: u };
}
