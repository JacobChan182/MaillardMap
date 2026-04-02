import { z } from 'zod';

export const friendRequestSchema = z.object({
  friendId: z.string().uuid(),
});

export type FriendRequestInput = z.infer<typeof friendRequestSchema>;

export const friendshipSchema = z.object({
  id: z.string(),
  friendId: z.string(),
  friendUsername: z.string(),
  friendDisplayName: z.string().nullable().optional(),
  friendAvatarUrl: z.string().nullable().optional(),
  status: z.enum(['pending', 'accepted']),
  createdAt: z.string(),
});

export type Friendship = z.infer<typeof friendshipSchema>;
