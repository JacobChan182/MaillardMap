import type { DatabaseError } from 'pg';
import { getPool } from '../../db/pool.js';
import type { FriendRequestInput } from './friends.schemas.js';

type FriendshipRow = {
  id: string;
  friend_id: string;
  friend_username: string;
  status: string;
  created_at: string;
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
     set status = 'accepted'
     where user_id = $1 and friend_id = $2 and status = 'pending'
     returning id`,
    [friendId, userId],
  );

  if (result.rows.length === 0) {
    return { ok: false as const, status: 404, code: 'REQUEST_NOT_FOUND' as const };
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
       f.status,
       f.created_at
     from friendships f
     join users u on u.id = f.user_id
     where f.friend_id = $1 and f.status = 'accepted'

     union all

     select
       f.id,
       f.friend_id as friend_id,
       u.username as friend_username,
       f.status,
       f.created_at
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
    status: 'accepted' as const,
    createdAt: r.created_at,
  }));
}
