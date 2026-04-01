export type FoursquareVenue = {
  foursquare_id: string;
  name: string;
  lat: number;
  lng: number;
  categories: string;
};

function fsqHeaders(key: string): Record<string, string> {
  const auth = key.startsWith('Bearer ') ? key : `Bearer ${key}`;
  return { Authorization: auth, Accept: 'application/json', 'X-Places-Api-Version': '2025-06-17' };
}

/**
 * Search places near coordinates via Foursquare Places API.
 */
export async function searchNearby(lat: number, lng: number, radius = 5000, query?: string): Promise<FoursquareVenue[]> {
  const key = process.env.FOURSQUARE_API_KEY;
  if (!key) {
    console.error('[FOURSQUARE] API key not configured — search will return empty results');
    return [];
  }

  // Category "13065" = Restaurants (Foursquare Places API)
  const url = `https://places-api.foursquare.com/places/search?ll=${lat},${lng}&radius=${radius}&categories=13065&limit=30&sort=DISTANCE${query ? `&query=${encodeURIComponent(query)}` : ''}`;
  let res;
  try {
    res = await fetch(url, { headers: fsqHeaders(key) });
  } catch (e: any) {
    console.error('[FOURSQUARE] fetch error:', e.message);
    return [];
  }
  if (!res.ok) return [];

  const data = await res.json();
  return (data.results || []).map(mapVenue);
}

function mapVenue(r: any): FoursquareVenue {
  return {
    foursquare_id: r.fsq_place_id ?? r.fsq_id,
    name: r.name,
    lat: r.latitude ?? r.geocodes?.main?.latitude ?? 0,
    lng: r.longitude ?? r.geocodes?.main?.longitude ?? 0,
    categories: r.categories?.map((c: any) => c.name).join(',') || '',
  };
}

/**
 * Get place details by Foursquare venue ID.
 */
export async function getPlaceDetails(foursquareId: string): Promise<FoursquareVenue | null> {
  const key = process.env.FOURSQUARE_API_KEY;
  if (!key) return null;

  const url = `https://places-api.foursquare.com/places/${foursquareId}`;
  try {
    const res = await fetch(url, { headers: fsqHeaders(key) });
    if (!res.ok) return null;
    return mapVenue(await res.json());
  } catch {
    return null;
  }
}
