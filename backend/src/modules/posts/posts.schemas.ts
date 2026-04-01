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
    return { foursquareId, comment: o.comment, photos };
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
  }),
);

export type CreatePostInput = z.infer<typeof createPostSchema>;

export const postSchema = z.object({
  id: z.string(),
  userId: z.string(),
  username: z.string(),
  restaurantId: z.string(),
  restaurantName: z.string(),
  restaurantAddress: z.string().nullable().optional(),
  lat: z.number(),
  lng: z.number(),
  comment: z.string().nullable(),
  photos: z.array(postPhotoSchema),
  liked: z.boolean(),
  likeCount: z.number(),
  createdAt: z.string(),
});

export type Post = z.infer<typeof postSchema>;
