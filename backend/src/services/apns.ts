import http2 from 'node:http2';
import jwt from 'jsonwebtoken';
import { deleteApnsToken, getApnsTokensForUser } from '../modules/devices/devices.service.js';
import type { ApnsEnvironment } from '../modules/devices/devices.schemas.js';

type ApnsPayload = {
  title: string;
  body: string;
  data?: Record<string, string | null | undefined>;
  badge?: number;
};

type ApnsConfig = {
  keyId: string;
  teamId: string;
  bundleId: string;
  privateKey: string;
};

let cachedToken: { value: string; issuedAtSeconds: number } | null = null;
let hasWarnedMissingConfig = false;

function apnsConfig(): ApnsConfig | null {
  const keyId = process.env.APNS_KEY_ID?.trim();
  const teamId = process.env.APNS_TEAM_ID?.trim();
  const bundleId = (process.env.APNS_BUNDLE_ID ?? 'com.maillardmap.app').trim();
  const rawKey = process.env.APNS_PRIVATE_KEY?.trim();
  const base64Key = process.env.APNS_PRIVATE_KEY_BASE64?.trim();
  const privateKey = rawKey
    ? rawKey.replace(/\\n/g, '\n')
    : base64Key
      ? Buffer.from(base64Key, 'base64').toString('utf8')
      : '';

  if (!keyId || !teamId || !bundleId || !privateKey) {
    if (!hasWarnedMissingConfig) {
      hasWarnedMissingConfig = true;
      console.warn('[apns] disabled: missing configuration', {
        hasKeyId: Boolean(keyId),
        hasTeamId: Boolean(teamId),
        hasBundleId: Boolean(bundleId),
        hasPrivateKey: Boolean(privateKey),
      });
    }
    return null;
  }
  return { keyId, teamId, bundleId, privateKey };
}

function providerToken(config: ApnsConfig): string {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && now - cachedToken.issuedAtSeconds < 45 * 60) {
    return cachedToken.value;
  }
  const value = jwt.sign(
    { iss: config.teamId, iat: now },
    config.privateKey,
    {
      algorithm: 'ES256',
      header: { alg: 'ES256', kid: config.keyId },
    },
  );
  cachedToken = { value, issuedAtSeconds: now };
  return value;
}

function apnsHost(environment: ApnsEnvironment): string {
  return environment === 'production' ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com';
}

async function sendToDevice(token: string, environment: ApnsEnvironment, payload: ApnsPayload, config: ApnsConfig): Promise<void> {
  const body = JSON.stringify({
    aps: {
      alert: { title: payload.title, body: payload.body },
      sound: 'default',
      ...(payload.badge != null ? { badge: payload.badge } : {}),
    },
    ...(payload.data ?? {}),
  });

  await new Promise<void>((resolve) => {
    const client = http2.connect(apnsHost(environment));
    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${token}`,
      authorization: `bearer ${providerToken(config)}`,
      'apns-topic': config.bundleId,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    });

    let status = 0;
    let response = '';
    req.setEncoding('utf8');
    req.on('response', (headers) => {
      status = Number(headers[':status'] ?? 0);
    });
    req.on('data', (chunk) => {
      response += chunk;
    });
    req.on('end', () => {
      client.close();
      if (status >= 200 && status < 300) {
        resolve();
        return;
      }
      const reason = (() => {
        try {
          return JSON.parse(response).reason as string | undefined;
        } catch {
          return undefined;
        }
      })();
      if (reason === 'BadDeviceToken' || reason === 'Unregistered' || reason === 'DeviceTokenNotForTopic') {
        void deleteApnsToken(token);
      }
      console.warn('[apns] send failed', { status, reason, tokenPrefix: token.slice(0, 8) });
      resolve();
    });
    req.on('error', (err) => {
      client.close();
      console.warn('[apns] request error', err);
      resolve();
    });
    req.end(body);
  });
}

export async function sendPushToUser(userId: string, payload: ApnsPayload): Promise<void> {
  const config = apnsConfig();
  if (!config) return;

  try {
    const devices = await getApnsTokensForUser(userId);
    if (devices.length === 0) {
      console.info('[apns] no registered devices for user', { userId });
      return;
    }
    console.info('[apns] sending push', {
      userId,
      title: payload.title,
      deviceCount: devices.length,
    });
    await Promise.all(devices.map((d) => sendToDevice(d.deviceToken, d.environment, payload, config)));
  } catch (err) {
    console.warn('[apns] push fanout failed', err);
  }
}

export function truncatePushText(s: string, max = 120): string {
  const t = s.trim();
  return t.length <= max ? t : `${t.slice(0, max - 3)}...`;
}
