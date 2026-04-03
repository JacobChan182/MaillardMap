# Android (MVVM)

BigBack Android app built with Jetpack Compose and MVVM architecture.

## Architecture

```
android/app/src/main/java/com/maillardmap/
  data/          # API client, Repository, SessionManager
  domain/        # Pure domain models (no serialization)
  ui/            # Compose screens (auth, feed, post, friends, saved, map, restaurant, blend)
  viewmodel/     # RootViewModel (navigation state)
  common/        # Theme, bottom nav, shared utilities
  MainActivity.kt
  MainApplication.kt
```

## Tech Stack

- **UI**: Jetpack Compose, Material Design
- **Navigation**: Navigation Compose
- **HTTP**: Retrofit + OkHttp
- **Images**: Coil
- **Maps**: Mapbox SDK
- **Architecture**: MVVM (ViewModel + StateFlow)

## Screens

- **Auth** -- Login and Signup with username/password
- **Feed** -- Friend activity feed with posts (like, photos, comments)
- **Create Post** -- Select restaurant (search), add up to 3 photos, write short comment (max 200 chars)
- **Friends** -- List, send friend requests, accept requests
- **Saved Places** -- Save/unsaved restaurants
- **Map** -- Mapbox with heatmap at low zoom, pins at high zoom
- **Blend** -- Select friends and get taste-blended restaurant recommendations
- **Restaurant Search** -- Search restaurants via Foursquare

## Setup

1. Set `MAPBOX_DOWNLOADS_TOKEN` environment variable for Mapbox SDK
2. Open in Android Studio or run:
   ```
   ./gradlew assembleDebug
   ```
3. Backend must be running at `http://10.0.2.2:3000` (localhost from emulator)

## API Base URL

The default base URL is `http://10.0.2.2:3000/` (Android emulator localhost). Update `RootViewModel.baseUrl` for physical devices.
