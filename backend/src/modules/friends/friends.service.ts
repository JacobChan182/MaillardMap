import type { DatabaseError } from 'pg';
import { getPool } from '../../db/pool.js';
import { rewritePublicMediaUrl } from '../../services/s3.js';
import type { FriendRequestInput } from './friends.schemas.js';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(s: string): boolean {
  return UUID_RE.test(s);
}

type FriendshipRow = {
  id: string;
  friend_id: string;
  friend_username: string;
  friend_display_name: string | null;
  friend_avatar_url: string | null;
  status: string;
  created_at: string;
  incoming_pending: boolean | null;
};

export async function sendFriendRequest(userId: string, input: FriendRequestInput) {
  const pool = getPool();

  // Check target user exists
  const targetCheck = await pool.query('select id from users where id = $1', [input.friendId]);
  if (targetCheck.rows.length === 0) {
    return { ok: false as const, status: 404, code: 'USER_NOT_FOUND' as const };
  }

  // Cannot friend yourself
  if (input.friendId === userId) {
    return { ok: false as const, status: 400, code: 'SELF_FRIEND' as const };
  }

  const edge = await pool.query<{ user_id: string; friend_id: string; status: string }>(
    `select user_id, friend_id, status from friendships
     where (user_id = $1 and friend_id = $2) or (user_id = $2 and friend_id = $1)`,
    [userId, input.friendId],
  );
  const rows = edge.rows;
  if (rows.some((r) => r.status === 'accepted')) {
    return { ok: true as const };
  }
  const outboundPending = rows.find((r) => r.status === 'pending' && r.user_id === userId && r.friend_id === input.friendId);
  const inboundPending = rows.find((r) => r.status === 'pending' && r.user_id === input.friendId && r.friend_id === userId);
  if (outboundPending) {
    return { ok: true as const };
  }
  if (inboundPending) {
    const acceptResult = await acceptFriendRequest(userId, input.friendId);
    if (acceptResult.ok) return { ok: true as const };
    return acceptResult;
  }

  try {
    await pool.query(
      `insert into friendships (user_id, friend_id, status)
       values ($1, $2, 'pending')`,
      [userId, input.friendId],
    );
    return { ok: true as const };
  } catch (e) {
    const err = e as Partial<DatabaseError>;
    if (err.code === '23505') {
      return { ok: false as const, status: 409, code: 'REQUEST_EXISTS' as const };
    }
    throw e;
  }
}

export async function acceptFriendRequest(userId: string, friendId: string) {
  const pool = getPool();

  // Update the inbound pending request to accepted
  const result = await pool.query(
    `update friendships
     set status = 'accepted', accepted_at = now()
     where user_id = $1 and friend_id = $2 and status = 'pending'
     returning id`,
    [friendId, userId],
  );

  if (result.rows.length === 0) {
    return { ok: false as const, status: 404, code: 'REQUEST_NOT_FOUND' as const };
  }

  return { ok: true as const };
}

/**
 * Remove a pending friendship (either direction: revoke, or decline incoming)
 * or an accepted friendship (unfriend).
 */
export async function removeFriendship(userId: string, friendId: string) {
  if (!isUuid(userId) || !isUuid(friendId)) {
    return { ok: false as const, status: 400, code: 'INVALID_ID' as const };
  }
  if (userId === friendId) {
    return { ok: false as const, status: 400, code: 'SELF_FRIEND' as const };
  }

  const pool = getPool();
  const result = await pool.query(
    `delete from friendships
     where (
       status = 'pending'
       and (
         (user_id = $1::uuid and friend_id = $2::uuid)
         or (user_id = $2::uuid and friend_id = $1::uuid)
       )
     )
     or (
       status = 'accepted'
       and (
         (user_id = $1::uuid and friend_id = $2::uuid)
         or (user_id = $2::uuid and friend_id = $1::uuid)
       )
     )
     returning id`,
    [userId, friendId],
  );

  if (result.rows.length === 0) {
    return { ok: false as const, status: 404, code: 'FRIENDSHIP_NOT_FOUND' as const };
  }

  return { ok: true as const };
}

export async function getFriendsList(userId: string) {
  const pool = getPool();
  const res = await pool.query<FriendshipRow>(
    `select
       f.id,
       f.user_id as friend_id,
       u.username as friend_username,
       u.display_name as friend_display_name,
       u.avatar_url as friend_avatar_url,
       f.status,
       f.created_at,
       true as incoming_pending
     from friendships f
     join users u on u.id = f.user_id
     where f.friend_id = $1 and f.status = 'pending'

     union all

     select
       f.id,
       f.friend_id as friend_id,
       u.username as friend_username,
       u.display_name as friend_display_name,
       u.avatar_url as friend_avatar_url,
       f.status,
       f.created_at,
       false as incoming_pending
     from friendships f
     join users u on u.id = f.friend_id
     where f.user_id = $1 and f.status = 'pending'

     union all

     select
       f.id,
       f.user_id as friend_id,
       u.username as friend_username,
       u.display_name as friend_display_name,
       u.avatar_url as friend_avatar_url,
       f.status,
       f.created_at,
       null::boolean as incoming_pending
     from friendships f
     join users u on u.id = f.user_id
     where f.friend_id = $1 and f.status = 'accepted'

     union all

     select
       f.id,
       f.friend_id as friend_id,
       u.username as friend_username,
       u.display_name as friend_display_name,
       u.avatar_url as friend_avatar_url,
       f.status,
       f.created_at,
       null::boolean as incoming_pending
     from friendships f
     join users u on u.id = f.friend_id
     where f.user_id = $1 and f.status = 'accepted'

     order by created_at desc`,
    [userId],
  );

  return res.rows.map((r) => ({
    id: r.id,
    friendId: r.friend_id,
    friendUsername: r.friend_username,
    friendDisplayName: r.friend_display_name,
    friendAvatarUrl: rewritePublicMediaUrl(r.friend_avatar_url),
    status: r.status as 'pending' | 'accepted',
    createdAt: r.created_at,
    incomingPending: r.incoming_pending,
  }));
}

/** True when there is an accepted friendship in either direction between the two users. */
export async function areMutualFriends(userIdA: string, userIdB: string): Promise<boolean> {
  if (userIdA === userIdB) return false;
  const pool = getPool();
  const res = await pool.query<{ one: number }>(
    `select 1 as one
     from friendships f
     where f.status = 'accepted'
       and (
         (f.user_id = $1 and f.friend_id = $2)
         or (f.user_id = $2 and f.friend_id = $1)
       )
     limit 1`,
    [userIdA, userIdB],
  );
  return res.rows.length > 0;
}
