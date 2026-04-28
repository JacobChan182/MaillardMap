import { getPool } from '../../db/pool.js';
import { areMutualFriends } from '../friends/friends.service.js';
import { searchNearby } from '../../external/foursquare.js';
import { sendPushToUser } from '../../services/apns.js';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type RestaurantRow = {
  id: string;
  foursquare_id: string;
  name: string;
  lat: number;
  lng: number;
  cuisine: string | null;
  address: string | null;
};

function displayName(row: { username: string; display_name: string | null }): string {
  return row.display_name?.trim() || `@${row.username}`;
}

/**
 * Search restaurants from Foursquare, caching results locally.
 */
export async function searchRestaurants(q: string, lat?: number, lng?: number) {
  const pool = getPool();

  // First check local DB for cached results
  let sql = `select id, foursquare_id, name, lat, lng, cuisine, address
     from restaurants
     where name ilike $1`;
  const args: (string | number)[] = [`%${q}%`];

  if (lat != null && lng != null) {
    args.push(lat, lng);
    sql += ` order by sqrt((lat - $2) * (lat - $2) + (lng - $3) * (lng - $3))`;
  }
  sql += ` limit 30`;

  const cached = await pool.query<RestaurantRow>(sql, args);

  if (cached.rows.length > 0) {
    return cached.rows.map(rowToRestaurant);
  }

  // Not found locally - fetch from Foursquare
  let results;
  if (lat != null && lng != null) {
    results = await searchNearby(lat, lng, 5000, q);
  } else {
    // Fallback center (NYC) when no coordinates provided
    results = await searchNearby(40.7128, -74.006, 50000, q);
  }
  if (results.length > 0) {
    const ids: string[] = [];
    for (const v of results) {
      const res = await pool.query(
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
        [
          v.foursquare_id,
          v.name,
          v.lat,
          v.lng,
          v.categories || null,
          v.address?.trim() ? v.address.trim() : null,
        ],
      );
      ids.push(res.rows[0].id);
    }
    if (ids.length > 0) {
      const fresh = await pool.query<RestaurantRow>(
        'select id, foursquare_id, name, lat, lng, cuisine, address from restaurants where id = any($1)',
        [ids],
      );
      return fresh.rows.map(rowToRestaurant);
    }
  }

  return [];
}

/**
 * Get or create a restaurant record from Foursquare data.
 * Returns the internal restaurant id.
 */
export async function upsertRestaurant(data: {
  foursquareId: string;
  name: string;
  lat: number;
  lng: number;
  cuisine?: string;
  address?: string;
}): Promise<string> {
  const pool = getPool();
  const addr = data.address?.trim() ? data.address.trim() : null;
  const result = await pool.query(
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
    [data.foursquareId, data.name, data.lat, data.lng, data.cuisine ?? null, addr],
  );
  return result.rows[0].id;
}

/**
 * Get a restaurant by internal ID.
 */
export async function getRestaurantById(id: string) {
  const pool = getPool();
  const res = await pool.query<RestaurantRow>(
    'select id, foursquare_id, name, lat, lng, cuisine, address from restaurants where id = $1',
    [id],
  );
  const row = res.rows[0];
  if (!row) return null;
  return rowToRestaurant(row);
}

/**
 * Resolve a restaurant by its Foursquare ID.
 */
export async function getRestaurantByFoursquareId(foursquareId: string) {
  const pool = getPool();
  const res = await pool.query<RestaurantRow>(
    'select id, foursquare_id, name, lat, lng, cuisine, address from restaurants where foursquare_id = $1',
    [foursquareId],
  );
  return res.rows[0];
}

function rowToRestaurant(row: RestaurantRow) {
  return {
    id: row.id,
    foursquareId: row.foursquare_id,
    name: row.name,
    lat: row.lat,
    lng: row.lng,
    cuisine: row.cuisine,
    address: row.address,
  };
}

export async function createRestaurantShare(
  fromUserId: string,
  recipientId: string,
  restaurantId: string,
): Promise<{ ok: true } | { ok: false; status: number; code: string; message: string }> {
  if (!UUID_RE.test(recipientId) || !UUID_RE.test(restaurantId)) {
    return {
      ok: false,
      status: 400,
      code: 'VALIDATION_ERROR',
      message: 'recipientId and restaurantId must be UUIDs',
    };
  }
  if (fromUserId === recipientId) {
    return {
      ok: false,
      status: 400,
      code: 'VALIDATION_ERROR',
      message: 'Cannot share with yourself',
    };
  }
  const restaurant = await getRestaurantById(restaurantId);
  if (!restaurant) {
    return { ok: false, status: 404, code: 'NOT_FOUND', message: 'Restaurant not found' };
  }
  const friends = await areMutualFriends(fromUserId, recipientId);
  if (!friends) {
    return {
      ok: false,
      status: 403,
      code: 'FORBIDDEN',
      message: 'You can only share restaurants with accepted friends',
    };
  }
  const pool = getPool();
  await pool.query(
    `insert into restaurant_shares (from_user_id, to_user_id, restaurant_id)
     values ($1, $2, $3)`,
    [fromUserId, recipientId, restaurantId],
  );
  const actor = await pool.query<{ username: string; display_name: string | null }>(
    'select username, display_name from users where id = $1',
    [fromUserId],
  );
  const actorName = actor.rows[0] ? displayName(actor.rows[0]) : 'Someone';
  void sendPushToUser(recipientId, {
    title: 'Restaurant shared',
    body: `${actorName} shared ${restaurant.name}`,
    data: { type: 'restaurant_share', restaurantId, actorId: fromUserId },
  });
  return { ok: true };
}
