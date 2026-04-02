import { z } from 'zod';

/** Accepts snake_case (API docs) or camelCase (some clients). */
export const savedCreateSchema = z.preprocess(
  (raw) => {
    if (raw == null || typeof raw !== 'object') return raw;
    const o = raw as Record<string, unknown>;
    return { restaurant_id: o.restaurant_id ?? o.restaurantId };
  },
  z.object({
    restaurant_id: z.string().uuid(),
  }),
);

export type SavedCreateInput = z.infer<typeof savedCreateSchema>;
