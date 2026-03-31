# claude.md

## 🧭 Product Overview

A fast, lightweight mobile social app for sharing restaurant experiences with friends and discovering new places through **taste blending**.

Users:

* Add friends (mutual)
* Post quick restaurant visits (≤3 photos + short comment)
* View activity on a map
* Blend tastes with friends/groups to get recommendations

---

## 🎯 Product Principles

1. **Fast over everything**

   * Minimize latency, clicks, and load time
2. **Low friction**

   * Posting must take ≤10 seconds
3. **Social-first**

   * Focus on friends, not anonymous reviews
4. **Structured data > user input**

   * Restaurants come only from Foursquare
5. **Simple > smart**

   * Heuristic recommendations, no ML

---

## 🚫 Non-Goals (DO NOT BUILD)

* Long-form reviews
* User-created restaurants
* Realtime features (no sockets, no live feeds)
* Complex ranking algorithms
* Messaging / DMs
* Notifications (v1)

---

## 🧱 Core Features (MVP)

### 1. Authentication

* Email or phone-based login
* JWT-based sessions

### 2. Friends

* Mutual friendship model
* Add via:

  * username search
  * contact import

### 3. Posts

* Required:

  * restaurant_id (Foursquare)
  * 1–3 photos
  * short_comment (≤200 chars)
* Optional:

  * liked flag (implicit via likes)
* No ratings required

### 4. Saved Places

* Users can privately save restaurants
* Used to improve recommendations

### 5. Likes

* Users can like posts
* Used as taste signal

### 6. Map

* Default: centered on user
* Zoomed out: heatmap of activity
* Zoomed in: restaurant pins

### 7. Taste Blending (Core Differentiator)

* Select 1+ friends
* Generate recommendations based on:

  * shared cuisines
  * geographic proximity

---

## 🏗️ System Architecture

### Mobile Apps

* iOS: Swift
* Android: Kotlin

### Backend

* Node.js (Express or Fastify)
* REST API only

### Database

* PostgreSQL

### Storage

* S3-compatible object storage (photos)

### External APIs

* Foursquare Places API → restaurant data
* Mapbox → maps, tiles, visualization

---

## 🧩 Data Model

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

---

## 🔌 API Design (REST)

### Auth

```
POST /auth/signup
POST /auth/login
```

### Users

```
GET /users/:id
GET /users/search?q=
```

### Friends

```
POST /friends/request
POST /friends/accept
GET /friends/list
```

### Posts

```
POST /posts
GET /posts/feed
GET /posts/user/:id
POST /posts/:id/like
```

### Saved Places

```
POST /saved
GET /saved
DELETE /saved/:restaurant_id
```

### Restaurants

```
GET /restaurants/search?q=
GET /restaurants/:id
```

(Fetched + cached from Foursquare)

### Recommendations

```
POST /recommendations/blend
BODY: { user_ids: [] }
```

---

## 🤖 Recommendation Logic (STRICT RULES)

### Inputs

* Selected users (including self)

### Signals

* Visited restaurants (posts)
* Liked posts
* Saved places

### Step-by-step

1. Collect all restaurants from:

   * posts
   * liked posts
   * saved places

2. Extract:

   * cuisine frequencies
   * coordinates

3. Compute:

   * top cuisines (frequency-based)
   * centroid:

     ```
     avg_lat = mean(lat)
     avg_lng = mean(lng)
     ```

4. Query nearby restaurants via Foursquare:

   * near centroid
   * filtered by top cuisines

5. Rank results:

   * cuisine match score
   * distance to centroid

### Output

* Ranked list of restaurants

### DO NOT:

* Use ML models
* Use embeddings
* Overcomplicate scoring

---

## 🗺️ Map Behavior

Using Mapbox:

* Default:

  * center on user location

* Zoom < threshold:

  * show heatmap of posts

* Zoom ≥ threshold:

  * show pins:

    * restaurants
    * friend activity

---

## ⚡ Performance Rules

* Keep endpoints <200ms where possible
* Avoid N+1 queries
* Cache Foursquare responses
* No premature abstractions
* Prefer simple queries over complex joins

---

## 🧠 Agent System (MAX 5 AGENTS)

### 1. Product Architect Agent

**Owns:**

* specs
* data models
* API contracts
* recommendation logic

**Rules:**

* Define before build
* Prevent overengineering

---

### 2. Backend Agent (Node.js)

**Owns:**

* all API endpoints
* DB schema
* Foursquare integration
* recommendation system

**Rules:**

* REST only
* clean, predictable JSON
* no business logic in controllers (use services)

---

### 3. iOS Agent (Swift)

**Owns:**

* full iOS app
* Mapbox integration
* UI flows

**Rules:**

* optimize for speed
* minimal architecture overhead

---

### 4. Android Agent (Kotlin)

**Owns:**

* full Android app
* parity with iOS

**Rules:**

* must match API behavior exactly

---

### 5. QA / Integration Agent

**Owns:**

* end-to-end validation
* API contract enforcement
* edge case testing

**Responsibilities:**

* simulate flows:

  * posting
  * liking
  * blending
* catch schema mismatches
* validate recommendation outputs

---

## 🔄 Development Workflow

1. Product Architect defines feature
2. Backend Agent implements API
3. iOS + Android agents build in parallel
4. QA agent validates integration
5. Iterate

---

## 🧪 Example User Flow (REFERENCE)

**Post Flow**

1. User taps “Post”
2. Searches restaurant (Foursquare)
3. Selects restaurant
4. Adds ≤3 photos
5. Adds short comment
6. Submits

**Blend Flow**

1. User selects friends
2. App calls `/recommendations/blend`
3. Backend returns ranked restaurants
4. Display on map + list

---

## 🔐 Guardrails

* NEVER allow custom restaurant creation
* ALWAYS use Foursquare IDs
* NEVER introduce realtime systems
* NEVER exceed 3 photos per post
* NEVER block UI on slow network calls

---

## 🚀 Future Extensions (NOT MVP)

* Notifications
* Collections
* AI recommendations (later)
* Group planning
* Reservations integration

---

## ✅ Definition of Done

A feature is complete when:

* Backend endpoint works
* iOS + Android implement it
* QA agent validates:

  * no crashes
  * correct data
  * consistent UX

---

END OF FILE
