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

- `PORT`: default `3000`
- `DATABASE_URL`: points at local Postgres (see repo root `docker-compose.yml`)

If you have Docker Desktop installed:

- `/db-up`
- `/db-down`

