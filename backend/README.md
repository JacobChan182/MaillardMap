# Backend API (`backend/`)

Owned by the `backend` agent.

## Quick start

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

### Health check

- `GET http://localhost:3000/health`

## Production (Docker)

- **`Dockerfile`** in this folder — build: `docker build -t maillardmap-api -f Dockerfile .` from `backend/`, or from repo root: `docker build -t maillardmap-api -f backend/Dockerfile backend`.
- **`.env.docker.example`** — copy to `.env.docker`, fill in values, then `docker run ... --env-file .env.docker maillardmap-api`.
- Deploy guides: [Docker + hosting platforms](../docs/deploy-api-docker.md), [Postgres / Supabase](../docs/deploy-supabase.md).

## Useful scripts

From `backend/`:

- `npm run dev`
- `npm run lint`
- `npm run typecheck`
- `npm test`
- `npm run build`

From repo root:

- `/backend-install`
- `/dev-backend`
- `/e2e-smoke`

## Environment

Copy `.env.example` to `.env` and set values.

- `PORT`: default `3000`
- `DATABASE_URL`: user, password, host, port, and database name must match Postgres (see repo root `docker-compose.yml`). Defaults there are user `maillardmap`, password `change-me`, DB `maillardmap`.
- `JWT_SECRET`: at least 32 characters
- **`RESEND_API_KEY`**: optional in dev; if unset, signup confirmation emails are skipped (log warning). Set for real email delivery.
- **`RESEND_FROM`**: required when `RESEND_API_KEY` is set — verified sender **email** (e.g. `onboarding@yourdomain.com`) or legacy `Name <email>`; the **inbox display name** is **`RESEND_FROM_NAME`** (defaults to `MaillardMap`), not the old `Name` part of `RESEND_FROM`.
- **`PUBLIC_API_BASE_URL`** (or `API_PUBLIC_URL`): public base URL of this API **with no trailing slash**; used in email confirmation links (`/auth/verify-email?token=...`). Defaults to `http://localhost:3000` if unset.
- `FOURSQUARE_API_KEY`: restaurant search
- `S3_*`: see `.env.example` for presigned uploads

If you have Docker Desktop installed:

- `/db-up`
- `/db-down`

### Postgres: `password authentication failed` after renaming users

Postgres only applies `POSTGRES_USER` / `POSTGRES_PASSWORD` when the data directory is **first** created. If the container volume was initialized with an older username (e.g. `bigback`), changing `docker-compose.yml` to `maillardmap` does not migrate accounts — your `.env` `DATABASE_URL` must still use the **existing** superuser, or you reset dev data:

```bash
# from repo root — deletes the named volume and all local DB data
docker compose down -v
docker compose up -d
```

Then set `DATABASE_URL` to match the compose defaults (see `.env.example`), run migrations, and try again.

