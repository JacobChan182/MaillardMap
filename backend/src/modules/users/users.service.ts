import { getPool } from '../../db/pool.js';

type UserRow = {
  id: string;
  username: string;
  created_at: string;
};

export async function getUserById(id: string) {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    'select id, username, created_at from users where id = $1',
    [id],
  );
  const user = res.rows[0];
  if (!user) return null;
  return { id: user.id, username: user.username, createdAt: user.created_at };
}

export async function searchUsers(q: string) {
  const pool = getPool();
  const res = await pool.query<UserRow>(
    `select id, username, created_at
     from users
     where username ilike $1
     limit 30`,
    [`%${q}%`],
  );
  return res.rows.map((r) => ({
    id: r.id,
    username: r.username,
    createdAt: r.created_at,
  }));
}
