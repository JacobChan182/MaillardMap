import { z } from 'zod';

export const apnsEnvironmentSchema = z.enum(['sandbox', 'production']);

export const registerApnsTokenSchema = z.object({
  token: z.string().trim().min(32).max(512),
  environment: apnsEnvironmentSchema,
});

export type RegisterApnsTokenInput = z.infer<typeof registerApnsTokenSchema>;
export type ApnsEnvironment = z.infer<typeof apnsEnvironmentSchema>;
