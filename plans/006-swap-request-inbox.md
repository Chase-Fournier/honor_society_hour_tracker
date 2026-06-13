# Plan 006: Pending swap requests appear as an inbox on the home screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/homescreenpage.dart`
> Written against the working tree at `a3682db` plus uncommitted changes. If the
> excerpts below don't match, re-locate them with greps; on structural mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none. **Should land before Plan 008** (god-file split).
- **Category**: direction
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

When another member requests a slot swap, the target only finds out if they
happen to open the Home tab *while it loads* — `_checkPendingSwapRequests()` runs
in `initState` and pops a sequence of `AlertDialog`s one per request. Miss that
moment (or dismiss one) and the request is invisible until the next cold load,
and stacked modal dialogs are a poor way to triage several at once. This plan
turns pending **incoming** swap requests into a persistent inbox section on the
Home screen — a card per request with Accept/Decline inline — reusing the
existing accept/decline logic. (Server-side push for swaps already exists via
`supabase/migrations/20260526000003_notification_triggers.sql`; this gives the
notification somewhere to land.)

## Current state

All in `lib/screens/homescreenpage.dart`:

- `initState` (line ~64) calls `_checkPendingSwapRequests();`.
- `_checkPendingSwapRequests()` (line ~2577) queries pending swaps **targeted at
  the current user**, with nested event/requester/timeslot data, then calls
  `handleSwapRequests(...)` which pops a dialog per request via
  `_showSwapRequestNotification(...)`.
- The query (reuse this shape — it already nests everything the cards need):

```dart
    final swapRequests = await Supabase.instance.client
        .from('swap_requests')
        .select(
            '*, Events!swap_requests_event_id_fkey(*), profiles!swap_requests_requester_id_fkey(*), "Time slots"!swap_requests_timeslot_id_fkey(start_time, end_time)')
        .eq('status', 'pending')
        .eq("target_id", currentUserId);
```

- **Reusable handlers already exist** — do NOT reimplement them:
  - `_acceptSwapRequest(SwapRequest swapRequest, Map<String, dynamic> eventData)`
    — updates status, performs the attendee swap, shows a snackbar, calls
    `_fetchEvents()`.
  - `_declineSwapRequest(SwapRequest swapRequest)` — sets status to 'declined',
    shows a snackbar.
  - `_isAlreadySignedUp(SwapRequest)` — returns bool; used to hide Accept when the
    target already holds that slot.
  - `SwapRequest.fromJson(Map<String,dynamic>)` parses a row.
- `formatter` is a `DateFormat('jm')` field on the state class (used for slot times).

**Structural pattern to copy** — the "Ongoing Opportunities" section. In `build`,
it renders conditionally:

```dart
                    // Ongoing / external opportunities
                    if (_continuousEvents.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildOngoingHeader(),
                      const SizedBox(height: 8),
                      ..._continuousEvents
                          .map((ce) => _buildContinuousEventCard(ce)),
                    ],
```

with `_buildOngoingHeader()` (a Row with an icon + title) and
`_buildContinuousEventCard(ce)` (a bordered `Container` card). Model the new
swap section on these. The progress bars are the first children of the scroll
column: `..._buildProgressBars(),`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze (gate) | `flutter analyze lib/screens/homescreenpage.dart` | No new errors/warnings |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` | — |

> **Verification reality**: no test suite. Gate is `flutter analyze`. Behavior is
> verified manually (Test plan).

## Scope

**In scope**:
- `lib/screens/homescreenpage.dart` only.

**Out of scope**:
- `_acceptSwapRequest`, `_declineSwapRequest`, `_isAlreadySignedUp`,
  `_swapAttendees`, `_performSwap` — reuse as-is, do not change their logic.
- The swap **request-creation** flow (`_showSwapRequestDialog` etc.).
- Any model or DB change.

## Git workflow

- Branch: `advisor/006-swap-request-inbox`
- One commit, subject e.g. `Add swap-request inbox to home screen`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add state to hold pending swap requests

Near the other state fields at the top of `_HomePageState` (e.g. by
`List<ContinuousEvent> _continuousEvents = [];`), add:

```dart
  // Raw pending swap-request rows targeted at the current user (with nested
  // Events / profiles / "Time slots"). Rendered as the home-screen inbox.
  List<Map<String, dynamic>> _pendingSwapRequests = [];
```

### Step 2: Make `_checkPendingSwapRequests` populate state instead of popping dialogs

Replace the body of `_checkPendingSwapRequests()` so it stores the rows in state
and no longer calls `handleSwapRequests`:

```dart
  Future<void> _checkPendingSwapRequests() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final swapRequests = await Supabase.instance.client
        .from('swap_requests')
        .select(
            '*, Events!swap_requests_event_id_fkey(*), profiles!swap_requests_requester_id_fkey(*), "Time slots"!swap_requests_timeslot_id_fkey(start_time, end_time)')
        .eq('status', 'pending')
        .eq("target_id", currentUserId);

    if (!mounted) return;
    setState(() {
      _pendingSwapRequests = List<Map<String, dynamic>>.from(swapRequests);
    });
  }
```

### Step 3: Remove the now-unused dialog helpers

Delete `handleSwapRequests(...)` and `_showSwapRequestNotification(...)` (they
were only used by the old auto-dialog flow). First confirm they have no other
callers:

`grep -n "handleSwapRequests\|_showSwapRequestNotification" lib/screens/homescreenpage.dart`

- If the only references are the definitions (and the call inside the old
  `_checkPendingSwapRequests`, which Step 2 removed) → delete both methods.
- If either is referenced elsewhere → STOP and report.

### Step 4: Add the inbox section widgets

Add two builder methods (place them near `_buildOngoingHeader` /
`_buildContinuousEventCard` for consistency):

```dart
  Widget _buildSwapRequestsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.swap_horiz,
              color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Swap Requests',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> row) {
    final scheme = Theme.of(context).colorScheme;
    final swapRequest = SwapRequest.fromJson(row);
    final eventData = row['Events'] as Map<String, dynamic>?;
    final profileData = row['profiles'] as Map<String, dynamic>?;
    final requesterName = profileData?['name'] ?? 'A member';
    final eventName = eventData?['name'] ?? 'an event';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$requesterName wants to swap',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '$eventName • ${formatter.format(swapRequest.startTime)} - ${formatter.format(swapRequest.endTime)}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    await _declineSwapRequest(swapRequest);
                    await _checkPendingSwapRequests();
                  },
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: eventData == null
                      ? null
                      : () async {
                          Provider.of<HapticsProvider>(context, listen: false)
                              .selection();
                          final already = await _isAlreadySignedUp(swapRequest);
                          if (already) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'You already hold this slot.')),
                              );
                            }
                            return;
                          }
                          await _acceptSwapRequest(swapRequest, eventData);
                          await _checkPendingSwapRequests();
                        },
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
```

> Note: `_declineSwapRequest` and `_acceptSwapRequest` are declared `void` (not
> `Future`) in the current code. If `await` on them produces an analyzer error,
> drop the `await` and call them without it (they already trigger their own
> refresh via `_fetchEvents()` / snackbars). Then still call
> `_checkPendingSwapRequests()` afterward to refresh the inbox.

### Step 5: Render the section in `build`

In the `build` method's scroll column, insert the inbox **above the progress
bars** so it's the first thing the user sees. Find the first child
`..._buildProgressBars(),` and insert immediately before it:

```dart
                    if (_pendingSwapRequests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSwapRequestsHeader(),
                      const SizedBox(height: 8),
                      ..._pendingSwapRequests.map(_buildSwapRequestCard),
                      const SizedBox(height: 16),
                    ],
                    // Progress bars for each requirement type
                    ..._buildProgressBars(),
```

### Step 6: Analyze

**Verify**: `flutter analyze lib/screens/homescreenpage.dart` → no new
errors/warnings; no "unused element" for the deleted methods; no undefined refs.

## Test plan

No automated harness. Manual (needs two accounts + Supabase):

- As member A, request a swap with member B for a slot A holds.
- As member B, open Home: a "Swap Requests" card appears at the top with A's name,
  the event, and the slot time. No modal dialog pops.
- Tap Decline → card disappears, request marked declined.
- Re-request, then tap Accept → the swap occurs (B now holds the slot), card
  disappears, events refresh.
- If B already holds the slot, Accept shows the "already hold this slot" snackbar
  and does not double-book.

## Done criteria

ALL must hold:

- [ ] `_pendingSwapRequests` state exists and is populated by `_checkPendingSwapRequests`
- [ ] No `AlertDialog` pops automatically for swaps on home load
- [ ] `grep -n "handleSwapRequests\|_showSwapRequestNotification" lib/screens/homescreenpage.dart` → no matches
- [ ] Inbox section renders above progress bars when there are pending requests
- [ ] Accept/Decline reuse the existing `_acceptSwapRequest`/`_declineSwapRequest`
- [ ] `flutter analyze lib/screens/homescreenpage.dart` introduces no new errors/warnings
- [ ] `git status` shows only `lib/screens/homescreenpage.dart` modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- `handleSwapRequests`/`_showSwapRequestNotification` are referenced somewhere
  other than the old flow (deleting them would break a caller).
- `_acceptSwapRequest`/`_declineSwapRequest` signatures differ from those in
  "Current state" (drift) — the card wiring would be wrong.
- The query/`SwapRequest.fromJson` shape doesn't match (e.g. `row['Events']` is
  null for valid rows) — investigate before rendering.

## Maintenance notes

- The inbox refreshes on load and after each action. A future improvement is a
  Supabase Realtime subscription on `swap_requests` so it updates live without a
  manual refresh — deferred.
- `_isAlreadySignedUp` is checked on Accept; keep that guard if the accept logic
  changes.
- A reviewer should confirm the deleted dialog methods left no dangling imports
  and that the section doesn't push the progress bars off-screen on small devices
  (it's above them by design — acceptable, but worth a glance).
