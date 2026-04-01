import { z } from 'zod';

export const restaurantSchema = z.object({
  id: z.string(),
  foursquareId: z.string(),
  name: z.string(),
  lat: z.number(),
  lng: z.number(),
  cuisine: z.string().nullable(),
});

export type Restaurant = z.infer<typeof restaurantSchema>;
