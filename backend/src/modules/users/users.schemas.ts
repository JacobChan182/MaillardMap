import { z } from 'zod';

export const userPublicSchema = z.object({
  id: z.string(),
  username: z.string(),
});

export type UserPublic = z.infer<typeof userPublicSchema>;
