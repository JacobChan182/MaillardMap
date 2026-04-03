# Deploy backend with Supabase (Postgres)

Supabase **does not run your Express server**. Use it for **managed Postgres**; host the Node API on **Railway**, **Render**, **Fly.io**, **Google Cloud Run**, etc. (this repo includes a `backend/Dockerfile`).

## 1. Supabase project

1. Create a project at [supabase.com](https://supabase.com).
2. Open your project and use the **Connect** button at the top (or **Project Settings → Database**). Supabase does **not** always label it “URI”; look for:
   - **Direct connection** — `postgresql://postgres:...@db.<ref>.supabase.co:5432/postgres` (good for migrations and long‑lived servers; IPv6 by default).
   - **Session pooler** (Supavisor session mode) — often still port `5432`, useful when you need **IPv4**.
   - **Transaction mode** (port `6543`) — pooler for serverless; Node `pg` may need [prepared statements disabled](https://github.com/orgs/supabase/discussions/28239) for this mode.
3. Copy the **postgres** / **postgresql** URL and replace **`[YOUR-PASSWORD]`** with the database password from **Database** settings (reset it there if needed). Append **`?sslmode=require`** if the string does not already include SSL params.

## 2. Run migrations

From `backend/` with production `DATABASE_URL`:

```bash
export DATABASE_URL='postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:5432/postgres?sslmode=require'
# Or the direct db.*.supabase.co:5432 URI from the dashboard.
npm ci
npm run db:migrate
```

Use the **direct** host (`db.<project-ref>.supabase.co:5432`) for migrations if the pooler ever rejects DDL.

## 3. Environment variables (API host)

Set on your container platform (or `.env` locally):

| Variable | Notes |
|----------|--------|
| `DATABASE_URL` | Supabase URI with `sslmode=require` |
| `JWT_SECRET` | ≥32 random characters; **do not** reuse dev |
| `PORT` | Often injected by platform (e.g. `8080`); ensure app reads `process.env.PORT` (already does) |
| `PUBLIC_API_BASE_URL` | **HTTPS** public URL of **this API** (email confirmation links) |
| `RESEND_API_KEY` / `RESEND_FROM` | Email verification |
| `FOURSQUARE_API_KEY` | Places API |
| `S3_*` | Presigned uploads (Supabase Storage is a different API; keep S3-compatible vars unless you reimplement uploads) |

## 4. CORS / clients

**Project URL → Settings → API** is for Supabase client keys, not your Express app.

Your mobile apps should call the **deployed API base URL** (same host as `PUBLIC_API_BASE_URL` without path). If you need a fixed origin for `cors()`, set `CORS_ORIGIN` only if you add that to the server (currently `cors()` is open).

## 5. Build and run the API (Docker)

From repo root:

```bash
docker build -t maillardmap-api -f backend/Dockerfile backend
docker run --rm -p 3000:3000 --env-file backend/.env.production maillardmap-api
```

Run migrations **before** the app starts, or as a **release phase** job with the same `DATABASE_URL`:

```bash
npm run build   # if not using Docker image that already built
npm run db:migrate:prod
```

## 6. `getaddrinfo ENOTFOUND db.<ref>.supabase.co`

Common cause: the **direct** DB host is often **IPv6-only**. Laptops and some networks never get a usable address, so Node reports **ENOTFOUND**.

**Fix:** In **Connect**, switch to **Session pooler** (Session mode): host looks like `aws-0-<region>.pooler.supabase.com`, with **IPv4**. Use that full URL as `DATABASE_URL` (and the **Username** the panel shows, often `postgres.<project-ref>`). Keep `?sslmode=require` if offered.

Also check: **paused** project, **typos**, **VPN/DNS**.

## 7. Optional: SSL with `pg`

If connections fail TLS handshakes, ensure `DATABASE_URL` includes `?sslmode=require`. The Supabase dashboard strings usually already include SSL parameters.

## 8. What not to use from Supabase (for this codebase)

- **Supabase Auth**: app uses custom JWT + `users` table; migrating away is a large change.
- **Edge Functions**: Deno, not this Express app—unless you rewrite endpoints.
