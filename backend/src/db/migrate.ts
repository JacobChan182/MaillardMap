import 'dotenv/config';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { DatabaseError } from 'pg';
import { getPool } from './pool.js';

function isDbAuthFailure(err: unknown): err is DatabaseError {
  return typeof err === 'object' && err !== null && 'code' in err && (err as DatabaseError).code === '28P01';
}

function isDnsNotFound(err: unknown): err is NodeJS.ErrnoException {
  return typeof err === 'object' && err !== null && 'code' in err && (err as NodeJS.ErrnoException).code === 'ENOTFOUND';
}

function printDnsHelp(err: NodeJS.ErrnoException): void {
  const hostname = 'hostname' in err && err.hostname != null ? String(err.hostname) : 'database host';
  const isDirectDbHost = hostname.includes('.supabase.co') && hostname.startsWith('db.');
  console.error(`
Could not resolve ${hostname} (DNS lookup failed).

${isDirectDbHost ? `The Supabase "direct" host (db.<ref>.supabase.co) is often IPv6-only. If your Mac or network does not resolve IPv6, use the Session pooler string instead:
  Dashboard → Connect → Session mode (host like *.pooler.supabase.com, username often postgres.<project-ref>).

` : ''}- Re-copy from Supabase Connect: use Session pooler for IPv4, or Direct if your network supports IPv6.
- Fix typos in the project ref; resume the project if it was paused.
- Or try another network / disable VPN if DNS is filtered.
`.trim());
}

function printDbAuthHelp(): void {
  const url = process.env.DATABASE_URL ?? '';
  let hintedUser = '';
  try {
    const u = new URL(url.replace(/^postgresql:/i, 'http:'));
    if (u.username) hintedUser = ` (connecting as "${decodeURIComponent(u.username)}")`;
  } catch {
    /* ignore */
  }
  console.error(`
Postgres authentication failed${hintedUser}.

DATABASE_URL must match the running database user and password.

If you use repo docker-compose defaults, set:
  DATABASE_URL=postgresql://maillardmap:change-me@localhost:5432/maillardmap

If you changed POSTGRES_USER / POSTGRES_PASSWORD after Postgres was first created,
the old users are still in the data volume. Reset local dev data (drops DB):
  cd .. && docker compose down -v && docker compose up -d
Then run migrations again.

See backend/README.md ("Postgres: password authentication failed").
`.trim());
}

type Migration = { id: string; filename: string; sql: string };

function migrationsDir() {
  const here = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(here, '../../migrations');
}

async function loadMigrations(): Promise<Migration[]> {
  const dir = migrationsDir();
  const files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
  const migrations: Migration[] = [];

  for (const filename of files) {
    const sql = await readFile(path.join(dir, filename), 'utf8');
    migrations.push({ id: filename, filename, sql });
  }
  return migrations;
}

async function ensureSchemaMigrations(pool: ReturnType<typeof getPool>) {
  await pool.query(`
    create table if not exists schema_migrations (
      id text primary key,
      applied_at timestamptz not null default now()
    );
  `);
}

async function appliedSet(pool: ReturnType<typeof getPool>) {
  const res = await pool.query<{ id: string }>('select id from schema_migrations');
  return new Set(res.rows.map((r: { id: string }) => r.id));
}

async function applyMigration(pool: ReturnType<typeof getPool>, m: Migration) {
  await pool.query('begin');
  try {
    await pool.query(m.sql);
    await pool.query('insert into schema_migrations (id) values ($1) on conflict (id) do nothing', [m.id]);
    await pool.query('commit');
  } catch (e) {
    await pool.query('rollback');
    throw e;
  }
}

async function main() {
  const pool = getPool();
  await ensureSchemaMigrations(pool);

  const migrations = await loadMigrations();
  const applied = await appliedSet(pool);

  const pending = migrations.filter((m) => !applied.has(m.id));

  if (pending.length === 0) {
    console.log('No pending migrations.');
    return;
  }

  console.log(`Applying ${pending.length} migration(s)...`);
  for (const m of pending) {
    console.log(`- ${m.filename}`);
    await applyMigration(pool, m);
  }

  console.log('Migrations complete.');
  await pool.end();
}

main().catch((err) => {
  if (isDbAuthFailure(err)) {
    printDbAuthHelp();
  } else if (isDnsNotFound(err)) {
    printDnsHelp(err);
  } else {
    console.error(err);
  }
  process.exit(1);
});

