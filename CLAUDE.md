# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product Overview

A fast, lightweight mobile social app for sharing restaurant experiences with friends and discovering new places through **taste blending**.

**Core user flows:**
- Add friends (mutual)
- Post quick restaurant visits (≤3 photos + short comment ≤200 chars)
- View activity on a map
- Blend tastes with friends/groups to get recommendations

**External APIs:**
- Foursquare Places API → restaurant data (structured data only, never user-created)
- Mapbox → maps, tiles, visualization

## Product Principles

1. **Fast over everything** - Minimize latency, clicks, and load time
2. **Low friction** - Posting must take ≤10 seconds
3. **Social-first** - Focus on friends, not anonymous reviews
4. **Structured data > user input** - Restaurants come only from Foursquare
5. **Simple > smart** - Heuristic recommendations, no ML

## Non-Goals (DO NOT BUILD)

- Long-form reviews
- User-created restaurants
- Realtime features (no sockets, no live feeds)
- Complex ranking algorithms (ML/embeddings)
- Messaging / DMs
- Notifications (v1)

## Tech Stack

| Layer | Technology |
|-------|------------|
| iOS | Swift |
| Android | Kotlin |
| Backend | Node.js (Express or Fastify), REST API only |
| Database | PostgreSQL |
| Storage | S3-compatible (photos) |
| Maps | Mapbox |

## Data Models

### User
```
id (uuid)
username (unique)
phone/email
created_at
```

### Friendship
```
id
user_id
friend_id
status (pending, accepted)
created_at
```

### Restaurant
```
id (internal uuid)
foursquare_id (unique)
name
lat
lng
cuisine (string or array)
```

### Post
```
id
user_id
restaurant_id
comment
created_at
```

### PostPhoto
```
id
post_id
url
order_index (1–3)
```

### Like
```
id
user_id
post_id
created_at
```

### SavedPlace
```
id
user_id
restaurant_id
created_at
```

## API Endpoints

```
POST /auth/signup
POST /auth/login

GET /users/:id
GET /users/search?q=

POST /friends/request
POST /friends/accept
GET /friends/list

POST /posts
GET /posts/feed
GET /posts/user/:id
POST /posts/:id/like

POST /saved
GET /saved
DELETE /saved/:restaurant_id

GET /restaurants/search?q=
GET /restaurants/:id

POST /recommendations/blend
BODY: { user_ids: [] }
```

## Recommendation Logic (HEURISTIC ONLY)

**NO ML, NO EMBEDDINGS**

1. Collect all restaurants from: posts, liked posts, saved places
2. Extract: cuisine frequencies, coordinates
3. Compute:
   - Top cuisines (frequency-based)
   - Centroid: avg_lat = mean(lat), avg_lng = mean(lng)
4. Query nearby restaurants via Foursquare near centroid, filtered by top cuisines
5. Rank by: cuisine match score, distance to centroid

## Performance Rules

- Keep endpoints <200ms where possible
- Avoid N+1 queries
- Cache Foursquare responses
- No premature abstractions
- Prefer simple queries over complex joins
- Never block UI on slow network calls

## Map Behavior

Using Mapbox:
- Default: center on user location
- Zoom < threshold: show heatmap of posts
- Zoom ≥ threshold: show pins (restaurants, friend activity)

## Guardrails

- NEVER allow custom restaurant creation (Foursquare only)
- ALWAYS use Foursquare IDs
- NEVER introduce realtime systems
- NEVER exceed 3 photos per post
- NEVER exceed 200 chars per comment
- NEVER use ML for recommendations

## Claude Teams Configuration

### Agents (MAX 5)

Use via `Agent` tool with `subagent_type`:

| Agent | Model | Owns | Rules |
|-------|-------|------|-------|
| `product-architect` | product-architect | Specs, data models, API contracts, recommendation logic | Define before build; prevent overengineering |
| `backend` | backend | API endpoints, DB schema, Foursquare integration, recommendation system | REST only; clean JSON; no logic in controllers (use services) |
| `ios` | ios | Full iOS app, Mapbox integration, UI flows | Optimize for speed; minimal architecture overhead |
| `android` | android | Full Android app, parity with iOS | Must match API behavior exactly |
| `qa` | qa | E2E validation, API contract enforcement, edge case testing | Simulate posting, liking, blending; catch schema mismatches |

### Skills

Invoke via `/skill-name` or Skill tool:

| Skill | Usage |
|-------|-------|
| `/commit` | `/commit message="..."` |
| `/test` | `/test` |
| `/build` | `/build` |
| `/lint` | `/lint` |
| `/typecheck` | `/typecheck` |
| `/format` | `/format` |
| `/review-pr` | `/review-pr [number]` |
| `/create-pr` | `/create-pr title="..." body="..." [base=main]` |
| `/db-migrate` | `/db-migrate` |
| `/db-seed` | `/db-seed` |
| `/docker-build` | `/docker-build` |
| `/docker-up` | `/docker-up` |
| `/docker-down` | `/docker-down` |
| `/logs` | `/logs service=...` |
| `/deploy` | `/deploy env=...` |
| `/security-scan` | `/security-scan` |

### Hooks

- `pre-commit`: Security scan (git-secrets) and npm audit
- `post-apply`: Auto-format code with Prettier

### Development Workflow

1. **Product Architect** defines feature (specs, models, API)
2. **Backend** implements API + DB schema
3. **iOS + Android** build in parallel (match API contracts)
4. **QA** validates integration (E2E flows, schema checks)
5. Iterate

### Project Structure

```
├── .claude/
│   ├── settings.json      # Agent/skill/hook definitions
│   ├── agents/            # Agent documentation
│   ├── skills/            # Skill documentation
│   ├── hooks/             # Hook shell scripts
│   ├── workflows/         # Development workflows
│   └── memory/            # Project memory
├── backend/               # Node.js API
├── ios/                   # Swift app
├── android/               # Kotlin app
└── docs/                  # Documentation
```

### Definition of Done

A feature is complete when:
- Backend endpoint works (tested)
- iOS + Android implement it
- QA agent validates: no crashes, correct data, consistent UX
