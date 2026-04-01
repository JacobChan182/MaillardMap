# BigBack Test Strategy

## Framework

- **Framework:** Vitest (`npm test` → `vitest run`)
- **Assertion style:** `describe` / `it` / `expect` (Vitest built-in globals)
- **Module format:** ESM only (`"type": "module"` in package.json)
- **File location:** `backend/test/**/*.test.ts`

## Test Tiers

### Tier 1 — Unit tests (no DB, no HTTP)

Pure functions and schema validation. Instant, deterministic.

| File | Covers |
|------|--------|
| `health.test.ts` | `getHealth()` return shape |
| `auth.test.ts` | `signup()` and `login()` service logic |
| `schema.test.ts` | Zod schemas for all request bodies |

### Tier 2 — Integration tests (Express app with mocked DB pool)

Tests routes against the real `createApp()` express instance, intercepting
PostgreSQL with a mock pool.

| File | Covers |
|------|--------|
| `routes.test.ts` | `GET /`, `GET /health`, `POST /auth/signup`, `POST /auth/login`, security headers, malformed input |

### Tier 3 — E2E flow descriptions (documented below)

End-to-end scenarios the QA agent should validate once full implementation
is complete. These are specifications, not executable tests.

## Running Tests

```bash
npm test            # vitest run  (all tests)
npm run typecheck   # typecheck before committing
```

## Mock Strategy

- **`db/pool.ts`** — `vi.mock()` replaces `getPool()` with a `MockPool` that
  matches SQL by substring and returns controlled results.
- **Foursquare API** — when implemented, mock via `vi.mock()` on the Foursquare
  client module.
- **JWT** — set `process.env.JWT_SECRET` to a 32+ character test value.

## Database Migrations

The migrations live in `backend/migrations/`. Run `npm run db:migrate` before
integration tests that need a real database.

---

## E2E Flow Descriptions

### Flow A — New User Signup & Post

```
1. POST /auth/signup  → 201, receive userId + JWT
2. GET /restaurants/search?q=pizza  → 200, receive list of Foursquare venues
3. POST /posts with:
     restaurant_id (from step 2)
     comment: "Great slice!"
     photos: [file1, file2]
   → 201, post created
4. GET /posts/feed  → 200, post visible in own feed
5. GET /posts/user/:id  → 200, own posts listed
```

### Flow B — Friendship & Social Interactions

```
1. Create User A and User B (signup + login each)
2. POST /friends/request { friend_id: B } as A  → 201, pending
3. GET /friends/list as A  → 200, B listed as pending
4. POST /friends/accept { request_id } as B  → 200, accepted
5. GET /friends/list as A  → 200, B now accepted
6. POST /posts/:id/like as B  → 201, liked
7. POST /posts/:id/like as B again  → 409 (duplicate like)
8. GET /posts/feed as A  → 200, includes friend B's posts
```

### Flow C — Save & Taste Blend

```
1. Create User A and User B
2. POST /saved { restaurant_id } as A (×3 different cuisines)
3. POST /posts as A (×2 posts, different cuisines)
4. POST /friends/accept (make A and B mutual friends)
5. POST /recommendations/blend { user_ids: [A, B] } as A
   → 200, returns:
       - topCuisines: frequency-sorted cuisine list
       - centroid: { avg_lat, avg_lng }
       - restaurants: nearby restaurants from Foursquare, ranked by
         cuisine match score + distance to centroid
6. Assert NO ML / embeddings used (heuristic only)
```

## Guardrail Tests (to implement once modules exist)

| Rule | Endpoint | Expected |
|------|----------|----------|
| Max 3 photos per post | POST /posts | 400 `PHOTO_LIMIT_EXCEEDED` |
| Max 200 char comment | POST /posts | 400 `COMMENT_TOO_LONG` |
| Foursquare-only restaurants | POST /posts | Must include valid `foursquare_id` |
| No custom restaurant creation | N/A | No endpoint allows creating a restaurant without Foursquare ID |
| JWT_SECRET < 32 chars | POST /auth/login | Throws error at startup |
| Rate limit exceeded | Any | 429 from express-rate-limit |
| N+1 prevention | GET /posts/feed | Query uses JOIN, not per-post queries |