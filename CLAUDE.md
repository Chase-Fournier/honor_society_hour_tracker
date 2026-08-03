# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Wheeler NHS Hour Tracker (`nhs_tracker`) — a Flutter app for tracking National Honor Society volunteer hours. Members log hours, sign up for event time slots, and request swaps; admins manage events, attendance, hour requirements, meeting notes, and member rosters. The app is multi-tenant: a single user can belong to multiple "honor societies" and switch between them.

Backend is Supabase (Postgres + auth + RLS). There is no separate API layer — screens and providers call the shared `supabase` client (`lib/data/supabase_client.dart`) directly.

## Commands

```sh
flutter pub get              # install dependencies
flutter run                  # run on the selected device
flutter run -d chrome        # run as web
flutter analyze              # static analysis / lint
flutter test                 # run all tests
flutter test test/models/event_test.dart   # run a single test file

# Asset regeneration (after changing assets/nhsicon.png or nhs-logo-simple.png)
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Dart SDK: `^3.1.1`. Android `minSdkVersion` is 21.

### Tests

`flutter test` runs a real suite (`test/`) and CI enforces it
(`.github/workflows/ci.yml`). It is hermetic — no network, no live Supabase.

- `test/helpers/fake_supabase.dart` — `createFakeSupabase()` builds a **real**
  `SupabaseClient` over a fake HTTP transport (`MockClient`), installs it via
  `supabaseOverride`, and registers teardown. Assert on `fake.requests` to check
  the PostgREST query the app actually built. `seedSession` signs a user in
  offline. Prefer this over mocking the `PostgrestFilterBuilder` chain.
- `test/helpers/fixtures.dart` — builders for model objects and Supabase rows.
- `test/helpers/pump.dart` — `pumpWithProviders` / `pumpInScaffold` supply the
  provider stack every interactive widget expects.
- `test/flutter_test_config.dart` — runs before every test file. Disables
  GoogleFonts runtime fetching and stubs gaimon's method channel.

Two things to know when writing tests:

- **Providers do async work in their constructors.** Awaiting your own
  `load...()` is not enough; the constructor's call can resolve afterwards and
  clobber what you just set. Drain with `await Future<void>.delayed(Duration.zero)`.
- **`defaultTargetPlatform` is `android` under `flutter_test`**, so
  platform-gated code (e.g. `HapticsProvider`) takes its mobile path.

`flutter analyze` still reports ~641 pre-existing infos/warnings (deprecated
`withOpacity`, `surfaceVariant`, unused elements), so scope it to the files you
touched (`flutter analyze lib/screens/foo.dart`) and compare against that
baseline rather than expecting a clean run. CI gates on **errors** only
(`--no-fatal-infos --no-fatal-warnings`). Run `dart format` on files you rewrite.

## Architecture

### Entry point and routing (`lib/main.dart`)
- `Supabase.initialize` is called with the project URL/anon key hard-coded in `main()` — these are not env vars. If they need to change, edit `main.dart` directly.
- `MyApp` sets up a single `Navigator` via `_navigatorKey` with three named routes: `/` (login), `/society_selection`, `/reset-password`.
- Two long-lived stream subscriptions are wired in `_initApp`:
  - `supabase.auth.onAuthStateChange` — drives routing on sign-in/out.
  - `AppLinks().uriLinkStream` — handles deep links with custom scheme `com.wheelermun.nhs` (`reset-password` and `callback` hosts).
- `_isProcessingPasswordRecovery` is a guard flag: when a password-recovery deep link arrives it suppresses the normal sign-in navigation so `ResetPasswordPage` can take over. Any change to auth-event handling must preserve this gate.
- `lib/data/supabase_client.dart` exposes the canonical client as a lazy
  **getter** (`supabase`), used by every screen, provider and service. It is a
  getter rather than a top-level `final` on purpose: a `final` is evaluated at
  library load and throws before `Supabase.initialize()` has run, which made
  those files impossible to import from a test. Never reintroduce a top-level
  `final supabase = Supabase.instance.client;` — `test/screens/import_smoke_test.dart`
  guards against it. Tests swap the client via `supabaseOverride`.

### State management — Provider
Five `ChangeNotifier`s are registered at app start in `MultiProvider` in
`main()`. They are not lazy-instantiated; long-lived singletons. Note each one
starts async work (SharedPreferences, and for `SocietyProvider` a network load)
**in its constructor**, which races anything that reads it immediately after:

- `SocietyProvider` (`lib/providers/societyprovider.dart`) — **the central tenancy provider.** Loads `user_society_memberships` joined with `honor_societies` and `hour_requirements`, tracks `currentSociety`, `userSocieties`, and `isAdmin`. Most screens key off `currentSociety.id` for queries. Calling `loadUserSocieties()` is required after sign-in.
- `ThemeNotifier` — holds the user-picked seed `Color`, persisted under `themeColor` in `SharedPreferences`.
- `ThemeProvider` — holds the selected `ThemeMode` (light/dark/midnight + ~16 named themes like sunset, forest, galaxy). `getThemeData(seedColor)` produces the `ThemeData`; the seed color only applies to light/dark/midnight — the named themes use hard-coded `ColorScheme` definitions.
- `HapticsProvider` — wraps `gaimon` haptics with a toggle (`haptics_enabled` in SharedPreferences). Call `selection()`, `success()`, `error()`, etc. instead of `HapticFeedback.*` directly.
- `NotificationsProvider` — master switch plus per-category toggles (`notif_*` keys in SharedPreferences) and the reminder lead time. `shouldScheduleFor(category)` is the gate; the master switch vetoes every category.

### Screen layout
- `MainScreen` (`lib/screens/mainscreen.dart`) is the post-login shell. It branches on `SocietyProvider.isAdmin` to render a different set of tabs and pages:
  - Admin: Dashboard, Events, Attendance, Lists, Settings.
  - Member: Home, Completed Hours, Settings.
- Each tab is its own top-level screen under `lib/screens/`. There is no shared route table for them — they're swapped via `PageController`.
- **Responsive list screens** follow one pattern: `MediaQuery.of(context).size.width > 900` renders a spreadsheet-style table (fixed header row, tap-to-sort column headers with an arrow indicator, zebra rows); anything narrower renders a card list. `adminlistspage.dart` and `JoinRequestsAdmin.dart` both do this — copy from them rather than inventing a third layout.
- **Multi-select** on those screens swaps the whole app bar: a "browse" bar (sort / enter-selection / tools) becomes a contextual bar (close, "N selected", select-all, the bulk actions). Bulk operations issue one batched Supabase query with `.inFilter('id', ids)`, never a loop of single-row calls.

### Data layer
- **No repository / service layer.** Screens and providers issue Supabase queries inline. When changing a database column or join, expect to grep across multiple `.dart` files.
- Models in `lib/models/` are plain Dart classes with `fromJson` (and sometimes `toJson`) factories that map Supabase snake_case columns to camelCase fields. Examples: `Event`, `TimeSlot`, `HonorSociety`, `HourRequirement`, `UserProfile`, `SwapRequest`, `MeetingNote`, `ActivityLog`.
- Snake_case ↔ camelCase mapping happens manually in each `fromJson` — be careful when adding fields.
- Schema changes live in `supabase/migrations/` (timestamp-prefixed SQL, applied with `supabase db push`); edge functions live in `supabase/functions/`. Tables predating that folder — `profiles`, `society_join_requests`, `user_society_memberships`, `Notes` — have no migration on disk, so their columns and RLS policies can only be confirmed against the live project. When a write might be refused by RLS, chain `.select()` onto it and compare the returned rows to what you asked for; a blocked Supabase write otherwise looks like success.

### Common UI primitives (`lib/common/`)
- `app_design.dart` — design tokens: `AppDesign.radiusMedium`, `paddingMedium`, `spacingM`, `elevationSmall`, etc. Use these instead of hardcoding magic numbers.
- `app_theme.dart` / `app_widgets.dart` — shared widgets like `AppCard` that wrap Material widgets with the design tokens and pull colors from `Theme.of(context).colorScheme`.
- `customnavigationbar.dart` — abstraction layer over the three nav-bar packages so `MainScreen` doesn't care which one is active.
- `iconutils.dart`, `nhsformatutils.dart`, `normalizetype.dart` — helpers for icon name → `IconData` mapping, formatting hours/dates, and normalizing the `type` field on events/requirements.
- `graduationyearutils.dart` — the single source for the graduation-year rule (a rolling window anchored on the current year) and its `TextFormField` validator. Both the signup form (`loginpage.dart`) and account settings use it; change the bounds here, not at the call sites.

### One-off top-level files in `lib/`
- `snake.dart` — the bundled Snake mini-game (49KB, self-contained). Not part of the main flow.
- `exporttoexcel.dart` — Excel report generation via the `excel` package.
- `bulkediteventspage.dart` — admin bulk-edit screen kept at the top level rather than under `screens/` (historical).
- `updateattendence.dart` — small attendance helper.

## Design language

`lib/screens/adminattendencepage.dart` is the agreed reference look. The recipes
(R1–R8) are: `bannerTheme` app bar, Material `FilterChip`
filters, flat `elevation: 0` cards with a hairline `outlineVariant` border and a
soft shadow (`AppContentCard`), tinted grouping cards (`AppGroupingCard`),
centered icon+headline empty states, and no hardcoded `Colors.*`. Prefer the
shared widgets in `app_widgets.dart` over hand-rolling a `Container`. Not every
screen follows this yet — compare against `adminattendencepage.dart` before
restyling anything.

## Conventions to follow

- **Always go through `SocietyProvider`** for the current society/admin flag rather than re-querying memberships. If state seems stale, call `loadUserSocieties()`.
- **Use design tokens.** Read radii, spacing, and elevation from `AppDesign` (`lib/common/app_design.dart`). Pull colors from `Theme.of(context).colorScheme` — do not hardcode hex values in screens; the themed `ColorScheme` is what makes the 19 themes work.
- **Use `HapticsProvider`** for any haptic feedback so user toggles are respected.
- **Custom URL scheme is `com.wheelermun.nhs`** — used for password-reset and auth callback deep links. Any new deep link must be routed through `_handleDeepLink` in `main.dart` and added to platform configs (`AndroidManifest.xml`, `Info.plist`).
- **Localizations.** Only `en_US` is supported. `FlutterQuillLocalizations.delegate` must remain in `MaterialApp.localizationsDelegates` — rich-text editing (`flutter_quill`) will crash without it.
- **Supabase keys live in `main.dart`.** The anon key is checked into the repo by design (it's the public anon key) — do not move it to env vars without coordinating with the deploy/CI story.
