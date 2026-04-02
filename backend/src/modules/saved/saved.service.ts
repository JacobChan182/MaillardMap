import { getPool } from '../../db/pool.js';

type SavedPlaceRow = {
  id: string;
  restaurant_id: string;
  foursquare_id: string | null;
  restaurant_name: string;
  saved_at: Date | string;
};

async function selectSavedPlaceRow(userId: string, restaurantId: string): Promise<SavedPlaceRow | null> {
  const pool = getPool();
  const res = await pool.query<SavedPlaceRow>(
    `select sp.id, sp.restaurant_id, r.foursquare_id, r.name as restaurant_name, sp.created_at as saved_at
     from saved_places sp
     join restaurants r on r.id = sp.restaurant_id
     where sp.user_id = $1 and sp.restaurant_id = $2`,
    [userId, restaurantId],
  );
  return res.rows[0] ?? null;
}

export async function savePlace(userId: string, restaurantId: string) {
  const pool = getPool();

  const r = await pool.query('select id from restaurants where id = $1', [restaurantId]);
  if (r.rows.length === 0) {
    return { ok: false, status: 404, code: 'RESTAURANT_NOT_FOUND' } as const;
  }

  try {
    await pool.query('insert into saved_places (user_id, restaurant_id) values ($1, $2)', [
      userId,
      restaurantId,
    ]);
  } catch (e) {
    const err = e as { code?: string };
    if (err.code !== '23505') throw e;
  }

  const savedPlace = await selectSavedPlaceRow(userId, restaurantId);
  if (!savedPlace) {
    throw new Error('Saved place missing after insert');
  }
  return { ok: true, saved_place: savedPlace } as const;
}

export async function getSavedPlaces(userId: string) {
  const pool = getPool();
  const res = await pool.query(
    `select sp.id, sp.restaurant_id, r.foursquare_id, r.name as restaurant_name, sp.created_at as saved_at
     from saved_places sp
     join restaurants r on r.id = sp.restaurant_id
     where sp.user_id = $1
     order by sp.created_at desc`,
    [userId],
  );
  return { saved_places: res.rows } as const;
}

export async function removeSavedPlace(userId: string, restaurantId: string) {
  const pool = getPool();
  await pool.query(
    'delete from saved_places where user_id = $1 and restaurant_id = $2',
    [userId, restaurantId],
  );
  return { ok: true } as const;
}
