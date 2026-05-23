export type VenueCategory = { id: string; name: string };

/** Legacy Foursquare "Dining and Drinking" category IDs (13000–13999). */
const LEGACY_DINING_ID_MIN = 13000;
const LEGACY_DINING_ID_MAX = 13999;

const DINING_NAME =
  /\b(restaurants?|caf[eé]|coffee|bar|pub|brewery|winery|bistro|diner|pizzeria|pizza|food|eatery|grill|kitchen|deli|steakhouse|seafood|ramen|sushi|taco|barbecue|bbq|dessert|donut|doughnut|ice cream|tea room|bubble tea|creperie|waffle|gastropub|brunch|buffet|cantina|taqueria|noodle|sandwich|juice bar|smoothie|bagel|dim sum|hot pot|food truck|food court|dining|bakery|bagel shop|dessert shop|nightclub)\b/i;

const NON_DINING_NAME =
  /\b(hotels?|motels?|hostels?|resorts?|airports?|train stations?|bus stations?|offices?|corporate|hospitals?|medical|schools?|universit(y|ies)|colleges?|gyms?|fitness|banks?|atms?|churches?|mosques?|temples?|museums?|libraries?|parks?|playgrounds?|gas stations?|fuel|supermarkets?|grocer(y|ies)|convenience stores?|pharmacies?|drugstores?|malls?|shopping centers?|retail|clothing stores?|electronics stores?|furniture stores?|hardware stores?|car dealers?|auto repair|parking|storage|apartments?|real estate|courthouses?|embassies|post offices?|cemeteries?|funeral homes?|stadiums?|arenas?|convention centers?|movie theaters?|cinemas?|theaters?|bowling|arcades?|casinos?|laundromats?|salons?|spas?|barbers?)\b/i;

function legacyDiningId(id: string): boolean {
  const n = Number.parseInt(id, 10);
  return Number.isFinite(n) && n >= LEGACY_DINING_ID_MIN && n <= LEGACY_DINING_ID_MAX;
}

export function isDiningCategory(name: string, id?: string): boolean {
  const label = name.trim();
  if (!label) return false;
  if (id && legacyDiningId(id)) return true;
  if (NON_DINING_NAME.test(label) && !DINING_NAME.test(label)) return false;
  return DINING_NAME.test(label);
}

/** True when Foursquare categories indicate a food/drink venue (not hotels, retail, etc.). */
export function isRestaurantVenue(categories: VenueCategory[]): boolean {
  if (categories.length === 0) return false;
  const dining = categories.filter((c) => isDiningCategory(c.name, c.id));
  if (dining.length === 0) return false;
  const onlyNonDining = categories.every(
    (c) => NON_DINING_NAME.test(c.name.trim()) && !isDiningCategory(c.name, c.id),
  );
  return !onlyNonDining;
}

/** Filter cached `cuisine` labels (comma-separated Foursquare category names). */
export function isRestaurantCuisineLabel(cuisine: string | null | undefined): boolean {
  if (cuisine == null || cuisine.trim() === '') return false;
  const names = cuisine.split(',').map((s) => s.trim()).filter(Boolean);
  if (names.length === 0) return false;
  const cats = names.map((name) => ({ id: '', name }));
  return isRestaurantVenue(cats);
}
