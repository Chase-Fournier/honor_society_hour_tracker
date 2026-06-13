# Plan 001: Service-hour totals never crash on a null `hours` value

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/completedhourspage.dart lib/screens/homescreenpage.dart`
> This plan was written against the working tree at commit `a3682db` **plus
> uncommitted changes**. If the excerpts in "Current state" below don't match
> the live code, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

Two hot code paths compute a member's completed hours with the expression
`entry['hours'] + 0.0 ?? 0.0`. In Dart, `+` binds tighter than `??`, so this
parses as `(entry['hours'] + 0.0) ?? 0.0`. If `entry['hours']` is ever `null`
(a nullable column, a row written without hours), `null + 0.0` throws a
`NoSuchMethodError` **before** the `?? 0.0` can apply — the `?? 0.0` fallback is
dead code. The throw lands in the surrounding `catch`, so the member's hours
total and home-screen progress bars silently fail to load. The fix makes the
fallback actually work and removes the dead arithmetic.

## Current state

- `lib/screens/completedhourspage.dart` — member's completed-hours screen.
  Loops over `Service hours` rows to sum totals.
- `lib/screens/homescreenpage.dart` — home screen; `_fetchCompletedHours`
  builds the progress-bar totals the same way.

Excerpt — `lib/screens/completedhourspage.dart:136`:

```dart
      // Process completed hours
      for (final entry in data) {
        final hours = entry['hours'] + 0.0 ?? 0.0;
```

Excerpt — `lib/screens/homescreenpage.dart:235`:

```dart
        // Process completed hours
        for (final entry in data) {
          final hours = entry['hours'] + 0.0 ?? 0.0;
```

Convention: this repo reads Supabase JSON as `dynamic` and coerces with casts
like `entry['event_name'] as String? ?? 'Unknown Event'` (see the line directly
below each excerpt). Match that style — cast to a nullable `num`, then default.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze (gate) | `flutter analyze lib/screens/completedhourspage.dart lib/screens/homescreenpage.dart` | No **new** errors/warnings introduced by this change |
| Flutter binary | If `flutter` is not on PATH, it is at `/Users/cfournier/Flutter SDK/flutter/bin/flutter` (path contains a space — quote it) | — |

> **Note on verification**: this repo has **no working test suite**
> (`test/widget_test.dart` is empty) and no CI. `flutter analyze` is the only
> automated gate. The file already emits some pre-existing `info`-level lints
> (e.g. `avoid_print`); those are acceptable. The bar is: **your change adds no
> new errors or warnings.**

## Scope

**In scope** (the only files you should modify):
- `lib/screens/completedhourspage.dart`
- `lib/screens/homescreenpage.dart`

**Out of scope** (do NOT touch):
- Any other `entry[...]` coercions in these loops — only the `hours` line changes.
- The `Service hours` table / model. The fix is purely client-side defensive parsing.

## Git workflow

- Branch: `advisor/001-fix-hours-null-precedence`
- One commit. Recent history uses short imperative subjects (e.g. "Smaller Changes", "UI tweaks for consistancy"); match that style, e.g. `Fix null-hours precedence in hour totals`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix the `completedhourspage.dart` site

Replace exactly this line (at `completedhourspage.dart:136`):

```dart
        final hours = entry['hours'] + 0.0 ?? 0.0;
```

with:

```dart
        final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
```

**Verify**: `grep -n "+ 0.0 ?? 0.0" lib/screens/completedhourspage.dart` → no matches.

### Step 2: Fix the `homescreenpage.dart` site

Replace exactly this line (at `homescreenpage.dart:235`):

```dart
          final hours = entry['hours'] + 0.0 ?? 0.0;
```

with:

```dart
          final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
```

**Verify**: `grep -rn "+ 0.0 ?? 0.0" lib/` → no matches across the whole `lib/` tree.

### Step 3: Analyze

**Verify**: `flutter analyze lib/screens/completedhourspage.dart lib/screens/homescreenpage.dart` → no new errors/warnings (pre-existing `info` lints are fine).

## Test plan

No automated test harness exists, so this is manual:

- There is nothing new to unit-test without first building a test baseline (out
  of scope here). If a `Service hours` model or test helper is later added,
  add a case where `hours` is `null` and assert the total is `0.0`, not a throw.
- **Manual smoke** (optional, requires a configured device + Supabase): open the
  Completed Hours screen and the Home screen for a member who has logged hours;
  confirm totals render. This is unchanged behavior for non-null data; the fix
  only affects the null case.

## Done criteria

ALL must hold:

- [ ] `grep -rn "+ 0.0 ?? 0.0" lib/` returns no matches
- [ ] Both `hours` lines read `(entry['hours'] as num?)?.toDouble() ?? 0.0`
- [ ] `flutter analyze lib/screens/completedhourspage.dart lib/screens/homescreenpage.dart` introduces no new errors/warnings
- [ ] `git status` shows only the two in-scope files modified
- [ ] `plans/README.md` status row updated to DONE

## STOP conditions

Stop and report back if:

- The `+ 0.0 ?? 0.0` expression is not present at the cited lines (code drifted).
- `flutter` cannot be located or run at all — report so the operator can run analyze.
- Analyze reports a **new** error after the edit that a one-line fix doesn't resolve.

## Maintenance notes

- The same nullable-coercion pattern appears throughout these JSON-parsing
  loops; if you see other `dynamic + literal` arithmetic on Supabase rows,
  it has the same latent precedence trap. Out of scope here but worth a sweep later.
- A reviewer should confirm the cast is `as num?` (not `as double?`) — Supabase
  returns integer columns as `int`, which is a `num` but not a `double`, so
  `as double?` would throw on integer hours.
