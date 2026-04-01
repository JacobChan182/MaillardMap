import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { ALLOWED_CONTENT_TYPES, generatePresignedUpload } from '../../services/s3.js';

const presignSchema = z.preprocess(
  (raw) => {
    if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) return raw;
    const o = raw as Record<string, unknown>;
    return {
      contentType: o.contentType ?? o.content_type,
      count: o.count,
    };
  },
  z.object({
    contentType: z.enum(ALLOWED_CONTENT_TYPES as [string, ...string[]]),
    count: z.number().int().min(1).max(3),
  }),
);

export const uploadsRouter = Router();

uploadsRouter.post('/presign', requireAuth, async (req, res) => {
  const parsed = presignSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: parsed.error.issues[0].message },
    });
  }

  const { contentType, count } = parsed.data;

  const uploads = await Promise.all(
    Array.from({ length: count }, () => generatePresignedUpload(contentType)),
  );

  return res.json({ uploads });
});
