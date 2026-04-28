import { z } from 'zod';

export const signupSchema = z.object({
  username: z.string().min(3).max(32),
  email: z.string().trim().min(3).max(320).email(),
  password: z.string().min(8).max(200),
});

export const loginSchema = z.object({
  username: z.string().min(3).max(254),
  password: z.string().min(8).max(200),
});

/** Username or email only (same rules as login identifier). */
export const resendConfirmationSchema = z.object({
  username: z.string().min(3).max(254),
});

/** Username or email for password reset link delivery. */
export const requestPasswordResetSchema = z.object({
  username: z.string().min(3).max(254),
});

/** One-time reset token from email + new password. */
export const resetPasswordSchema = z.object({
  token: z.string().trim().min(16).max(512),
  password: z.string().min(8).max(200),
});

export type SignupInput = z.infer<typeof signupSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type ResendConfirmationInput = z.infer<typeof resendConfirmationSchema>;
export type RequestPasswordResetInput = z.infer<typeof requestPasswordResetSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
