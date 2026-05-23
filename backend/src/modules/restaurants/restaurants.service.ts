import { getPool } from '../../db/pool.js';
import { areMutualFriends } from '../friends/friends.service.js';
import { searchNearby } from '../../external/foursquare.js';
import { sendPushToUser } from '../../services/apns.js';
import { isRestaurantCuisineLabel } from './restaurant-venue-filter.js';

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

/** ~10 miles — used for nearby Foursquare search and local cache radius. */
const SEARCH_RADIUS_M = 16093;

function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(Δφ / 2) ** 2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const HAVERSINE_SQL = `(6371000 * acos(
  least(1.0, greatest(-1.0,
    cos(radians($2)) * cos(radians(lat)) * cos(radians(lng) - radians($3)) +
    sin(radians($2)) * sin(radians(lat))
  ))
))`;

async function searchCachedByName(
  q: string,
  lat?: number,
  lng?: number,
  radiusM?: number,
): Promise<RestaurantRow[]> {
  const pool = getPool();
  let sql: string;
  let args: (string | number)[];

  if (lat != null && lng != null && radiusM != null) {
    sql = `select id, foursquare_id, name, lat, lng, cuisine, address
       from restaurants
       where name ilike $1
         and ${HAVERSINE_SQL} <= $4
       order by ${HAVERSINE_SQL}
       limit 30`;
    args = [`%${q}%`, lat, lng, radiusM];
  } else {
    sql = `select id, foursquare_id, name, lat, lng, cuisine, address
       from restaurants
       where name ilike $1`;
    args = [`%${q}%`];
    if (lat != null && lng != null) {
      args.push(lat, lng);
      sql += ` order by ${HAVERSINE_SQL}`;
    }
    sql += ` limit 30`;
  }

  const cached = await pool.query<RestaurantRow>(sql, args);
  return cached.rows.filter((row) => isRestaurantCuisineLabel(row.cuisine));
}

async function upsertFoursquareVenues(venues: Awaited<ReturnType<typeof searchNearby>>): Promise<RestaurantRow[]> {
  if (venues.length === 0) return [];
  const pool = getPool();
  const ids: string[] = [];
  for (const v of venues) {
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
  const fresh = await pool.query<RestaurantRow>(
    'select id, foursquare_id, name, lat, lng, cuisine, address from restaurants where id = any($1)',
    [ids],
  );
  return fresh.rows;
}

/**
 * Search restaurants from Foursquare, caching results locally.
 */
export async function searchRestaurants(q: string, lat?: number, lng?: number) {
  if (lat != null && lng != null) {
    const [fsqVenues, cachedNearby] = await Promise.all([
      searchNearby(lat, lng, SEARCH_RADIUS_M, q),
      searchCachedByName(q, lat, lng, SEARCH_RADIUS_M),
    ]);

    const upserted = await upsertFoursquareVenues(fsqVenues);

    const merged = new Map<string, RestaurantRow>();
    for (const row of [...cachedNearby, ...upserted]) {
      merged.set(row.foursquare_id, row);
    }

    return Array.from(merged.values())
      .map((row) => ({
        row,
        distance: distanceMeters(lat, lng, row.lat, row.lng),
      }))
      .sort((a, b) => a.distance - b.distance)
      .slice(0, 30)
      .map(({ row }) => rowToRestaurant(row));
  }

  const cached = await searchCachedByName(q);
  return cached.map(rowToRestaurant);
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
