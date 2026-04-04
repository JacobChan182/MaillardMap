# MaillardMap

**Social restaurant discovery for friends** — share short visits (photos + comment), see activity on a map, save places, and blend tastes with friends for heuristic recommendations. Restaurant data comes from **Foursquare** only (no user-created venues).

> **Repo one-liner (GitHub description):** Full-stack social dining app — **SwiftUI** & **Jetpack Compose** clients, **Node.js (Express) + TypeScript** REST API, **PostgreSQL**, **S3** photo uploads, **Mapbox** maps, **Foursquare** places, **OpenAPI** contract.

## Features

- **Auth** — Sign up / log in; optional email verification (Resend).
- **Friends** — Send and accept requests; mutual friend graph for social context.
- **Posts** — Pick a Foursquare-backed restaurant, up to **3** photos (presigned S3 upload), comment ≤ **200** characters; friend feed, per-user and per-restaurant views.
- **Engagement** — Likes and threaded **comments** on posts.
- **Saved places** — Bookmark restaurants for later.
- **Map** — Mapbox map with zoom-dependent visualization (heatmap vs pins) for activity.
- **Taste blend (coming soon!)** — `POST /recommendations/blend` aggregates posts, likes, and saves across selected users, derives top cuisines + geographic centroid, and ranks nearby matches with a **simple heuristic** (no ML).
- **Restaurant search** — Server-backed search that resolves through Foursquare and persists structured rows in Postgres.
- **Profile & notifications** — User profiles and in-app notification surfaces (see API/OpenAPI for current endpoints).

## Tech stack

| Area | Technology |
|------|------------|
| **iOS** | Swift, SwiftUI, MVVM |
| **Android** | Kotlin, Jetpack Compose, Navigation, Retrofit/OkHttp, Coil, MVVM |
| **API** | Node.js, **Express 5**, TypeScript, Zod validation |
| **Data** | PostgreSQL 16 (migrations in `backend/`) |
| **Storage** | S3-compatible presigned uploads (`@aws-sdk/client-s3`) |
| **Maps** | Mapbox (native SDKs) |
| **Places** | Foursquare Places API |
| **Contract** | `docs/openapi.yaml` (source of truth for mobile + backend) |
| **Ops** | Docker Compose for local Postgres; deploy docs under `docs/` |

## Repository layout

```
├── backend/       # REST API (Express, Vitest, ESLint, Prettier)
├── ios/           # SwiftUI app (Xcode project: BigBack.xcodeproj)
├── android/       # Kotlin + Compose app
├── docs/          # OpenAPI, architecture, deployment guides
├── .claude/       # Agent/skill configuration (optional tooling)
└── docker-compose.yml   # Local PostgreSQL
```

The iOS target name **BigBack** is legacy in paths and Xcode; the product and packages align with **MaillardMap**.

## Prerequisites

- **Node.js** (see `backend/package.json` engines if present; LTS recommended)
- **PostgreSQL** (local: `docker compose up -d` from repo root)
- **Xcode** (iOS) / **Android Studio** + SDK 34 (Android)
- API keys as documented in `backend/.env.example`, Mapbox tokens for mobile builds

## Quick start — API

```bash
cd backend
cp .env.example .env
# Set DATABASE_URL, JWT_SECRET, and optional FOURSQUARE / S3 / Resend vars

# From repo root, if using Compose:
docker compose up -d
cd backend && npm install && npm run db:migrate && npm run dev
```

Health check: `GET http://localhost:3000/health`

## Mobile clients

- **Android** — See [`android/README.md`](android/README.md) for Gradle, `MAILLARDMAP_API_BASE_URL`, and Mapbox Maven token.
- **iOS** — Open `ios/BigBack.xcodeproj` in Xcode; configure Mapbox and API base URL per project settings (see `ios/BigBack` sources and `Services/APIClient.swift`).

## API contract & quality

- OpenAPI spec: [`docs/openapi.yaml`](docs/openapi.yaml)
- Contributing workflow, ownership, and PR checklist: [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Documentation

- [`backend/README.md`](backend/README.md) — env vars, Docker image, scripts
- [`docs/architecture.md`](docs/architecture.md) — schema and system notes
- [`docs/deploy-api-docker.md`](docs/deploy-api-docker.md), [`docs/deploy-supabase.md`](docs/deploy-supabase.md) — hosting

## License

MIT