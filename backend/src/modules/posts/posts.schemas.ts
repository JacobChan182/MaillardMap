import { z } from 'zod';

export const postPhotoSchema = z.object({
  id: z.string(),
  postId: z.string(),
  url: z.string(),
  orderIndex: z.number().min(1).max(3),
});

export type PostPhoto = z.infer<typeof postPhotoSchema>;

/** Accepts camelCase (API docs) or snake_case (iOS). */
export const createPostSchema = z.preprocess(
  (raw) => {
    if (raw == null || typeof raw !== 'object') return raw;
    const o = raw as Record<string, unknown>;
    const foursquareId = o.foursquareId ?? o.foursquare_id;
    let photos = o.photos;
    if (photos == null && Array.isArray(o.photo_urls)) {
      photos = (o.photo_urls as string[]).map((url) => ({ url }));
    }
    const rawRating = o.rating;
    const rating =
      typeof rawRating === 'string'
        ? Number(rawRating)
        : typeof rawRating === 'number'
          ? rawRating
          : undefined;
    return { foursquareId, comment: o.comment, photos, rating };
  },
  z.object({
    foursquareId: z.string(),
    comment: z.string().max(200).optional(),
    photos: z
      .array(
        z.object({
          url: z.string().url(),
        }),
      )
      .max(3)
      .optional(),
    rating: z
      .number()
      .min(0.5, 'Rating must be at least 0.5 stars')
      .max(5, 'Rating must be at most 5 stars')
      .refine((n) => Math.abs(n * 2 - Math.round(n * 2)) < 1e-6, {
        message: 'Rating must be in half-star steps (0.5, 1, …, 5)',
      }),
  }),
);

export type CreatePostInput = z.infer<typeof createPostSchema>;

export const postSchema = z.object({
  id: z.string(),
  userId: z.string(),
  username: z.string(),
  displayName: z.string().nullable().optional(),
  avatarUrl: z.string().nullable().optional(),
  restaurantId: z.string(),
  restaurantName: z.string(),
  restaurantAddress: z.string().nullable().optional(),
  lat: z.number(),
  lng: z.number(),
  comment: z.string().nullable(),
  photos: z.array(postPhotoSchema),
  liked: z.boolean(),
  likeCount: z.number(),
  commentCount: z.number(),
  createdAt: z.string(),
  rating: z.number().nullable().optional(),
});

export type Post = z.infer<typeof postSchema>;
