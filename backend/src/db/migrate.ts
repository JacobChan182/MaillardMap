import 'dotenv/config';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getPool } from './pool.js';

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
  console.error(err);
  process.exitCode = 1;
});

