# Android (MVVM)

This folder is owned by the `android` agent.

## MVVM layout (skeleton)

```
android/
  app/
    src/main/java/com/bigback/
      data/        # API + persistence
      domain/      # use-cases + models
      ui/          # Compose views/screens
      viewmodel/   # ViewModels
```

## Next steps

- Create a Gradle project (Android Studio) rooted at `android/`
- Use `data/` for repositories + network DTOs
- Use `domain/` for app models and use cases
- Use `ui/` + `viewmodel/` for MVVM (Compose)
