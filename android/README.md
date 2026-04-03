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

1. **Install an Android SDK** (if you do not have one yet): install [Android Studio](https://developer.android.com/studio) and use **Settings → Languages & Frameworks → Android SDK** to install SDK **34** (matches `compileSdk`). Note the **Android SDK location** path shown at the top of that screen.
2. **Point Gradle at the SDK** (command-line builds):
   - **Option A:** Copy `local.properties.example` to `local.properties` in this folder and set `sdk.dir` to that path (use forward slashes, no quotes), **or**
   - **Option B:** `export ANDROID_HOME="/path/to/Android/sdk"` (same folder Studio shows), then run `./gradlew`.
3. Set `MAPBOX_DOWNLOADS_TOKEN` for Mapbox Maven (see `settings.gradle.kts`).
4. From this folder:
   ```bash
   ./gradlew assembleDebug
   ```
   Debug APK: `app/build/outputs/apk/debug/app-debug.apk`
5. Backend for the emulator: `http://10.0.2.2:3000` (see **API Base URL** below).

Opening the `android/` folder in Android Studio and using **Build → Make Project** / **Run** still works; Studio writes `local.properties` for you.

## API base URL

Resolved at build time into **`BuildConfig.API_BASE_URL`** (used by `RootViewModel` and `AuthScreen`).

1. **`gradle.properties`** — `MAILLARDMAP_API_BASE_URL` (committed default is the live Railway host; change as needed).
2. **`local.properties`** — same key **overrides** for local dev, e.g. `MAILLARDMAP_API_BASE_URL=http://10.0.2.2:3000` (emulator → host) or `http://192.168.x.x:3000` (physical device → your machine).

Rebuild after changing the URL.
