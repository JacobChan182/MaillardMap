# Deploy the API with Docker

The HTTP API lives in `backend/`. The image is built from **`backend/Dockerfile`** (Node 22 Alpine, `npm run build`, `node dist/index.js`).

## Before first deploy

1. **Database** reachable from the internet (e.g. [Supabase Postgres](./deploy-supabase.md)) with **`DATABASE_URL`** (Session pooler recommended for IPv4).
2. **Run migrations** against that database (from your laptop or CI):

   ```bash
   cd backend
   export DATABASE_URL='postgresql://...'
   npm ci && npm run db:migrate
   ```

   Or after a local Docker build: `npm run build && npm run db:migrate:prod`.

3. **Secrets** ready: `JWT_SECRET` (≥32 chars), `RESEND_*`, `S3_*`, `FOURSQUARE_API_KEY`, `PUBLIC_API_BASE_URL` (HTTPS URL of **this** API for email links).

## No custom domain yet?

You still get a **public HTTPS URL** from the host:

- **Railway:** `https://<service>.up.railway.app` (shown after first deploy).
- **Render:** `https://<name>.onrender.com`.

Use **that** as `PUBLIC_API_BASE_URL` (no trailing slash), e.g. `https://maillardmap-api-production.up.railway.app`. After the first deploy, add or update the variable and **redeploy / restart** so confirmation emails point at the live API. You can add a custom domain later and only then change `PUBLIC_API_BASE_URL`.

For **local Docker only**, you can set `PUBLIC_API_BASE_URL=http://localhost:3000` to smoke-test; links in email will not work from another device until the API is on the internet.

## Build and run locally

From **repo root**:

```bash
docker build -t maillardmap-api -f backend/Dockerfile backend
docker run --rm -p 3000:3000 \
  -e PORT=3000 \
  -e DATABASE_URL='postgresql://...' \
  -e JWT_SECRET='...' \
  -e PUBLIC_API_BASE_URL='http://localhost:3000' \
  maillardmap-api
```

Use **`backend/.env.docker.example`** as a template: copy to `backend/.env.docker`, fill in secrets, then:

`docker run --rm -p 3001:3000 --env-file backend/.env.docker maillardmap-api`

Omit or leave empty `RESEND_API_KEY` if you only need `/health` checks.

Health check: `GET http://localhost:3000/health`

The process uses **`process.env.PORT`** (`3000` default); hosted platforms usually set `PORT` themselves — **do not** hardcode the port in the image.

## Hosted platforms (Docker)

Use the same image everywhere: **Dockerfile path** = `backend/Dockerfile`, **context** = `backend/` (or repo root with `-f backend/Dockerfile` and context `backend`).

| Platform | Typical setup |
|----------|----------------|
| **[Railway](https://railway.app)** | New Project → Deploy from GitHub → set **Root Directory** / **Dockerfile** to `backend` or use `Dockerfile` at `backend/Dockerfile`. Add env vars. Optional **Release** command: `node dist/db/migrate.js` (image must have `dist` + `migrations`; use the same env as the service). |
| **[Render](https://render.com)** | **Web Service** → **Docker**. Set Dockerfile path, env vars. **Pre-deploy** or one-off shell: run migrations with `DATABASE_URL`. |
| **[Fly.io](https://fly.io)** | `fly launch` in `backend/` or map `Dockerfile`; set secrets with `fly secrets set`. Run migrate via `fly ssh console` or CI once. |
| **[Google Cloud Run](https://cloud.google.com/run)** | Build & deploy: `gcloud run deploy --source backend` or push image to AR, set `--set-env-vars`, **min instances** ≥1 if you want fewer cold starts. Cloud Run sets **`PORT`** automatically. |
| **AWS ECS / Fargate** | Task definition: same image, secrets from SSM/Secrets Manager, target group health check on `/health`. |

### Migrations in production

- **One-off before** first traffic: run `npm run db:migrate` locally or a job with prod `DATABASE_URL`.
- **Or** add a release step that runs `node dist/db/migrate.js` (entrypoint already compiled in the image). Fail the release if migrate fails so you never start an old schema.

### Health checks

Point load balancers at **`GET /health`** (200 JSON).

## Monorepo layout (step 4)

Git root is the **repo** folder that contains `backend/`, `ios/`, etc. On the host:

- **Dockerfile path:** `backend/Dockerfile` (or relative equivalent).
- **Docker context / root directory:** **`backend`** — the directory that contains `Dockerfile`, `package.json`, `src/`, and `migrations/`.

Wrong context (e.g. repo root without pointing at `backend`) breaks the build because the `COPY` paths expect files inside `backend/`.

## Security notes (step 5)

- **Never** commit `.env` with production secrets.
- **JWT_SECRET:** new random value for production.
- **`PUBLIC_API_BASE_URL`:** the public **API** base (e.g. `https://api.yourdomain.com`), not the Supabase URL.

## Related

- [Supabase / Postgres](./deploy-supabase.md) — database URL, IPv6 vs pooler, migrate from CLI.
