# Wiam Okok — Portfolio

Personal portfolio app built with Flutter, available on mobile and web.

## About

A showcase of my work as a mobile app developer — 3 years of experience across freelance and full-time roles, with 1 published app and several unreleased projects.

## Stack

| Concern | Package |
|---|---|
| State management | `hooks_riverpod` + `flutter_hooks` |
| Navigation | `auto_route` |
| Animations | `flutter_animate` |
| Typography | `google_fonts` (Space Grotesk) |
| Links | `url_launcher` |

## Structure

```
lib/
  core/theme/       — Colors, text styles, theme
  core/routing/     — auto_route setup
  domain/           — Portfolio data, project & experience models
  feature/home/     — Main scrollable portfolio screen
  feature/projects/ — Project detail screen
  shared/ui/        — PressableScale, AnimatedReveal
```

## Running

```bash
# Mobile
flutter run

# Web (dev)
flutter run -d web-server --web-port 3000

# Web (release build)
flutter build web --release
```

## Contact

**wiam.okok@gmail.com**
