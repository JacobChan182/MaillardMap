import { z } from 'zod';

export const userPublicSchema = z.object({
  id: z.string(),
  username: z.string(),
  displayName: z.string().nullable(),
  avatarUrl: z.string().nullable(),
  bio: z.string().nullable().optional(),
  createdAt: z.string(),
  profilePrivate: z.boolean().optional(),
});

export type UserPublic = z.infer<typeof userPublicSchema>;

const optionalNullableString = z
  .union([z.string(), z.null()])
  .optional();

export const patchMeSchema = z.preprocess(
  (raw) => {
    if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) return raw;
    const o = raw as Record<string, unknown>;
    return {
      displayName: o.displayName ?? o.display_name,
      avatarUrl: o.avatarUrl ?? o.avatar_url,
      bio: o.bio,
      profilePrivate: o.profilePrivate ?? o.profile_private,
    };
  },
  z.object({
    displayName: optionalNullableString,
    avatarUrl: optionalNullableString,
    bio: optionalNullableString,
    profilePrivate: z.boolean().optional(),
  }),
);

export type PatchMeInput = z.infer<typeof patchMeSchema>;
