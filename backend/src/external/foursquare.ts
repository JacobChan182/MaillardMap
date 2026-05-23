import { isRestaurantVenue, type VenueCategory } from '../modules/restaurants/restaurant-venue-filter.js';

export type FoursquareVenue = {
  foursquare_id: string;
  name: string;
  lat: number;
  lng: number;
  categories: string;
  categoryList: VenueCategory[];
  address: string;
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
  return (data.results || [])
    .map(mapVenue)
    .filter((v: FoursquareVenue) => isRestaurantVenue(v.categoryList));
}

function venueAddressFromLocation(loc: any): string {
  if (!loc || typeof loc !== 'object') return '';
  const formatted = loc.formatted_address;
  if (typeof formatted === 'string' && formatted.trim()) return formatted.trim();
  const line1 = [loc.address, loc.address_extended].filter(Boolean).join(', ');
  const cityPart = [loc.locality, loc.region, loc.postcode].filter(Boolean).join(', ');
  const combined = [line1, cityPart].filter(Boolean).join(', ');
  return typeof combined === 'string' ? combined.trim() : '';
}

function mapCategoryList(r: any): VenueCategory[] {
  if (!Array.isArray(r.categories)) return [];
  return r.categories
    .map((c: any) => ({
      id: String(c?.fsq_category_id ?? c?.id ?? ''),
      name: typeof c?.name === 'string' ? c.name : '',
    }))
    .filter((c: VenueCategory) => c.name.length > 0);
}

function mapVenue(r: any): FoursquareVenue {
  const categoryList = mapCategoryList(r);
  const categories =
    categoryList.length > 0
      ? categoryList.map((c) => c.name).join(', ')
      : typeof r.categories === 'string'
        ? r.categories
        : '';
  return {
    foursquare_id: r.fsq_place_id ?? r.fsq_id,
    name: r.name,
    lat: r.latitude ?? r.geocodes?.main?.latitude ?? 0,
    lng: r.longitude ?? r.geocodes?.main?.longitude ?? 0,
    categories,
    categoryList,
    address: venueAddressFromLocation(r.location),
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
    const venue = mapVenue(await res.json());
    return isRestaurantVenue(venue.categoryList) ? venue : null;
  } catch {
    return null;
  }
}
