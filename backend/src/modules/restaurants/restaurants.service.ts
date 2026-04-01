import { getPool } from '../../db/pool.js';

type RestaurantRow = {
  id: string;
  foursquare_id: string;
  name: string;
  lat: number;
  lng: number;
  cuisine: string | null;
};

/**
 * Search restaurants from Foursquare, caching results locally.
 */
export async function searchRestaurants(q: string) {
  const pool = getPool();

  // First check local DB for cached results
  const cached = await pool.query<RestaurantRow>(
    `select id, foursquare_id, name, lat, lng, cuisine
     from restaurants
     where name ilike $1
     limit 30`,
    [`%${q}%`],
  );

  if (cached.rows.length > 0) {
    return cached.rows.map(rowToRestaurant);
  }

  // Not found locally - fetch from Foursquare
  // Note: In production you'd call Foursquare API here.
  // For now, return local search results (empty if none cached)
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
}): Promise<string> {
  const pool = getPool();
  const result = await pool.query(
    `insert into restaurants (foursquare_id, name, lat, lng, cuisine)
     values ($1, $2, $3, $4, $5)
     on conflict (foursquare_id) do update set updated_at = now()
     returning id`,
    [data.foursquareId, data.name, data.lat, data.lng, data.cuisine ?? null],
  );
  return result.rows[0].id;
}

/**
 * Get a restaurant by internal ID.
 */
export async function getRestaurantById(id: string) {
  const pool = getPool();
  const res = await pool.query<RestaurantRow>(
    'select id, foursquare_id, name, lat, lng, cuisine from restaurants where id = $1',
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
    'select id, foursquare_id, name, lat, lng, cuisine from restaurants where foursquare_id = $1',
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
  };
}
