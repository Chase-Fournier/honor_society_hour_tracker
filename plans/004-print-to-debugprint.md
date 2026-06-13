# Plan 004: Replace `print()` with `debugPrint()` across the app

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/`
> Written against the working tree at `a3682db` plus uncommitted changes. This is
> a repo-wide mechanical change; if many files have shifted, re-run the grep in
> Step 1 to get the current file list before editing.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: Plans 001, 002, 003 should land first (they edit
  `homescreenpage.dart`/`completedhourspage.dart`, which also contain `print`s —
  doing those first avoids re-touching the same lines).
- **Category**: dx
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

There are ~70 `print(...)` calls in `lib/`. `print` writes to stdout in **release
builds** too (PII/operational data leakage, noise, and a small perf cost), and
the repo's own lint config (`flutter_lints`, which enables `avoid_print`) flags
every one — so `flutter analyze` is full of avoidable `info` lints that bury real
warnings. The codebase already standardized on `debugPrint` in
`lib/services/notification_service.dart`, which is throttled and **compiled out
of release** via `kReleaseMode` checks inside Flutter. This plan makes logging
consistent and clears the lint noise so future analyze runs are signal.

## Current state

- ~70 `print(` call sites across `lib/` (providers, screens, services, helpers).
  Get the live list with the grep in Step 1.
- `lib/services/notification_service.dart` already uses `debugPrint(...)` — this
  is the convention to match.
- `debugPrint` comes from `package:flutter/foundation.dart`. Files that import
  `package:flutter/material.dart` already have it transitively; pure Dart files
  (some providers/helpers) may need an explicit import.

Example of the pattern to change (representative — there are ~70):

```dart
    } catch (e) {
      print('Error fetching data: $e');
    }
```

becomes:

```dart
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| List print sites | `grep -rln "print(" lib --include="*.dart"` | the set of files to edit |
| Count remaining | `grep -rn "\bprint(" lib --include="*.dart" \| grep -v debugPrint \| wc -l` | `0` at the end |
| Analyze (gate) | `flutter analyze` (whole project) | far fewer `avoid_print` infos; **no new** errors/warnings |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` | — |

> **Verification reality**: no test suite exists. The gate is `flutter analyze`
> plus the grep counts below. This change is semantics-preserving (logging only),
> so analyze + greps are sufficient.

## Scope

**In scope**:
- Every file under `lib/` that contains a bare `print(` call (from the Step 1 list).

**Out of scope**:
- `debugPrint` calls that already exist — leave them.
- `lib/snake.dart` — the bundled mini-game; if it contains `print`s, you may
  convert them for consistency, but do not otherwise modify game logic.
- Any change to error *handling* (adding snackbars, rethrowing, etc.) — this plan
  only swaps the logging primitive. Behavioral error-handling improvements are a
  separate, deferred effort (see Maintenance).
- The `supabase/` directory (TypeScript/SQL) — `print` there is unrelated.

## Git workflow

- Branch: `advisor/004-print-to-debugprint`
- One commit (mechanical change), subject e.g. `Replace print with debugPrint`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Enumerate the files

Run `grep -rln "print(" lib --include="*.dart"`. This is your work list. Note
that the match also catches `debugPrint(` — you only convert **bare** `print(`.

### Step 2: Convert bare `print(` → `debugPrint(`

For each file in the list, replace bare `print(` with `debugPrint(`. Do not
touch existing `debugPrint(` calls. A safe per-file approach is a literal
replace of the token `print(` → `debugPrint(` **only where not already preceded
by `debug`** (i.e. don't produce `debugdebugPrint`). If your tooling can't
express that, edit occurrences individually.

**Verify (per file or at the end)**:
`grep -rn "\bprint(" lib --include="*.dart" | grep -v debugPrint` → no matches.

### Step 3: Add the foundation import where `debugPrint` is undefined

Run `flutter analyze`. For any file now reporting `Undefined name 'debugPrint'`
or `The function 'debugPrint' isn't defined`, add at the top with the other
imports:

```dart
import 'package:flutter/foundation.dart';
```

Re-run analyze until no such errors remain. (Most screen files import
`material.dart` and won't need this; some providers/helpers will.)

**Verify**: `flutter analyze` → zero `debugPrint`-undefined errors.

### Step 4: Final analyze

**Verify**: `flutter analyze` completes with **no new errors/warnings** and a
visibly reduced number of `avoid_print` infos compared to before (ideally zero
`avoid_print`).

## Test plan

No automated harness. This is a logging-primitive swap with no behavioral
change; verification is the grep counts (Step 2) and `flutter analyze` (Steps
3–4). No new tests.

## Done criteria

ALL must hold:

- [ ] `grep -rn "\bprint(" lib --include="*.dart" | grep -v debugPrint` returns no matches
- [ ] `flutter analyze` reports no `avoid_print` lints from `lib/`
- [ ] `flutter analyze` introduces no new errors/warnings vs. before the change
- [ ] No files outside the Step 1 list (plus any `foundation.dart` import additions) are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- After the swap, `flutter analyze` shows errors that aren't a missing
  `foundation.dart` import (something else is going on).
- You find `print` used to produce **user-facing program output** (not logging)
  — e.g. a CLI-style tool path. `debugPrint` would suppress it in release.
  (Unlikely in a Flutter UI app, but stop if you see it.)
- The replace accidentally produces `debugdebugPrint(` anywhere.

## Maintenance notes

- This plan deliberately does **not** improve error *handling* — there are ~126
  `catch (e)` blocks, many of which only log. Turning the dangerous ones into
  user-visible errors or wiring a crash reporter (e.g. Sentry/Firebase
  Crashlytics — `firebase_core` is already a dependency) is a worthwhile,
  separate follow-up.
- Going forward, keep `avoid_print` clean: new code should use `debugPrint` (or a
  real logger if one is introduced). A reviewer should reject new `print(` calls.
