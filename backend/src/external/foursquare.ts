export type FoursquareVenue = {
  foursquare_id: string;
  name: string;
  lat: number;
  lng: number;
  categories: string;
};

/**
 * Search places near coordinates via Foursquare Places API.
 */
export async function searchNearby(lat: number, lng: number, radius = 5000, query?: string): Promise<FoursquareVenue[]> {
  const key = process.env.FOURSQUARE_API_KEY;
  if (!key) return [];

  // Category "13063" = Restaurants
  const url = `https://api.foursquare.com/v3/places/search?ll=${lat},${lng}&radius=${radius}&categories=13063&limit=30&sort=DISTANCE${query ? `&query=${encodeURIComponent(query)}` : ''}`;
  const res = await fetch(url, {
    headers: { Authorization: key, Accept: 'application/json' },
  });
  if (!res.ok) return [];

  const data = await res.json();
  return (data.results || []).map((r: any) => ({
    foursquare_id: r.fsq_id,
    name: r.name,
    lat: r.geocodes?.main?.latitude ?? 0,
    lng: r.geocodes?.main?.longitude ?? 0,
    categories: r.categories?.map((c: any) => c.name).join(',') || '',
  }));
}

/**
 * Get place details by Foursquare venue ID.
 */
export async function getPlaceDetails(foursquareId: string): Promise<FoursquareVenue | null> {
  const key = process.env.FOURSQUARE_API_KEY;
  if (!key) return null;

  const url = `https://api.foursquare.com/v3/places/${foursquareId}`;
  const res = await fetch(url, {
    headers: { Authorization: key, Accept: 'application/json' },
  });
  if (!res.ok) return null;

  const data = await res.json();
  return {
    foursquare_id: data.fsq_id,
    name: data.name,
    lat: data.geocodes?.main?.latitude ?? 0,
    lng: data.geocodes?.main?.longitude ?? 0,
    categories: data.categories?.map((c: any) => c.name).join(',') || '',
  };
}
