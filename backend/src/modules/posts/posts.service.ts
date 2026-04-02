import type { Pool } from 'pg';
import { getPool } from '../../db/pool.js';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(s: string): boolean {
  return UUID_RE.test(s);
}

type PostData = {
  id: string;
  userId: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
  restaurantId: string;
  restaurantName: string;
  restaurantAddress: string | null;
  lat: number;
  lng: number;
  comment: string | null;
  photos: { id: string; postId: string; url: string; orderIndex: number }[];
  liked: boolean;
  likeCount: number;
  commentCount: number;
  createdAt: string;
};

export async function createPost(userId: string, input: {
  foursquareId: string;
  name: string;
  lat: number;
  lng: number;
  cuisine?: string;
  address?: string | null;
  comment?: string;
  photos?: { url: string }[];
}): Promise<string> {
  const pool = getPool();

  const addressParam = input.address?.trim() ? input.address.trim() : null;

  // Upsert restaurant; merge address so rows from search / Foursquare keep or gain a street line.
  const upsertRes = await pool.query(
    `insert into restaurants (foursquare_id, name, lat, lng, cuisine, address)
     values ($1, $2, $3, $4, $5, $6)
     on conflict (foursquare_id) do update set
       name = excluded.name,
       lat = excluded.lat,
       lng = excluded.lng,
       cuisine = coalesce(excluded.cuisine, restaurants.cuisine),
       address = coalesce(nullif(trim(excluded.address), ''), restaurants.address),
       updated_at = now()
     returning id`,
    [input.foursquareId, input.name, input.lat, input.lng, input.cuisine ?? null, addressParam],
  );
  const restaurantId = upsertRes.rows[0].id;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const postRes = await client.query(
      `insert into posts (user_id, restaurant_id, comment)
       values ($1, $2, $3)
       returning id`,
      [userId, restaurantId, input.comment ?? null],
    );
    const postId = postRes.rows[0].id;

    if (input.photos && input.photos.length > 0) {
      for (let i = 0; i < input.photos.length; i++) {
        await client.query(
          `insert into post_photos (post_id, url, order_index)
           values ($1, $2, $3)`,
          [postId, input.photos[i].url, i + 1],
        );
      }
    }

    await client.query('COMMIT');
    return postId;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

/**
 * Get friend IDs (bidirectional) for a user.
 */
export async function getFriendIds(pool: Pool, userId: string): Promise<string[]> {
  const res = await pool.query<{ id: string }>(
    `select friend_id as id from friendships where user_id = $1 and status = 'accepted'
     union
     select user_id as id from friendships where friend_id = $1 and status = 'accepted'`,
    [userId],
  );
  return res.rows.map((r) => r.id);
}

/**
 * Query a set of posts with all joined data, photos, like counts, and liked status for a specific user.
 */
export async function queryPosts(
  pool: Pool,
  userIds: string[],
  likerId: string,
  options?: { restaurantId?: string },
): Promise<PostData[]> {
  const restaurantId = options?.restaurantId;
  const postsRes = await pool.query(
    `select
       p.id as post_id,
       p.user_id,
       u.username,
       u.display_name,
       u.avatar_url,
       p.restaurant_id,
       r.name as restaurant_name,
       r.address as restaurant_address,
       r.lat as restaurant_lat,
       r.lng as restaurant_lng,
       p.comment,
       p.comment_count,
       p.created_at
     from posts p
     join users u on u.id = p.user_id
     join restaurants r on r.id = p.restaurant_id
     where p.user_id = any($1)
     ${restaurantId ? 'and p.restaurant_id = $2' : ''}
     order by p.created_at desc`,
    restaurantId ? [userIds, restaurantId] : [userIds],
  );

  if (postsRes.rows.length === 0) return [];

  const postIds = postsRes.rows.map((r) => r.post_id);

  // Fetch photos
  const photosRes = await pool.query<{ post_id: string; id: string; url: string; order_index: number }>(
    `select post_id, id, url, order_index from post_photos where post_id = any($1) order by post_id, order_index`,
    [postIds],
  );
  const photosByPost = new Map<string, { id: string; postId: string; url: string; orderIndex: number }[]>();
  for (const p of photosRes.rows) {
    const arr = photosByPost.get(p.post_id) || [];
    arr.push({ id: p.id, postId: p.post_id, url: p.url, orderIndex: p.order_index });
    photosByPost.set(p.post_id, arr);
  }

  // Fetch like counts
  const likesRes = await pool.query<{ post_id: string; count: string }>(
    `select post_id, count(*)::text as count from likes where post_id = any($1) group by post_id`,
    [postIds],
  );
  const likeCounts = new Map<string, number>();
  for (const r of likesRes.rows) {
    likeCounts.set(r.post_id, parseInt(r.count, 10));
  }

  // Fetch liked-by-liker (skip when anonymous or invalid — PG uuid columns reject '')
  let likedSet = new Set<string>();
  if (isUuid(likerId)) {
    const likedRes = await pool.query<{ post_id: string }>(
      `select post_id from likes where user_id = $1 and post_id = any($2)`,
      [likerId, postIds],
    );
    likedSet = new Set(likedRes.rows.map((r) => r.post_id));
  }

  // Build results
  const results: PostData[] = [];
  for (const row of postsRes.rows) {
    results.push({
      id: row.post_id,
      userId: row.user_id,
      username: row.username,
      displayName: row.display_name,
      avatarUrl: row.avatar_url,
      restaurantId: row.restaurant_id,
      restaurantName: row.restaurant_name,
      restaurantAddress: row.restaurant_address,
      lat: row.restaurant_lat,
      lng: row.restaurant_lng,
      comment: row.comment,
      photos: photosByPost.get(row.post_id) || [],
      liked: likedSet.has(row.post_id),
      likeCount: likeCounts.get(row.post_id) || 0,
      commentCount: row.comment_count || 0,
      createdAt: row.created_at,
    });
  }

  return results;
}

/**
 * Get personalized feed: posts from friends (and own posts), ordered by recency.
 */
export async function getFeed(userId: string): Promise<PostData[]> {
  const pool = getPool();
  const friendIds = await getFriendIds(pool, userId);
  const allIds = friendIds.length > 0 ? [...friendIds, userId] : [userId];
  return queryPosts(pool, allIds, userId);
}

/**
 * Posts at one restaurant from friends + self (same visibility as feed), newest first.
 */
export async function getFeedPostsByRestaurant(userId: string, restaurantId: string): Promise<PostData[]> {
  if (!isUuid(restaurantId)) return [];
  const pool = getPool();
  const friendIds = await getFriendIds(pool, userId);
  const allIds = friendIds.length > 0 ? [...friendIds, userId] : [userId];
  return queryPosts(pool, allIds, userId, { restaurantId });
}

/**
 * Get all posts by a specific user.
 */
export async function getPostsByUser(targetUserId: string, likerId: string): Promise<PostData[]> {
  const pool = getPool();
  return queryPosts(pool, [targetUserId], likerId);
}

/**
 * Like or unlike a post. Returns true if liked (just added), false if unliked (just removed).
 */
export async function toggleLike(userId: string, postId: string): Promise<boolean> {
  const pool = getPool();

  const postCheck = await pool.query('select id from posts where id = $1', [postId]);
  if (postCheck.rows.length === 0) {
    return false; // Post not found; treat as "already unliked"
  }

  try {
    await pool.query(
      `insert into likes (user_id, post_id) values ($1, $2)`,
      [userId, postId],
    );
    return true;
  } catch (e) {
    const err = e as { code?: string };
    if (err.code === '23505') {
      // Already liked, unlike it
      await pool.query(`delete from likes where user_id = $1 and post_id = $2`, [userId, postId]);
      return false;
    }
    throw e;
  }
}

// ─── Comments ───────────────────────────────────────────────────────

type CommentRow = {
  id: string;
  user_id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  text: string;
  created_at: string;
};

/**
 * Get all comments for a post, ordered oldest first.
 */
export async function getCommentsByPost(postId: string): Promise<
  {
    id: string;
    userId: string;
    username: string;
    displayName: string | null;
    avatarUrl: string | null;
    text: string;
    createdAt: string;
  }[]
> {
  const pool = getPool();
  const res = await pool.query<CommentRow>(
    `select c.id, c.user_id, c.text, c.created_at, u.username, u.display_name, u.avatar_url
     from comments c
     join users u on u.id = c.user_id
     where c.post_id = $1
     order by c.created_at asc`,
    [postId],
  );
  return res.rows.map((r) => ({
    id: r.id,
    userId: r.user_id,
    username: r.username,
    displayName: r.display_name,
    avatarUrl: r.avatar_url,
    text: r.text,
    createdAt: r.created_at,
  }));
}

/**
 * Add a comment to a post. Returns the new comment.
 */
export async function addComment(userId: string, postId: string, text: string) {
  const pool = getPool();
  const commentRes = await pool.query(
    `insert into comments (user_id, post_id, text) values ($1, $2, $3) returning id`,
    [userId, postId, text],
  );
  const commentId = commentRes.rows[0].id;

  // Increment post's comment_count so feed cards show live count
  await pool.query(`update posts set comment_count = comment_count + 1 where id = $1`, [postId]);

  // Re-fetch to return username
  const comments = await getCommentsByPost(postId);
  return comments.find((c) => c.id === commentId)!;
}
