import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';

const PRESIGN_EXPIRES_IN = 600; // 10 minutes

const MIME_TO_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
};

export const ALLOWED_CONTENT_TYPES = Object.keys(MIME_TO_EXT);

let client: S3Client | null = null;

function getClient(): S3Client {
  if (client) return client;

  const endpoint = process.env.S3_ENDPOINT;
  const accessKeyId = process.env.S3_ACCESS_KEY_ID;
  const secretAccessKey = process.env.S3_SECRET_ACCESS_KEY;

  if (!endpoint || !accessKeyId || !secretAccessKey) {
    throw new Error('S3_ENDPOINT, S3_ACCESS_KEY_ID, and S3_SECRET_ACCESS_KEY are required');
  }

  client = new S3Client({
    region: 'auto',
    endpoint,
    credentials: { accessKeyId, secretAccessKey },
  });

  return client;
}

function getBucket(): string {
  const bucket = process.env.S3_BUCKET;
  if (!bucket) throw new Error('S3_BUCKET is required');
  return bucket;
}

function getPublicUrl(): string {
  const url = process.env.S3_PUBLIC_URL;
  if (!url) throw new Error('S3_PUBLIC_URL is required');
  return url.replace(/\/$/, '');
}

/** Rewrite URLs saved with an old S3_PUBLIC_URL (e.g. https://placeholder) to the current S3_PUBLIC_URL so phones can load them on LAN. */
export function rewritePublicMediaUrl(url: string | null): string | null {
  if (url == null || url.length === 0) return url;
  const legacy = process.env.S3_PUBLIC_URL_LEGACY?.trim().replace(/\/$/, '');
  if (!legacy) return url;
  const current = process.env.S3_PUBLIC_URL?.trim().replace(/\/$/, '');
  if (!current || legacy === current) return url;
  if (url === legacy || url.startsWith(`${legacy}/`)) {
    return current + url.slice(legacy.length);
  }
  return url;
}

export async function generatePresignedUpload(contentType: string) {
  const ext = MIME_TO_EXT[contentType];
  if (!ext) throw new Error(`Unsupported content type: ${contentType}`);

  const key = `posts/${randomUUID()}.${ext}`;
  const bucket = getBucket();

  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(getClient(), command, {
    expiresIn: PRESIGN_EXPIRES_IN,
  });

  const publicUrl = `${getPublicUrl()}/${key}`;

  return { uploadUrl, publicUrl };
}

/** Profile photo; scoped under `avatars/{userId}/` to reduce abuse. */
export async function generateAvatarPresignedUpload(userId: string, contentType: string) {
  const ext = MIME_TO_EXT[contentType];
  if (!ext) throw new Error(`Unsupported content type: ${contentType}`);

  const key = `avatars/${userId}/${randomUUID()}.${ext}`;
  const bucket = getBucket();

  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(getClient(), command, {
    expiresIn: PRESIGN_EXPIRES_IN,
  });

  const publicUrl = `${getPublicUrl()}/${key}`;

  return { uploadUrl, publicUrl };
}
