import { z } from 'zod';

export const signupSchema = z.object({
  username: z.string().min(3).max(32),
  phoneOrEmail: z.string().min(3).max(200).optional(),
  password: z.string().min(8).max(200),
});

export const loginSchema = z.object({
  username: z.string().min(3).max(200),
  password: z.string().min(8).max(200),
});

export type SignupInput = z.infer<typeof signupSchema>;
export type LoginInput = z.infer<typeof loginSchema>;

