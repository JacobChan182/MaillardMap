# MVVM conventions

This repo uses **MVVM** for the mobile clients.

## iOS (SwiftUI)

- **Views**: `ios/BigBack/Views/` (SwiftUI)
- **ViewModels**: `ios/BigBack/ViewModels/` (`@MainActor` ObservableObjects)
- **Models**: `ios/BigBack/Models/` (DTOs + domain models)
- **Services**: `ios/BigBack/Services/` (API client, storage, integrations)

## Android (Compose)

- **ui**: `android/app/src/main/java/com/bigback/ui/` (Compose screens)
- **viewmodel**: `android/app/src/main/java/com/bigback/viewmodel/`
- **domain**: `android/app/src/main/java/com/bigback/domain/` (models + use cases)
- **data**: `android/app/src/main/java/com/bigback/data/` (network + persistence + repos)

## Backend (layering, not MVVM)

Backend uses a thin HTTP layer + modules:

```
backend/src/
  server/            # express app wiring
  modules/<feature>/ # routes + service per feature
```
