# Android-iOS Parity Roadmap

**Initiative:** BigBack Platform Parity
**Target:** Align Android feature set with iOS implementation
**Date:** April 3, 2026

---

## Executive Summary

The Android app currently implements core functionality but lacks parity with iOS in several critical areas. This roadmap addresses:

1. **Missing features** (post editing, search debouncing, notification system)
2. **UI/UX consistency** (navigation patterns, interactive states, theming)
3. **Architecture alignment** (ViewModel responsibilities, error handling)
4. **Test coverage gaps** (E2E flows, edge cases, API contracts)

**Estimated Complexity:** 3-4 weeks of focused development

---

## 1. Current State Analysis

### 1.1 Android Implementation Status

**✅ Completed Features:**
- Authentication flow (login/signup)
- Basic feed display with posts
- Friend management (request/accept)
- Saved places persistence
- Restaurant search
- Blend heuristic recommendations
- Map integration with Mapbox

**⚠️ Partially Implemented:**
- Post creation (photo upload not fully validated)
- Like functionality (UI exists, API integration unclear)
- Location permissions handling

**❌ Missing Critical Features:**
- Email verification flow
- Post editing/update capability
- Post deletion functionality
- Comments on posts
- Notifications system
- User profile management
- Settings/preferences
- Pagination in feeds
- Debounced restaurant search
- Restaurant detail view
- Restaurant posts aggregation

### 1.2 iOS Feature Inventory

**Core ViewModels & Screens:**
```
AuthViewModel.swift + AuthView.swift
FeedViewModel.swift + FeedView.swift
CreatePostViewModel.swift + CreatePostView.swift
BlendViewModel.swift + BlendView.swift
MapViewModel.swift + MapView.swift
FriendsViewModel.swift + FriendsView.swift
SavedPlacesViewModel.swift + SavedPlacesView.swift
RestaurantSearchViewModel.swift + RestaurantSearchView.swift
UserPostsViewModel.swift + UserPostsView.swift
RestaurantPostsViewModel.swift + RestaurantPostsView.swift
NotificationsViewModel.swift + NotificationsView.swift
EditProfileView.swift
PostDetailView.swift
CommentsView.swift
MainTabView.swift (tab coordinator)
```

**Supporting Infrastructure:**
```
APIClient.swift (network layer with retry)
AvatarImageLoader.swift (avatar caching)
SocialImageCompression.swift (photo optimization)
TabRouter.swift (navigation coordinator)
Models/*.swift (data models)
```

---

## 2. Feature Parity Matrix

| Feature | Android Status | iOS Status | Priority | Effort |
|---------|---------------|------------|----------|--------|
| **Authentication** |
| Login/Signup | ✅ Complete | ✅ Complete | P0 | 0 |
| Email verification | ❌ Missing | ✅ Complete | P0 | 2d |
| Password reset | ❌ Missing | ✅ Complete | P2 | 2d |
| Edit profile | ❌ Missing | ✅ Complete | P1 | 3d |
| **Feed & Posts** |
| Post display | ✅ Basic | ✅ Full | P0 | 1d |
| Post creation | ⚠️ Partial | ✅ Complete | P0 | 3d |
| Post editing | ❌ Missing | ✅ Complete | P0 | 2d |
| Post deletion | ❌ Missing | ✅ Partial | P1 | 1d |
| Like posts | ⚠️ Unclear | ✅ Complete | P0 | 2d |
| Comments | ❌ Missing | ✅ Complete | P0 | 3d |
| Post detail view | ❌ Missing | ✅ Complete | P1 | 2d |
| **Friends** |
| Request/Accept | ✅ Complete | ✅ Complete | P0 | 0 |
| Friend status UI | ⚠️ Basic | ✅ Refined | P1 | 1d |
| Mutual friend count | ❌ Missing | ✅ Present | P2 | 1d |
| **Map** |
| Restaurant pins | ✅ Complete | ✅ Complete | P0 | 0 |
| Friend activity | ⚠️ Partial | ✅ Complete | P0 | 2d |
| Heatmap zoom | ❌ Missing | ✅ Complete | P1 | 2d |
| Focus restaurant | ⚠️ Partial | ✅ Complete | P1 | 1d |
| **Blend** |
| Taste algorithm | ✅ Complete | ✅ Complete | P0 | 0 |
| Friend selector | ✅ Complete | ✅ Complete | P0 | 0 |
| Results display | ⚠️ Basic | ✅ Rich | P1 | 2d |
| **Saved Places** |
| Save/Delete | ✅ Complete | ✅ Complete | P0 | 0 |
| UI polish | ⚠️ Basic | ✅ Refined | P2 | 1d |
| **Restaurant** |
| Search | ✅ Basic | ✅ Debounced | P0 | 2d |
| Restaurant detail | ❌ Missing | ✅ Complete | P0 | 3d |
| Restaurant posts | ❌ Missing | ✅ Complete | P1 | 2d |
| Aggregated stats | ❌ Missing | ✅ Present | P2 | 2d |
| **Notifications** |
| System | ❌ Missing | ✅ Complete | P2 | 5d |

---

## 3. UI/UX Consistency Requirements

### 3.1 Screen Mapping to iOS Equivalents

**Tab Navigation Structure:**
- **iOS:** MainTabView.swift with TabRouter
- **Android:** BottomNav.kt with navigation controller
- **Action:** Match tab icons, labels, and ordering exactly

**Per-Screen Mapping:**

| iOS Screen | Android Screen | Required Changes |
|------------|----------------|------------------|
| AuthView | AuthScreen | Add email verification UI state, match iOS layout |
| FeedView | FeedScreen | Add pull-to-refresh, match post card density |
| CreatePostView | CreatePostScreen | Add photo picker UI, validation states |
| BlendView | BlendScreen | Add friend multiselect UI, blur effect |
| MapView | MapScreen | Add friend activity overlay, heatmap layer |
| FriendsView | FriendsScreen | Add request animations, mutual count |
| SavedPlacesView | SavedPlacesScreen | Match iOS layout patterns |
| RestaurantSearchView | RestaurantSearchScreen | Add debounced search, match iOS results UI |
| NotificationsView | ❌ Missing | Need full implementation |

### 3.2 Critical UI Components to Replicate

| Component | iOS Implementation | Android Status | Action |
|-----------|-------------------|----------------|--------|
| **Post Card** | PostCardView.swift (SwiftUI) | Basic Card in FeedScreen | Replicate exact layout, spacing, action buttons |
| **Star Rating** | StarRatingControl.swift | ⚠️ Partial | Implement exact 5-star interactive control |
| **Restaurant Row** | RestaurantSearchResultRow.swift | Basic item | Match iOS styling and truncation rules |
| **Profile Avatar** | ProfileAvatarView.swift | Missing | Add circle crop with placeholder |
| **Comment Bubble** | CommentsView.swift | Missing | Full implementation needed |
| **Map Pin** | MapView.swift annotations | Basic marker | Match iOS pin design and clustering |
| **Blend Result Card** | BlendView.swift result view | Basic | Add blur, cross-fade animation |
| **Empty States** | Various empty views | Minimal | Add skeleton loading, empty states |

### 3.3 Design System Alignment

| iOS Element | Android Equivalent | Notes |
|-------------|--------------------|-------|
| SF Pro font | Inter/Roboto | Need to select appropriate weight mapping |
| systemBackground | Surface | Match light/dark color values |
| systemBlue | Primary | Use matching Pantone/HEX codes |
| Navigation bar translucency | Material elevation | May need custom composables |
| Sheet presentation | ModalBottomSheet | Match iOS sheet drag behavior |
| SwiftUI navigationDestination | Compose navigation | Ensure consistent back button behavior |

**File Reference:** `ios/BigBack/Views/**/*.swift` vs `android/app/src/main/java/com/bigback/ui/**/*.kt`

---

## 4. Architecture Alignment

### 4.1 ViewModel Mapping

| iOS ViewModel | Android ViewModel | Parity Notes |
|---------------|-------------------|--------------|
| AuthViewModel | AuthViewModel | ✅ Matched - may need email verification state |
| FeedViewModel | FeedScreen (logic embedded) | ⚠️ Move to dedicated ViewModel |
| CreatePostViewModel | CreatePostScreen | ⚠️ Extract to ViewModel |
| MapViewModel | MapScreen | ⚠️ Extract to ViewModel |
| FriendsViewModel | FriendsScreen | ⚠️ Extract to ViewModel |
| SavedPlacesViewModel | SavedPlacesScreen | ⚠️ Extract to ViewModel |
| RestaurantSearchViewModel | RestaurantSearchScreen | ⚠️ Extract to ViewModel |
| BlendViewModel | BlendScreen | ⚠️ Extract to ViewModel |
| NotificationsViewModel | ❌ Missing | ❌ Full implementation needed |

**Action Item:** Refactor Android to use consistent ViewModel pattern across all screens (separate screen logic from UI state).

### 4.2 Network Layer

**iOS Implementation:** `APIClient.swift`
- URLSession with async/await
- OAuth token injection
- Retry logic with exponential backoff
- Error decoding to ServerErrorDetail

**Android Implementation:** `ApiClient.kt`
- Retrofit with call adapters
- Interceptor for auth token
- Basic error handling
- No retry mechanism

**Required Updates:**
1. Add retry with backoff to ApiClient.kt
2. Match iOS error types and propagation
3. Implement presigned upload URL flow for photos
4. Add request deduplication/memoization

### 3.3 Data Models

**iOS Models:** Swift structs with Codable, proper naming conventions
**Android Models:** Kotlin data classes (matched ✅)

**Check for consistency:**
- Field names match API spec exactly
- Nullable properties align with backend contracts
- Date formatting consistent (ISO 8601)

**File Reference:** `ios/BigBack/Models/*.swift` vs `android/app/src/main/java/com/bigback/domain/Models.kt`

---

## 5. Implementation Sequence

### Phase 0: Foundation (Priority Critical)
**Duration:** 3-4 days

1. **Architecture Refactor**
   - Extract ViewModels for all screens that lack them
   - Standardize error handling patterns
   - Add analytics instrumentation points

2. **Network Layer Enhancement**
   - Add retry logic with exponential backoff
   - Match iOS error types
   - Implement proper presigned upload handling

3. **UI Component Library**
   - Implement StarRatingControl (Compose equivalent)
   - Build ProfileAvatarView with caching
   - Create consistent empty/skeleton states

### Phase 1: Parity - Core Experiences (Priority P0)
**Duration:** 10-12 days

**Week 1:**
- Email verification flow (2d)
- Post editing capability (2d)
- Like functionality + UI (2d)
- Comments system (2d)
- Post detail screen (2d)

**Week 2:**
- Restaurant search debouncing (2d)
- Restaurant detail view (3d)
- Map friend activity overlay (2d)
- Map heatmap layer (2d)
- Restaurant posts aggregation (2d)

**Parallel:** UI polish on Feed/Map/Blend screens to match iOS density

### Phase 2: Parity - Refinement (Priority P1)
**Duration:** 5-6 days

- Pagination for feeds (2d)
- Post deletion (1d)
- Restaurant aggregated stats (2d)
- Settings/preferences screen (3d)
- Deep linking support (2d)

### Phase 3: Polish & Performance (Priority P2)
**Duration:** 4-5 days

- Image caching optimization (2d)
- Map marker clustering (2d)
- Pull-to-refresh everywhere (1d)
- Skeleton loading states (2d)
- Accessibility audit (1d)

### Phase 4: Quality & Testing
**Duration:** Ongoing + 2 days final pass

- Unit tests for ViewModels
- UI tests for critical flows
- API contract validation
- Beta testing with iOS users

---

## 6. Test Coverage Plan

### 6.1 Critical Test Scenarios (QA Team Input Needed)

**Authentication Flow:**
- [ ] Login with valid credentials
- [ ] Login with invalid credentials
- [ ] Signup with duplicate username
- [ ] Email verification flow
- [ ] Logout and session invalidation

**Feed & Posts:**
- [ ] Load feed with zero posts
- [ ] Create post with 1-3 photos
- [ ] Create post with zero photos (edge case)
- [ ] Edit existing post
- [ ] Delete post
- [ ] Like/unlike post
- [ ] Add comment
- [ ] Infinite scroll pagination

**Friends:**
- [ ] Send friend request
- [ ] Accept/decline request
- [ ] Remove friend
- [ ] Mutual friend count accuracy

**Blend:**
- [ ] Blend with single friend
- [ ] Blend with multiple friends
- [ ] Blend with no activity (empty result)
- [ ] Blend result ranking consistency

**Map:**
- [ ] Location permissions denied
- [ ] Restaurant pin tap navigation
- [ ] Focus restaurant from post
- [ ] Heatmap toggle (if implemented)
- [ ] Friend activity markers appear

**Search:**
- [ ] Debounced search triggers on input
- [ ] Search result accuracy
- [ ] Empty search term handling
- [ ] Rate limiting protection

### 6.2 API Contract Tests

```kotlin
// Example: Retrofit interface test
@Test
fun `POST /posts creates post with correct payload`() {
    val postData = CreatePostRequest(comment = "test", restaurantId = "xxx")
    val response = apiClient.createPost(postData)
    assert(response.isSuccessful)
    assert(response.body()?.comment == "test")
}
```

**Validations:**
- Auth token header injection
- Request payload schemas
- Response parsing (including error cases)
- Retry behavior on 5xx
- 401 handling (token refresh)

### 6.3 Performance Benchmarks

| Screen | Target Load Time | iOS Baseline | Gap |
|--------|------------------|--------------|-----|
| Feed scroll | <16ms per item | ~12ms | 4ms |
| Map render | <1s | ~800ms | 200ms |
| Post create | <10s | ~6s | 4s |

---

## 7. Technical Risks & Blockers

1. **Mapbox SDK Version Mismatch**
   - iOS uses Mapbox Maps SDK v10.x
   - Android uses Mapbox Maps SDK v11.x
   - **Risk:** Feature/API differences may require workarounds
   - **Action:** Audit Mapbox feature usage; coordinate with iOS team

2. **Photo Handling Complexity**
   - iOS: SocialImageCompression + presigned upload
   - Android: Coil + unclear upload flow
   - **Risk:** Photo quality/size may differ between platforms
   - **Action:** Implement spiral compression matching iOS exactly

3. **Navigation Parity**
   - iOS: SwiftUI NavigationStack with sheet presentation
   - Android: Compose Navigation with modal bottom sheets
   - **Risk:** Transition animations may feel inconsistent
   - **Action:** Customize Compose transitions to match iOS

4. **State Management Differences**
   - iOS: @StateObject/@ObservedObject with async/await
   - Android: ViewModel + StateFlow/LiveData
   - **Risk:** Error state handling may diverge
   - **Action:** Standardize error propagation patterns

---

## 8. Dependencies & Assumptions

- Backend API contracts are stable and versioned
- iOS team can provide code reviews for parity questions
- QA team available for cross-platform testing
- Mapbox enterprise plan covers both platforms
- Foursquare Places API rate limits sufficient for both apps

---

## 9. Success Criteria

- ✅ All screens listed in iOS Feature Inventory have Android equivalents
- ✅ UI components match iOS pixel-perfect within platform conventions
- ✅ Network layer handles errors identically
- ✅ No crashes or ANRs in parity scenarios (QA validated)
- ✅ API contract tests pass for all endpoints
- ✅ Performance metrics within 20% of iOS baseline

---

## 10. Next Steps

1. **Immediate:** Review this roadmap with team lead and QA engineer
2. **Week 1:** Begin Phase 0 architecture refactor
3. **Parallel:** QA team creates test cases for identified scenarios
4. **Daily:** Sync with iOS team for clarification on ambiguous features
5. **Bi-weekly:** Demo parity progress to stakeholders

**Questions for iOS Team:**
1. What is the exact algorithm for heatmap generation on the map?
2. How does the notifications system handle delivery when app is backgrounded?
3. Are there any hidden UI states (loading, error, empty) not visible in code?
4. What edge cases should we test for photo uploads?

---

## Appendix: File References

### Android Key Files
- `android/app/src/main/java/com/bigback/ui/RootScreen.kt` - Navigation root
- `android/app/src/main/java/com/bigback/viewmodel/RootViewModel.kt` - App state
- `android/app/src/main/java/com/bigback/data/Repository.kt` - Data layer
- `android/app/src/main/java/com/bigback/data/ApiClient.kt` - Network
- `android/app/src/main/java/com/bigback/common/Theme.kt` - Design system
- `android/app/src/main/java/com/bigback/common/BottomNav.kt` - Tab navigation

### iOS Key Files
- `ios/BigBack/App/BigBackApp.swift` - App entry point
- `ios/BigBack/Views/Main/MainTabView.swift` - Tab coordinator
- `ios/BigBack/Services/APIClient.swift` - Network layer
- `ios/BigBack/ViewModels/*.swift` - All ViewModels
- `ios/BigBack/Views/**/*.swift` - All screens
