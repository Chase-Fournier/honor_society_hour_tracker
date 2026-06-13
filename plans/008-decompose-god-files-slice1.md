# Plan 008: Begin decomposing the god-files — extract home progress bars (slice 1)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise. This
> plan is the **first slice** of a larger decomposition; do ONLY what's in Scope,
> then update `plans/README.md`. Do not attempt to split the rest of the file.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/homescreenpage.dart`
> Written against the working tree at `a3682db` plus uncommitted changes. Because
> Plans 001–007 also edit `homescreenpage.dart`, **run this plan LAST**, after
> they've landed. Re-locate the builders with the greps below before editing; on
> structural mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: M (this slice; the full decomposition is L and ongoing)
- **Risk**: MED
- **Depends on**: Plans 001, 002, 003, 006, 007 (all edit `homescreenpage.dart`).
  Land this **after** them to avoid conflicts.
- **Category**: tech-debt
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

Three screen files are an order of magnitude larger than the repo median:
`adminlistspage.dart` (~3900 lines), `admineventspage.dart` (~3560),
`homescreenpage.dart` (~2840). They're hard to navigate, review, and test, and
they're merge-conflict magnets (every recent feature touched them). The fix is
**incremental extraction**, not a big-bang rewrite. This plan does one safe,
high-confidence slice — moving the two self-contained progress-bar card builders
out of `homescreenpage.dart` into a reusable `lib/common/` file — to shrink the
worst offender and establish the pattern for future slices. The repo already has
this pattern: `TodaysEventsSection` is a standalone widget at the bottom of
`adminattendencepage.dart`, and `lib/common/` holds shared UI helpers
(`app_widgets.dart`, `app_design.dart`).

## Current state

In `lib/screens/homescreenpage.dart`:

- `_buildProgressBars()` (line ~878) — reads state maps (`_requirementMap`,
  `_completedHoursMap`, `_potentialHoursMap`, `_meetingRequirement`) and calls the
  two card builders. **Stays in the file.**
- `_buildDoubleProgressBar(BuildContext context, String title, double
  completedHours, double potentialHours, int hoursNeeded)` (line ~899) — **fully
  parameterized / pure** (no `this.`/state access; only its params + `Theme` +
  `AppDesign` + `getIconForType`). ~175 lines.
- `_buildMeetingProgressBar(BuildContext context, double completedHours, int
  hoursNeeded)` (line ~1077) — pure **except** it computes `meetingsLeft`
  internally as `_events.where((event) => event.type == 'Meeting').length`. ~150
  lines.

These builders use: `AppDesign` (`lib/common/app_design.dart`), `getIconForType`
(`lib/common/iconutils.dart`), and Flutter material widgets — all importable into
a new file.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Locate builders | `grep -n "_buildProgressBars\|_buildDoubleProgressBar\|_buildMeetingProgressBar" lib/screens/homescreenpage.dart` | the lines above |
| Analyze (gate) | `flutter analyze lib/screens/homescreenpage.dart lib/common/progress_bars.dart` | No new errors/warnings |
| Line count before/after | `wc -l lib/screens/homescreenpage.dart` | smaller after |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` | — |

> **Verification reality**: no test suite. Gate is `flutter analyze`. This is a
> pure code-move (no behavior change), so analyze + the line-count drop + a visual
> check that the home screen still renders progress bars is the bar.

## Scope

**In scope**:
- `lib/common/progress_bars.dart` (create)
- `lib/screens/homescreenpage.dart` (move two methods out; keep `_buildProgressBars`)

**Out of scope** (do NOT do in this plan):
- `adminlistspage.dart` and `admineventspage.dart` — later slices.
- Any other builder in `homescreenpage.dart` (event card, time-slot items, swap
  cards, continuous-event cards) — they depend on state/`setState` and are
  riskier; deferred.
- Changing any rendering, colors, animations, or behavior. This is a move only.

## Git workflow

- Branch: `advisor/008-extract-home-progress-bars`
- One commit, subject e.g. `Extract home progress-bar widgets to lib/common`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Create `lib/common/progress_bars.dart`

Create the file with two top-level functions. Copy the **bodies** of
`_buildDoubleProgressBar` and `_buildMeetingProgressBar` verbatim from
`homescreenpage.dart`, with these changes:

- Rename to top-level `buildDoubleProgressBar(...)` / `buildMeetingProgressBar(...)`.
- `buildMeetingProgressBar` gains a `required int meetingsLeft` parameter, and
  inside its body **replace** the line that computes
  `_events.where((event) => event.type == 'Meeting').length` with use of the
  `meetingsLeft` parameter (delete the local `_events` lookup).

Skeleton:

```dart
import 'package:flutter/material.dart';
import 'app_design.dart';
import 'iconutils.dart';

/// Completed + potential hours bar for one requirement type.
/// Pure: all inputs are parameters. Extracted from HomePage.
Widget buildDoubleProgressBar(BuildContext context, String title,
    double completedHours, double potentialHours, int hoursNeeded) {
  // <-- paste the original _buildDoubleProgressBar body verbatim -->
}

/// Meeting-attendance progress bar.
/// `meetingsLeft` is passed in (originally derived from the events list).
Widget buildMeetingProgressBar(BuildContext context, double completedHours,
    int hoursNeeded, {required int meetingsLeft}) {
  // <-- paste the original _buildMeetingProgressBar body verbatim,
  //     but use `meetingsLeft` instead of recomputing from _events -->
}
```

**Verify**: `flutter analyze lib/common/progress_bars.dart` → resolves (it may
report "unused" until Step 3 wires it; no *errors*).

### Step 2: Delete the two methods from `homescreenpage.dart`

Remove `_buildDoubleProgressBar` (~899) and `_buildMeetingProgressBar` (~1077)
from `homescreenpage.dart` entirely. Keep `_buildProgressBars()`.

### Step 3: Point `_buildProgressBars` at the extracted functions

Add the import at the top of `homescreenpage.dart`:

```dart
import '../common/progress_bars.dart';
```

In `_buildProgressBars()`, change the two calls:

- `_buildDoubleProgressBar(context, type, completedHours, potentialHours, hoursNeeded.floor())`
  → `buildDoubleProgressBar(context, type, completedHours, potentialHours, hoursNeeded.floor())`
- The meeting call — compute `meetingsLeft` here (where `_events` is in scope) and
  pass it:

```dart
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    final meetingsLeft =
        _events.where((event) => event.type == 'Meeting').length;
    progressBars.add(buildMeetingProgressBar(
        context, meetingHours, _meetingRequirement,
        meetingsLeft: meetingsLeft));
```

**Verify**:
- `grep -n "_buildDoubleProgressBar\|_buildMeetingProgressBar" lib/screens/homescreenpage.dart` → no matches (only the extracted, renamed versions are referenced).
- `flutter analyze lib/screens/homescreenpage.dart lib/common/progress_bars.dart` → no new errors/warnings.

### Step 4: Confirm the file shrank

**Verify**: `wc -l lib/screens/homescreenpage.dart` is ~300 lines smaller than
before this plan.

## Test plan

No automated harness. This is a pure move; verification:
- `flutter analyze` clean (Steps 1–3).
- Manual: open the Home screen; the requirement progress bars and the meeting
  progress bar render identically (same numbers, same "Upcoming: N" / "Complete"
  labels) to before. The meeting bar's "Upcoming: N" must still show the count of
  upcoming meetings (proves `meetingsLeft` was wired correctly).

## Done criteria

ALL must hold:

- [ ] `lib/common/progress_bars.dart` exists with `buildDoubleProgressBar` and `buildMeetingProgressBar`
- [ ] `grep -n "_buildDoubleProgressBar\|_buildMeetingProgressBar" lib/screens/homescreenpage.dart` → no matches
- [ ] `_buildProgressBars()` calls the extracted functions and passes `meetingsLeft`
- [ ] `flutter analyze lib/screens/homescreenpage.dart lib/common/progress_bars.dart` → no new errors/warnings
- [ ] `wc -l lib/screens/homescreenpage.dart` decreased by ~300 lines
- [ ] `git status` shows only the new file + `homescreenpage.dart`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- `_buildDoubleProgressBar`/`_buildMeetingProgressBar` reference any state besides
  what's described (i.e. they aren't as pure as documented) — extraction needs
  rethinking.
- Plans 001–007 are not yet landed (run this last; otherwise expect conflicts).
- After the move, analyze shows a missing symbol the new file's imports don't
  cover, and adding the obvious `lib/common/*` import doesn't fix it.

## Maintenance notes — the decomposition backlog (for future slices, NOT this plan)

This is slice 1. Future, separately-planned slices (each one file, each pure or
state-injected, each verified by analyze):

- Extract `homescreenpage.dart`'s event card / time-slot item builders — harder;
  they call `setState` and providers, so they'd become `StatefulWidget`s with
  callbacks (model after `TodaysEventsSection` in `adminattendencepage.dart`).
- Extract the Supabase data-access methods (`_fetchEvents`,
  `_fetchCompletedHours`, etc.) into a `HomeRepository` — the repo currently has
  **no repository layer** (noted in `CLAUDE.md`); this is the highest-value
  structural change but MED-HIGH risk, so plan it on its own with a test baseline
  first.
- Apply the same widget-extraction recipe to `adminlistspage.dart` (filter cards,
  user card) and `admineventspage.dart` (event card, dialogs).

A reviewer of this slice should confirm zero visual/behavioral change to the
progress bars and that `meetingsLeft` matches the old inline computation.
