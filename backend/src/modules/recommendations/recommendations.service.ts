import { getPool } from '../../db/pool.js';

export type BlendResult = {
  top_cuisines: { name: string; count: number }[];
  centroid: { lat: number; lng: number };
  restaurants: {
    id: string;
    foursquare_id: string;
    name: string;
    cuisine: string | null;
    distance: number;
    score: number;
  }[];
};

export async function blendTastes(userIds: string[]): Promise<BlendResult> {
  const pool = getPool();

  // Collect all restaurants from posts, likes, and saved places for the given users
  const res = await pool.query(
    `select distinct r.id, r.foursquare_id, r.name, r.cuisine, r.lat, r.lng
     from restaurants r
     where r.id in (
       select restaurant_id from posts where user_id = any($1)
       union
       select p.restaurant_id from likes l
       join posts p on p.id = l.post_id
       where l.user_id = any($1)
       union
       select restaurant_id from saved_places where user_id = any($1)
     )`,
    [userIds],
  );

  const rows: { id: string; foursquare_id: string; name: string; cuisine: string | null; lat: number; lng: number }[] = res.rows;

  if (rows.length === 0) {
    return { top_cuisines: [], centroid: { lat: 0, lng: 0 }, restaurants: [] };
  }

  // Top cuisines by frequency
  const cuisineCount = new Map<string, number>();
  for (const r of rows) {
    if (r.cuisine) {
      for (const c of r.cuisine.split(',').map(s => s.trim())) {
        cuisineCount.set(c, (cuisineCount.get(c) || 0) + 1);
      }
    }
  }
  const topCuisines = Array.from(cuisineCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, count]) => ({ name, count }));

  // Centroid
  const avgLat = rows.reduce((sum, r) => sum + r.lat, 0) / rows.length;
  const avgLng = rows.reduce((sum, r) => sum + r.lng, 0) / rows.length;

  // Score restaurants
  const topCuisinesSet = new Set(topCuisines.map(c => c.name));
  const scored = rows.map(r => {
    const dist = Math.sqrt((r.lat - avgLat) ** 2 + (r.lng - avgLng) ** 2) * 111; // rough km
    const hasCuisine = r.cuisine
      ? r.cuisine.split(',').some(c => topCuisinesSet.has(c.trim()))
      : false;
    const cuisineScore = hasCuisine ? 1 : 0;
    const distScore = Math.max(0, 1 - dist / 10);
    const score = parseFloat((0.5 * cuisineScore + 0.5 * distScore).toFixed(2));
    return {
      id: r.id,
      foursquare_id: r.foursquare_id,
      name: r.name,
      cuisine: r.cuisine,
      distance: parseFloat(dist.toFixed(2)),
      score,
    };
  }).sort((a, b) => b.score - a.score);

  return {
    top_cuisines: topCuisines,
    centroid: { lat: parseFloat(avgLat.toFixed(4)), lng: parseFloat(avgLng.toFixed(4)) },
    restaurants: scored.slice(0, 20),
  };
}
