# Contributing to Wheeler NHS Tracker

First off — thank you for taking the time to contribute! 🎉 This project helps National Honor Society members and administrators track volunteer hours, and every improvement makes it better for the chapters that rely on it.

This guide explains how to set up the project, the conventions we follow, and how to get your changes merged. If anything here is unclear, please [open an issue](https://github.com/Chase-Fournier/wheeler_nhs/issues) and we'll improve the docs.

## Code of conduct

Be kind, be constructive, and assume good intent. We want this to be a welcoming project for first-time contributors and students. Harassment or dismissive behavior toward other contributors isn't tolerated.

## Ways to contribute

You don't have to write code to help:

* **Report a bug** — open an issue describing what happened, what you expected, and steps to reproduce.
* **Suggest a feature** — open an issue explaining the problem you're trying to solve.
* **Improve documentation** — fixes to the README, this guide, or in-code comments are very welcome.
* **Write code** — pick up an open issue or propose a change (see below).

## Project at a glance

* **Frontend:** Flutter (Dart SDK `^3.1.1`, Android `minSdkVersion` 21).
* **Backend:** Supabase (Postgres + auth + row-level security). There is **no separate API layer** — screens and providers call `Supabase.instance.client` directly.
* **State management:** [Provider](https://pub.dev/packages/provider). Long-lived `ChangeNotifier`s are registered at app start; `SocietyProvider` is the central multi-tenancy provider.
* **Multi-tenant:** a user can belong to multiple honor societies and switch between them.

For a deeper architectural tour, read [`CLAUDE.md`](CLAUDE.md) — it documents the entry point, routing, providers, screen layout, and data layer in detail.

## Setting up your environment

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install) on your `PATH`
* A code editor — [VS Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio)
* A [Supabase](https://supabase.com/) account and project (the app needs a backend to run against)

### First-time setup

1. **Fork** this repository on GitHub, then clone your fork:
   ```sh
   git clone https://github.com/<your-username>/wheeler_nhs.git
   cd wheeler_nhs
   ```
2. **Add the upstream remote** so you can stay in sync:
   ```sh
   git remote add upstream https://github.com/Chase-Fournier/wheeler_nhs.git
   ```
3. **Install dependencies:**
   ```sh
   flutter pub get
   ```
4. **Configure Supabase.** Update the project URL and anon key in `lib/main.dart` (see the [Configuration section of the README](README.md#️-configuration)). The anon key is a public client key — security is enforced by row-level security (RLS) on the database, so make sure RLS is enabled on every table in your Supabase project.
5. **Run the app:**
   ```sh
   flutter run            # on the selected device
   flutter run -d chrome  # in the browser
   ```

## Development workflow

1. **Sync** your fork with upstream before starting:
   ```sh
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```
2. **Create a branch** off `main` for your change:
   ```sh
   git checkout -b feature/short-description
   ```
   Use a prefix that fits the work: `feature/`, `fix/`, `docs/`, or `refactor/`.
3. **Make focused commits** with clear, descriptive messages. Prefer several small commits over one giant one.
4. **Check your work** before pushing (see [Before you submit](#before-you-submit)).
5. **Push** to your fork and open a pull request.

## Coding conventions

These keep the codebase consistent across the app's 19 themes and multi-tenant model. They mirror the rules in [`CLAUDE.md`](CLAUDE.md):

* **Go through `SocietyProvider`** for the current society and admin flag — don't re-query memberships. If state seems stale, call `loadUserSocieties()`.
* **Use design tokens.** Pull radii, spacing, and elevation from `AppDesign` (`lib/common/app_design.dart`) instead of hardcoding numbers.
* **Pull colors from `Theme.of(context).colorScheme`** — never hardcode hex values in screens. The themed `ColorScheme` is what makes every theme work.
* **Use `HapticsProvider`** (`selection()`, `success()`, `error()`, …) for haptics instead of calling `HapticFeedback.*` directly, so user toggles are respected.
* **Model mapping is manual.** Models in `lib/models/` map Supabase `snake_case` columns to `camelCase` fields in their `fromJson`/`toJson`. When adding a field, update the mapping carefully.
* **No repository/service layer.** Supabase queries live inline in screens and providers. If you change a column or join, expect to grep across multiple `.dart` files.
* **Deep links** use the custom scheme `com.wheelermun.nhs`. Any new deep link must be routed through `_handleDeepLink` in `lib/main.dart` and registered in the platform configs (`AndroidManifest.xml`, `Info.plist`).
* **Localization** is `en_US` only. Keep `FlutterQuillLocalizations.delegate` in `MaterialApp.localizationsDelegates` — rich-text editing crashes without it.

## Before you submit

Run these and make sure they pass:

```sh
flutter analyze        # static analysis / lint — should report no issues
flutter test           # run the test suite
```

If you changed assets (`assets/nhsicon.png` or `nhs-logo-simple.png`), regenerate the derived files:

```sh
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Please don't commit build artifacts or local state — `android/app/.cxx/`, `supabase/.temp/`, `.dart_tool/`, and `/build/` are gitignored for a reason. Never commit secrets such as a signing keystore, `key.properties`, or a Supabase service-role key.

## Opening a pull request

* Target the `main` branch of `Chase-Fournier/wheeler_nhs`.
* Give the PR a clear title and describe **what** changed and **why**. Link any related issue (e.g. `Closes #123`).
* Include screenshots or a short clip for UI changes — it makes review much faster.
* Keep PRs focused. If you find unrelated cleanup, consider a separate PR.
* Make sure `flutter analyze` and `flutter test` pass.

A maintainer will review your PR, may ask for changes, and will merge it once it's ready. Thanks again for contributing! 💙
