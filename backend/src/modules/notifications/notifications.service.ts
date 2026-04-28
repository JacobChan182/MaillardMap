import type { Pool } from 'pg';
import { getPool } from '../../db/pool.js';
import { rewritePublicMediaUrl } from '../../services/s3.js';

export type NotificationType =
  | 'friend_request'
  | 'friend_accept'
  | 'like'
  | 'comment'
  | 'reply'
  | 'mention'
  | 'restaurant_share';

export type AppNotification = {
  id: string;
  type: NotificationType;
  createdAt: string;
  actorId: string;
  actorUsername: string;
  actorDisplayName: string | null;
  actorAvatarUrl: string | null;
  postId: string | null;
  commentId: string | null;
  previewText: string | null;
  restaurantId: string | null;
};

const LIMIT = 100;
const PER_SOURCE = 80;

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function textMentionsUsername(text: string, username: string): boolean {
  if (!username) return false;
  const re = new RegExp(`(^|[^a-zA-Z0-9_])@${escapeRegExp(username)}(?![a-zA-Z0-9_])`, 'i');
  return re.test(text);
}

function trunc(s: string, max: number): string {
  const t = s.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1)}…`;
}

function iso(d: unknown): string {
  if (d instanceof Date) return d.toISOString();
  return String(d);
}

async function ensureDismissedNotificationsTable(pool: Pool): Promise<void> {
  await pool.query(`
    create table if not exists dismissed_notifications (
      user_id uuid not null references users(id) on delete cascade,
      notification_id text not null,
      dismissed_at timestamptz not null default now(),
      primary key (user_id, notification_id)
    )
  `);
  await pool.query('create index if not exists idx_dismissed_notifications_user_id on dismissed_notifications(user_id)');
}

export async function getNotifications(userId: string): Promise<AppNotification[]> {
  const pool = getPool();
  await ensureDismissedNotificationsTable(pool);
  const userRes = await pool.query<{ username: string }>('select username from users where id = $1', [userId]);
  const myUsername = userRes.rows[0]?.username ?? '';

  const items: AppNotification[] = [];

  const frRes = await pool.query<{
    id: string;
    created_at: Date;
    user_id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
  }>(
    `select f.id, f.created_at, f.user_id, u.username, u.display_name, u.avatar_url
     from friendships f
     join users u on u.id = f.user_id
     where f.friend_id = $1 and f.status = 'pending'
     order by f.created_at desc
     limit $2`,
    [userId, PER_SOURCE],
  );
  for (const r of frRes.rows) {
    items.push({
      id: `fr:${r.id}`,
      type: 'friend_request',
      createdAt: iso(r.created_at),
      actorId: String(r.user_id),
      actorUsername: r.username,
      actorDisplayName: r.display_name,
      actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
      postId: null,
      commentId: null,
      previewText: null,
      restaurantId: null,
    });
  }

  const acceptRes = await pool.query<{
    id: string;
    accepted_at: Date;
    friend_id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
  }>(
    `select f.id, f.accepted_at, f.friend_id, u.username, u.display_name, u.avatar_url
     from friendships f
     join users u on u.id = f.friend_id
     where f.user_id = $1 and f.status = 'accepted' and f.accepted_at is not null
     order by f.accepted_at desc
     limit $2`,
    [userId, PER_SOURCE],
  );
  for (const r of acceptRes.rows) {
    items.push({
      id: `fac:${r.id}`,
      type: 'friend_accept',
      createdAt: iso(r.accepted_at),
      actorId: String(r.friend_id),
      actorUsername: r.username,
      actorDisplayName: r.display_name,
      actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
      postId: null,
      commentId: null,
      previewText: 'Accepted your request',
      restaurantId: null,
    });
  }

  const shareRes = await pool.query<{
    id: string;
    created_at: Date;
    from_user_id: string;
    restaurant_id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
    restaurant_name: string;
  }>(
    `select rs.id, rs.created_at, rs.from_user_id, rs.restaurant_id,
            u.username, u.display_name, u.avatar_url, r.name as restaurant_name
     from restaurant_shares rs
     join users u on u.id = rs.from_user_id
     join restaurants r on r.id = rs.restaurant_id
     where rs.to_user_id = $1
     order by rs.created_at desc
     limit $2`,
    [userId, PER_SOURCE],
  );
  for (const r of shareRes.rows) {
    items.push({
      id: `rs:${r.id}`,
      type: 'restaurant_share',
      createdAt: iso(r.created_at),
      actorId: String(r.from_user_id),
      actorUsername: r.username,
      actorDisplayName: r.display_name,
      actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
      postId: null,
      commentId: null,
      previewText: r.restaurant_name,
      restaurantId: String(r.restaurant_id),
    });
  }

  const likeRes = await pool.query<{
    id: string;
    created_at: Date;
    user_id: string;
    post_id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
    restaurant_name: string;
  }>(
    `select l.id, l.created_at, l.user_id, l.post_id, u.username, u.display_name, u.avatar_url,
            r.name as restaurant_name
     from likes l
     join posts p on p.id = l.post_id
     join users u on u.id = l.user_id
     join restaurants r on r.id = p.restaurant_id
     where p.user_id = $1 and l.user_id <> $1
     order by l.created_at desc
     limit $2`,
    [userId, PER_SOURCE],
  );
  for (const r of likeRes.rows) {
    items.push({
      id: `like:${r.id}`,
      type: 'like',
      createdAt: iso(r.created_at),
      actorId: String(r.user_id),
      actorUsername: r.username,
      actorDisplayName: r.display_name,
      actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
      postId: String(r.post_id),
      commentId: null,
      previewText: r.restaurant_name,
      restaurantId: null,
    });
  }

  const replyRes = await pool.query<{
    id: string;
    created_at: Date;
    user_id: string;
    post_id: string;
    text: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
    restaurant_name: string;
  }>(
    `select c.id, c.created_at, c.user_id, c.post_id, c.text,
            u.username, u.display_name, u.avatar_url, r.name as restaurant_name
     from comments c
     join comments parent on parent.id = c.parent_id
     join users u on u.id = c.user_id
     join posts p on p.id = c.post_id
     join restaurants r on r.id = p.restaurant_id
     where parent.user_id = $1 and c.user_id <> $1
     order by c.created_at desc
     limit $2`,
    [userId, PER_SOURCE],
  );

  const usedCommentIds = new Set<string>();

  for (const r of replyRes.rows) {
    const cid = String(r.id);
    usedCommentIds.add(cid);
    items.push({
      id: `reply:${cid}`,
      type: 'reply',
      createdAt: iso(r.created_at),
      actorId: String(r.user_id),
      actorUsername: r.username,
      actorDisplayName: r.display_name,
      actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
      postId: String(r.post_id),
      commentId: cid,
      previewText: trunc(r.text, 140),
      restaurantId: null,
    });
  }

  const commentRes = await pool.query<{
    id: string;
    created_at: Date;
    user_id: string;
    post_id: string;
    text: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
    restaurant_name: string;
  }>(
    `select c.id, c.created_at, c.user_id, c.post_id, c.text,
            u.username, u.display_name, u.avatar_url, r.name as restaurant_name
     from comments c
     join posts p on p.id = c.post_id
     join users u on u.id = c.user_id
     join restaurants r on r.id = p.restaurant_id
     where p.user_id = $1 and c.user_id <> $1 and c.parent_id is null
     order by c.created_at desc
     limit $2`,
    [userId, PER_SOURCE],
  );
  for (const r of commentRes.rows) {
    const cid = String(r.id);
    if (usedCommentIds.has(cid)) continue;
    usedCommentIds.add(cid);
    items.push({
      id: `comment:${cid}`,
      type: 'comment',
      createdAt: iso(r.created_at),
      actorId: String(r.user_id),
      actorUsername: r.username,
      actorDisplayName: r.display_name,
      actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
      postId: String(r.post_id),
      commentId: cid,
      previewText: trunc(r.text, 140),
      restaurantId: null,
    });
  }

  if (myUsername.length > 0) {
    const mentionRes = await pool.query<{
      id: string;
      created_at: Date;
      user_id: string;
      post_id: string;
      text: string;
      username: string;
      display_name: string | null;
      avatar_url: string | null;
      restaurant_name: string;
    }>(
      `select c.id, c.created_at, c.user_id, c.post_id, c.text,
              u.username, u.display_name, u.avatar_url, r.name as restaurant_name
       from comments c
       join users u on u.id = c.user_id
       join posts p on p.id = c.post_id
       join restaurants r on r.id = p.restaurant_id
       where c.user_id <> $1 and c.text ilike $2
       order by c.created_at desc
       limit 200`,
      [userId, `%@${myUsername}%`],
    );
    for (const r of mentionRes.rows) {
      const cid = String(r.id);
      if (!textMentionsUsername(r.text, myUsername)) continue;
      if (usedCommentIds.has(cid)) continue;
      usedCommentIds.add(cid);
      items.push({
        id: `mention:${cid}`,
        type: 'mention',
        createdAt: iso(r.created_at),
        actorId: String(r.user_id),
        actorUsername: r.username,
        actorDisplayName: r.display_name,
        actorAvatarUrl: rewritePublicMediaUrl(r.avatar_url),
        postId: String(r.post_id),
        commentId: cid,
        previewText: trunc(r.text, 140),
        restaurantId: null,
      });
    }
  }

  const dismissedRes = await pool.query<{ notification_id: string }>(
    'select notification_id from dismissed_notifications where user_id = $1',
    [userId],
  );
  const dismissed = new Set(dismissedRes.rows.map((r) => r.notification_id));

  items.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  return items.filter((item) => !dismissed.has(item.id)).slice(0, LIMIT);
}

export async function dismissNotification(userId: string, notificationId: string): Promise<void> {
  const pool = getPool();
  await ensureDismissedNotificationsTable(pool);
  await pool.query(
    `insert into dismissed_notifications (user_id, notification_id)
     values ($1, $2)
     on conflict (user_id, notification_id) do nothing`,
    [userId, notificationId],
  );
}
