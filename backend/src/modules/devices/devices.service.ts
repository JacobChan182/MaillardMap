import type { Pool } from 'pg';
import { getPool } from '../../db/pool.js';
import type { ApnsEnvironment, RegisterApnsTokenInput } from './devices.schemas.js';

export type ApnsDeviceToken = {
  userId: string;
  deviceToken: string;
  environment: ApnsEnvironment;
};

export async function ensureApnsDeviceTokensTable(pool: Pool = getPool()): Promise<void> {
  await pool.query(`
    create table if not exists apns_device_tokens (
      user_id uuid not null references users(id) on delete cascade,
      device_token text primary key,
      platform text not null default 'ios',
      environment text not null check (environment in ('sandbox', 'production')),
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now(),
      last_seen_at timestamptz not null default now()
    )
  `);
  await pool.query('create index if not exists idx_apns_device_tokens_user_id on apns_device_tokens(user_id)');
}

export async function registerApnsToken(userId: string, input: RegisterApnsTokenInput): Promise<void> {
  const pool = getPool();
  await ensureApnsDeviceTokensTable(pool);
  await pool.query(
    `insert into apns_device_tokens (user_id, device_token, environment)
     values ($1, $2, $3)
     on conflict (device_token) do update set
       user_id = excluded.user_id,
       environment = excluded.environment,
       updated_at = now(),
       last_seen_at = now()`,
    [userId, input.token, input.environment],
  );
}

export async function unregisterApnsToken(userId: string, token: string): Promise<void> {
  const pool = getPool();
  await ensureApnsDeviceTokensTable(pool);
  await pool.query('delete from apns_device_tokens where user_id = $1 and device_token = $2', [userId, token]);
}

export async function getApnsTokensForUser(userId: string): Promise<ApnsDeviceToken[]> {
  const pool = getPool();
  await ensureApnsDeviceTokensTable(pool);
  const res = await pool.query<{ user_id: string; device_token: string; environment: ApnsEnvironment }>(
    `select user_id, device_token, environment
     from apns_device_tokens
     where user_id = $1`,
    [userId],
  );
  return res.rows.map((r) => ({
    userId: r.user_id,
    deviceToken: r.device_token,
    environment: r.environment,
  }));
}

export async function deleteApnsToken(token: string): Promise<void> {
  const pool = getPool();
  await ensureApnsDeviceTokensTable(pool);
  await pool.query('delete from apns_device_tokens where device_token = $1', [token]);
}
