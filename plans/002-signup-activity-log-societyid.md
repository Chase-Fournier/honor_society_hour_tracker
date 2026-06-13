# Plan 002: Signup activity-log rows carry their `society_id`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/homescreenpage.dart`
> Written against the working tree at `a3682db` plus uncommitted changes. If the
> excerpts below don't match the live code, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

`logactivity(...)` takes an optional named `societyId` and writes it to
`activity_logs.society_id`. The **unsignup** and **swap** calls pass it, but the
**signup** call does not — so every "signup" audit row is written with
`society_id: null`. Any per-society view, filter, or report over `activity_logs`
silently drops signups, making the activity log inconsistent and society-scoped
analytics wrong. This is a one-argument fix that aligns signup with the
sibling calls.

## Current state

- `lib/models/logactivity.dart` — defines `logactivity`; signature ends with
  optional named params `{String? oldUserId, String? newUserId, int? societyId}`
  and inserts `'society_id': societyId` into `activity_logs`.
- `lib/screens/homescreenpage.dart` — the home screen owns signup/unsignup.

The current society is obtained the same way throughout this file:

```dart
final society =
    Provider.of<SocietyProvider>(context, listen: false).currentSociety;
```

**Unsignup already does it right** — excerpt around `homescreenpage.dart:2413`:

```dart
        await logactivity(
          event.name,
          '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
          NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
          'unsignup',
          userId,
          societyId: society?.id,
        );
```

**Signup is missing it** — excerpt at `homescreenpage.dart:2520-2526`:

```dart
          await logactivity(
            event.name,
            '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
            NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
            'signup',
            userId,
          );
```

Important: in `_signUpForTimeSlot`, a `society` local already exists earlier in
the method (it is read to evaluate requirements). Confirm it is in scope at the
`logactivity` call before reusing it — see Step 1.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze (gate) | `flutter analyze lib/screens/homescreenpage.dart` | No new errors/warnings |
| Flutter binary | If `flutter` not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` (quote the space) | — |

> **Note**: no test suite exists (`test/widget_test.dart` is empty); `flutter
> analyze` is the only automated gate. Pre-existing `info` lints are acceptable.

## Scope

**In scope**:
- `lib/screens/homescreenpage.dart`

**Out of scope**:
- `lib/models/logactivity.dart` — signature already supports `societyId`; do not change it.
- The unsignup/swap calls — already correct.

## Git workflow

- Branch: `advisor/002-signup-activity-log-societyid`
- One commit, short imperative subject, e.g. `Pass societyId on signup activity log`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Confirm the `society` local is in scope at the signup `logactivity` call

Open `_signUpForTimeSlot` in `lib/screens/homescreenpage.dart`. Near the top of
the method body there is a `final society = Provider.of<SocietyProvider>(...)
.currentSociety;` used for requirement checks. Confirm that same `society`
variable is visible (not shadowed, not out of an inner block) at the `'signup'`
`logactivity` call at line ~2520.

- If `society` IS in scope there → use it (`societyId: society?.id`).
- If it is NOT in scope there (declared inside an inner block) → STOP and report;
  do not redeclare a second `society` without confirming the surrounding structure.

### Step 2: Add the `societyId` argument to the signup call

Change the signup `logactivity` call to:

```dart
          await logactivity(
            event.name,
            '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
            NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
            'signup',
            userId,
            societyId: society?.id,
          );
```

**Verify**: `grep -n "'signup'" lib/screens/homescreenpage.dart` shows the call,
and the following lines now include `societyId: society?.id,`.

### Step 3: Analyze

**Verify**: `flutter analyze lib/screens/homescreenpage.dart` → no new errors/warnings.

## Test plan

No automated harness. Manual verification (optional, needs device + Supabase):
sign up for a time slot, then inspect the newest `activity_logs` row with
`action_type = 'signup'` and confirm `society_id` is populated (not null).

## Done criteria

ALL must hold:

- [ ] The `'signup'` `logactivity` call passes `societyId: society?.id`
- [ ] `flutter analyze lib/screens/homescreenpage.dart` introduces no new errors/warnings
- [ ] `git status` shows only `lib/screens/homescreenpage.dart` modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- The signup `logactivity` call is not present / already passes `societyId` (drift).
- `society` is not in scope at the call site (see Step 1) — needs human judgment on structure.

## Maintenance notes

- If a new activity type is added, ensure its `logactivity` call also passes
  `societyId` — the optional param makes it easy to forget. A reviewer should
  check every `logactivity(` call site passes it.
