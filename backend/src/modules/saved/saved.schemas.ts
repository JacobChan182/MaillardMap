import { z } from 'zod';

export const savedCreateSchema = z.object({
  restaurant_id: z.string().min(1),
});

export type SavedCreateInput = z.infer<typeof savedCreateSchema>;
