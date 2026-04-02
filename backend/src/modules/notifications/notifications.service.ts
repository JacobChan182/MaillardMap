import { getPool } from '../../db/pool.js';
import { rewritePublicMediaUrl } from '../../services/s3.js';

export type NotificationType =
  | 'friend_request'
  | 'friend_accept'
  | 'like'
  | 'comment'
  | 'reply'
  | 'mention';

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

export async function getNotifications(userId: string): Promise<AppNotification[]> {
  const pool = getPool();
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
      });
    }
  }

  items.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  return items.slice(0, LIMIT);
}
