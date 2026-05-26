# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Wheeler NHS Hour Tracker (`nhs_tracker`) — a Flutter app for tracking National Honor Society volunteer hours. Members log hours, sign up for event time slots, and request swaps; admins manage events, attendance, hour requirements, meeting notes, and member rosters. The app is multi-tenant: a single user can belong to multiple "honor societies" and switch between them.

Backend is Supabase (Postgres + auth + RLS). There is no separate API layer — screens and providers call `Supabase.instance.client` directly.

## Commands

```sh
flutter pub get              # install dependencies
flutter run                  # run on the selected device
flutter run -d chrome        # run as web
flutter analyze              # static analysis / lint
flutter test                 # run all tests
flutter test test/widget_test.dart   # run a single test file

# Asset regeneration (after changing assets/nhsicon.png or nhs-logo-simple.png)
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Dart SDK: `^3.1.1`. Android `minSdkVersion` is 21.

## Architecture

### Entry point and routing (`lib/main.dart`)
- `Supabase.initialize` is called with the project URL/anon key hard-coded in `main()` — these are not env vars. If they need to change, edit `main.dart` directly.
- `MyApp` sets up a single `Navigator` via `_navigatorKey` with three named routes: `/` (login), `/society_selection`, `/reset-password`.
- Two long-lived stream subscriptions are wired in `_initApp`:
  - `supabase.auth.onAuthStateChange` — drives routing on sign-in/out.
  - `AppLinks().uriLinkStream` — handles deep links with custom scheme `com.wheelermun.nhs` (`reset-password` and `callback` hosts).
- `_isProcessingPasswordRecovery` is a guard flag: when a password-recovery deep link arrives it suppresses the normal sign-in navigation so `ResetPasswordPage` can take over. Any change to auth-event handling must preserve this gate.
- `final supabase = Supabase.instance.client;` at the bottom of `main.dart` is the canonical client reference imported throughout the app.

### State management — Provider
Five `ChangeNotifier`s are registered at app start in `MultiProvider`. They are not lazy-instantiated; long-lived singletons:

- `SocietyProvider` (`lib/providers/societyprovider.dart`) — **the central tenancy provider.** Loads `user_society_memberships` joined with `honor_societies` and `hour_requirements`, tracks `currentSociety`, `userSocieties`, and `isAdmin`. Most screens key off `currentSociety.id` for queries. Calling `loadUserSocieties()` is required after sign-in.
- `ThemeNotifier` — holds the user-picked seed `Color`, persisted under `themeColor` in `SharedPreferences`.
- `ThemeProvider` — holds the selected `ThemeMode` (light/dark/midnight + ~16 named themes like sunset, forest, galaxy). `getThemeData(seedColor)` produces the `ThemeData`; the seed color only applies to light/dark/midnight — the named themes use hard-coded `ColorScheme` definitions.
- `HapticsProvider` — wraps `gaimon` haptics with a toggle (`haptics_enabled` in SharedPreferences). Call `selection()`, `success()`, `error()`, etc. instead of `HapticFeedback.*` directly.
- `NavigationProvider` — switches between `google` / `circle` / `floating` bottom nav variants (see `lib/common/customnavigationbar.dart`); persisted as `navigation_bar_type` index.

### Screen layout
- `MainScreen` (`lib/screens/mainscreen.dart`) is the post-login shell. It branches on `SocietyProvider.isAdmin` to render a different set of tabs and pages:
  - Admin: Dashboard, Events, Attendance, Lists, Settings.
  - Member: Home, Completed Hours, Settings.
- Each tab is its own top-level screen under `lib/screens/`. There is no shared route table for them — they're swapped via `PageController`.

### Data layer
- **No repository / service layer.** Screens and providers issue Supabase queries inline. When changing a database column or join, expect to grep across multiple `.dart` files.
- Models in `lib/models/` are plain Dart classes with `fromJson` (and sometimes `toJson`) factories that map Supabase snake_case columns to camelCase fields. Examples: `Event`, `TimeSlot`, `HonorSociety`, `HourRequirement`, `UserProfile`, `SwapRequest`, `MeetingNote`, `ActivityLog`.
- Snake_case ↔ camelCase mapping happens manually in each `fromJson` — be careful when adding fields.

### Common UI primitives (`lib/common/`)
- `app_design.dart` — design tokens: `AppDesign.radiusMedium`, `paddingMedium`, `spacingM`, `elevationSmall`, etc. Use these instead of hardcoding magic numbers.
- `app_theme.dart` / `app_widgets.dart` — shared widgets like `AppCard` that wrap Material widgets with the design tokens and pull colors from `Theme.of(context).colorScheme`.
- `customnavigationbar.dart` — abstraction layer over the three nav-bar packages so `MainScreen` doesn't care which one is active.
- `iconutils.dart`, `nhsformatutils.dart`, `normalizetype.dart` — helpers for icon name → `IconData` mapping, formatting hours/dates, and normalizing the `type` field on events/requirements.

### One-off top-level files in `lib/`
- `snake.dart` — the bundled Snake mini-game (49KB, self-contained). Not part of the main flow.
- `exporttoexcel.dart` — Excel report generation via the `excel` package.
- `bulkediteventspage.dart` — admin bulk-edit screen kept at the top level rather than under `screens/` (historical).
- `updateattendence.dart` — small attendance helper.

## Conventions to follow

- **Always go through `SocietyProvider`** for the current society/admin flag rather than re-querying memberships. If state seems stale, call `loadUserSocieties()`.
- **Use design tokens.** Read radii, spacing, and elevation from `AppDesign` (`lib/common/app_design.dart`). Pull colors from `Theme.of(context).colorScheme` — do not hardcode hex values in screens; the themed `ColorScheme` is what makes the 19 themes work.
- **Use `HapticsProvider`** for any haptic feedback so user toggles are respected.
- **Custom URL scheme is `com.wheelermun.nhs`** — used for password-reset and auth callback deep links. Any new deep link must be routed through `_handleDeepLink` in `main.dart` and added to platform configs (`AndroidManifest.xml`, `Info.plist`).
- **Localizations.** Only `en_US` is supported. `FlutterQuillLocalizations.delegate` must remain in `MaterialApp.localizationsDelegates` — rich-text editing (`flutter_quill`) will crash without it.
- **Supabase keys live in `main.dart`.** The anon key is checked into the repo by design (it's the public anon key) — do not move it to env vars without coordinating with the deploy/CI story.
