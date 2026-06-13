# Plan 005: One event-fetch implementation in the admin events screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/admineventspage.dart`
> Written against the working tree at `a3682db` plus uncommitted changes. If the
> excerpts/line numbers below don't match, re-locate them with the greps in the
> steps before editing; on a structural mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none. **Should land before Plan 008** (god-file split), which
  relocates this code.
- **Category**: tech-debt
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

`admineventspage.dart` has **two different implementations of "load this
society's events with their time slots and attendees"**:

- `_fetchDataOptimized()` (called on `initState`) — one nested Supabase query.
- `_fetchEvents()` (called on pull-to-refresh and after every add/update/delete)
  — three separate queries that assemble the same model a different way.

Maintaining two builders of the same object means they drift: a field added to
one parsing path is missed in the other, so the screen can show different data
right after a refresh than it did on load. Worse, the two disagree on a real
behavior: `_fetchDataOptimized` joins time slots with `!inner`, which **drops
events that have no time slots** (an admin can create an event, then not see it
until it has a slot), while `_fetchEvents` keeps them. This plan collapses to one
implementation and fixes the slotless-event drop.

## Current state

- `lib/screens/admineventspage.dart`:
  - `_fetchDataOptimized()` — lines ~1344–1452, single nested query, also fetches
    collections, sets `_isLoading`.
  - `_fetchEvents()` — lines ~1453–1570, three-query version, sets `_isLoading`.
  - `_fetchEvents()` is called at **4 sites**: 269 (pull-to-refresh, paired with
    `_fetchCollections()`), 1649 (after collection delete), 2316 (after add),
    2606 (after update).

The `!inner` join that drops slotless events — `admineventspage.dart:1378`:

```dart
              society_id,
              "Time slots"!inner(
                id,
                start_time,
                end_time,
                number_of_people,
```

The pull-to-refresh pair — `admineventspage.dart:268-271`:

```dart
                          onRefresh: () async {
                            await _fetchEvents();
                            await _fetchCollections();
                          },
```

The other three call sites are bare `_fetchEvents();` / `await _fetchEvents();`
at lines 1649, 2316, 2606.

Convention: RPC/query style elsewhere in this file already uses the nested-select
form in `_fetchDataOptimized`; that is the implementation we keep.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze (gate) | `flutter analyze lib/screens/admineventspage.dart` | No new errors/warnings |
| Find callers | `grep -n "_fetchEvents\|_fetchDataOptimized" lib/screens/admineventspage.dart` | confirms the sites below |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` | — |

> **Verification reality**: no test suite. Gate is `flutter analyze` + the greps.
> Behavioral checks (refresh shows the same data as load; a slotless event is
> visible) are manual and listed in the Test plan.

## Scope

**In scope**:
- `lib/screens/admineventspage.dart` only.

**Out of scope**:
- `_fetchCollections()` — keep it; it's still called on init via `_fetchDataOptimized`.
- Attendee/TimeSlot model classes.
- Any change to how events are filtered or rendered.

## Git workflow

- Branch: `advisor/005-consolidate-admin-event-fetch`
- One commit, subject e.g. `Consolidate admin event fetch into one path`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Stop dropping slotless events

At `admineventspage.dart:1378`, change the inner join to a left join so events
with no time slots are retained (matching the old `_fetchEvents` behavior):

```dart
              society_id,
              "Time slots"(
                id,
                start_time,
                end_time,
                number_of_people,
```

(Only `"Time slots"!inner(` → `"Time slots"(`. Leave everything else in the
nested select unchanged.)

**Verify**: `grep -n '"Time slots"!inner' lib/screens/admineventspage.dart` → no matches.

### Step 2: Point pull-to-refresh at the single implementation

Replace the refresh pair at lines 268–271:

```dart
                          onRefresh: () async {
                            await _fetchEvents();
                            await _fetchCollections();
                          },
```

with:

```dart
                          onRefresh: () async {
                            await _fetchDataOptimized();
                          },
```

(`_fetchDataOptimized` already fetches both events and collections, so the
separate `_fetchCollections()` is redundant here.)

### Step 3: Repoint the remaining three call sites

Replace `_fetchEvents()` with `_fetchDataOptimized()` at the three remaining
sites (after collection delete ~1649, after add ~2316, after update ~2606),
preserving the existing `await`/non-`await` form at each:

- `_fetchEvents();` → `_fetchDataOptimized();`
- `await _fetchEvents();` → `await _fetchDataOptimized();`

**Verify**: `grep -n "_fetchEvents" lib/screens/admineventspage.dart` shows only
the method **definition** line remaining (no callers).

### Step 4: Delete the now-unused `_fetchEvents()` method

Remove the entire `_fetchEvents()` method (the block from
`Future<void> _fetchEvents() async {` through its closing brace, immediately
before `Future<void> _fetchCollections() async {`).

**Verify**: `grep -n "_fetchEvents" lib/screens/admineventspage.dart` → no
matches at all.

### Step 5: Analyze

**Verify**: `flutter analyze lib/screens/admineventspage.dart` → no new
errors/warnings, and specifically no "unused element `_fetchEvents`" or
"undefined method" errors.

## Test plan

No automated harness. Manual verification (needs device + Supabase):

- Load the admin Events screen, then pull to refresh — the same events appear
  (no flicker to a different set).
- Create an event with **no time slots** and confirm it now appears in the list
  (previously it would be hidden until it had a slot).
- Add, edit, and delete operations still refresh the list correctly.

## Done criteria

ALL must hold:

- [ ] `grep -n '"Time slots"!inner' lib/screens/admineventspage.dart` → no matches
- [ ] `grep -n "_fetchEvents" lib/screens/admineventspage.dart` → no matches
- [ ] All former `_fetchEvents()` callers now call `_fetchDataOptimized()`
- [ ] `flutter analyze lib/screens/admineventspage.dart` introduces no new errors/warnings
- [ ] `git status` shows only `lib/screens/admineventspage.dart` modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- `_fetchDataOptimized` no longer fetches collections (someone changed it) — then
  removing `_fetchCollections()` from the refresh handler would be wrong.
- The `!inner` join or the call sites don't match the excerpts (drift).
- After deletion, analyze reports any remaining reference to `_fetchEvents`.

## Maintenance notes

- After this, there is **one** event-loading path; any new event field must be
  added to the nested select in `_fetchDataOptimized` only.
- A reviewer should confirm the left-join change didn't change attendee counts
  (attendees are nested under time slots, unaffected) and that slotless events
  render without throwing (they'll have an empty `timeSlots` list).
- If Plan 008 (god-file split) extracts this fetch into a service, it should move
  the single consolidated method, not resurrect two.
