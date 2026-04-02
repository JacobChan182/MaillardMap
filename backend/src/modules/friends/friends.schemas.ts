import { z } from 'zod';

/** Clients send `friend_id`; API also accepts `friendId`. */
export const friendIdBodySchema = z
  .object({
    friendId: z.string().uuid().optional(),
    friend_id: z.string().uuid().optional(),
  })
  .refine((o) => o.friendId != null || o.friend_id != null, { message: 'friendId or friend_id required' })
  .transform((o) => ({ friendId: (o.friendId ?? o.friend_id)! }));

export const friendRequestSchema = friendIdBodySchema;

export type FriendRequestInput = z.infer<typeof friendRequestSchema>;

export const friendshipSchema = z.object({
  id: z.string(),
  friendId: z.string(),
  friendUsername: z.string(),
  friendDisplayName: z.string().nullable().optional(),
  friendAvatarUrl: z.string().nullable().optional(),
  status: z.enum(['pending', 'accepted']),
  createdAt: z.string(),
  /** `true` = they requested you; `false` = you requested them; `null` when `status` is `accepted`. */
  incomingPending: z.boolean().nullable().optional(),
});

export type Friendship = z.infer<typeof friendshipSchema>;
