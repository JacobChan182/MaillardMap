# Android Implementation Plan

## Goal
Build a complete Android app (Jetpack Compose) that matches the iOS counterpart 1:1, implementing all specified features and API contracts.

## High-Level Approach
1. **Domain Models** – Create Kotlin data classes matching all backend JSON schemas.
2. **Network Layer** – Implement full Retrofit API client for all 17 endpoints, including auth handling.
3. **Repository & Session** – Provide clean suspend functions and persist JWT/USER state.
4. **UI Screens** – Develop each screen using Jetpack Compose, aligning with iOS behavior.
5. **Integration & Testing** – Ensure end-to-end flow, proper error handling, and state consistency.

## Detailed Tasks

- **Task 1: Domain Models**
  - Define data classes in `domain/Models.kt`:
    - `User`, `Friendship`, `Restaurant`, `Post`, `PostPhoto`, `SavedPlace`, `BlendResult`, `Like`, etc.
  - Use `@SerializedName` for snake_case JSON fields.

- **Task 2: API Client**
  - Implement `data/ApiClient.kt` with Retrofit service covering all endpoints.
  - Add Authorization: Bearer token header.
  - Handle error responses (401 → logout, 400 → error UI).

- **Task 3: Repository**
  - Create `data/Repository.kt` with suspend functions for each API call:
    - `signup`, `login`, `searchUsers`, `sendFriendRequest`, `acceptFriendRequest`,
      `getFriends`, `createPost`, `getFeed`, `getUserPosts`, `likePost`,
      `savePlace`, `getSavedPlaces`, `removeSavedPlace`, `searchRestaurants`,
      `getRestaurant`, `blendTastes`.
  - Inject `ApiClient` dependencies.

- **Task 4: Session Management**
  - Implement `data/SessionManager.kt` to persist JWT and user ID (DataStore or SharedPreferences).
  -Expose `isLoggedIn`, `token`, `userId`, `logout()`.

- **Task 5: Auth Screen**
  - Build `ui/auth/AuthScreen.kt` with signup/login forms, error handling, navigation to `RootScreen` on success.

- **Task 6: Feed Screen**
  - Implement `ui/feed/FeedScreen.kt` using lazy column, `PostCard` composables.
  - Pull-to-refresh, like counts, liked state.

- **Task 7: Create Post Screen**
  - Build `ui/post/CreatePostScreen.kt` with restaurant search, photo picker (max 3), comment field (≤200 chars), submission.

- **Task 8: Friends Screen**
  - Implement `ui/friends/FriendsScreen.kt` with friend list, request/search functionality.

- **Task 9: Blend Screen**
  - Build `ui/blend/BlendScreen.kt` for friend selection and display of blend results.

- **Task 10: Map Screen**
  - Implement `ui/map/MapScreen.kt` using Mapbox Compose SDK or Google Maps Compose, showing pins and user location.

- **Task 11: Saved Places Screen**
  - Implement `ui/saved/SavedPlacesScreen.kt` with list, swipe-to-delete, save/remove actions.

- **Task 12: Restaurant Search Screen**
  - Build `ui/restaurant/RestaurantSearchScreen.kt` with search bar and results list.

- **Task 13: Root Screen & Bottom Nav**
  - Implement `ui/RootScreen.kt` with 5-tab bottom navigation (`BottomNav.kt`).

- **Task 14: Shared Resources**
  - Ensure `common/Theme.kt`, theming, and constants are consistent across screens.

- **Task 15: Testing & Validation**
  - QA flows: auth, posting, liking, blending, saved places.
  - Verify API contract compliance and error handling.

## Dependencies
- Tasks 1-3 must complete before UI work begins.
- Feed, CreatePost, and Blend screens share repository calls.
- Authentication state flows through SessionManager to all screens.

## Success Criteria
- All API endpoints work with correct request/response shapes.
- UI matches iOS behavior pixel-perfectly (Compose).
- No crashes, proper error UI, state persistence across sessions.
- End-to-end tests pass for core flows (login → feed → like → save).