# Plan 007: Members get a local reminder before slots they signed up for

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/homescreenpage.dart lib/services/notification_service.dart lib/providers/notificationsprovider.dart`
> Written against the working tree at `a3682db` plus uncommitted changes. If the
> excerpts below don't match, re-locate with greps; on structural mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: Plan 003 (it rewrites the signup success block). Land 003 first,
  then this. If 003 has NOT landed, this still works — see Step 3's anchor note.
  **Should also land before Plan 008** (god-file split).
- **Category**: direction
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

The notification stack is already fully built — local notifications, FCM, device
tokens, a `send-push` edge function, DB triggers, **and** a user-facing "Event
reminders" toggle in settings with a configurable "minutes before" value. But the
method that actually schedules a reminder, `NotificationService.scheduleEvent
Reminder(...)`, is **never called anywhere in the app**. So the toggle does
nothing: members never get reminded about slots they signed up for. This plan
wires the existing method into the signup flow (and cancels the reminder on
unsignup), respecting the user's toggles — turning already-paid-for
infrastructure into a working feature.

## Current state

- `lib/services/notification_service.dart` — singleton `NotificationService.instance`.
  Relevant existing methods (do not change them):

```dart
  Future<void> scheduleEventReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? payload,
  }) async { ... }   // no-ops if scheduledFor is in the past

  Future<void> cancel(int id) => _plugin.cancel(id);
```

- `lib/providers/notificationsprovider.dart` — `NotificationsProvider` (a
  `ChangeNotifier`, registered in `main.dart` and consumed in
  `notificationsettingspage.dart`). Relevant getters:

```dart
  bool get enabled => _enabled;                 // master switch
  bool get eventReminders => _eventReminders;   // this feature's toggle
  int get reminderMinutesBefore => _reminderMinutesBefore; // default 60
```

- `lib/screens/homescreenpage.dart`:
  - `_signUpForTimeSlot(Event event, TimeSlot timeSlot)` — on success runs
    `hapticsProvider.success(); _fetchEvents();`. **This is where to schedule.**
  - `_removeAttendee(Event event, TimeSlot timeSlot)` — on success runs an
    `'unsignup'` `logactivity(...)` then `_fetchEvents();`. **This is where to cancel.**
  - `timeSlot.id` is an `int?`; `timeSlot.time` is a `TimeOfDay`; `event.date` is a
    `DateTime`; `event.name` is a `String`.

The repo builds an event DateTime from date + slot time in several places like:

```dart
DateTime(event.date.year, event.date.month, event.date.day,
    timeSlot.time.hour, timeSlot.time.minute)
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Confirm provider is registered | `grep -n "NotificationsProvider" lib/main.dart` | shows it created/provided |
| Analyze (gate) | `flutter analyze lib/screens/homescreenpage.dart` | No new errors/warnings |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` | — |

> **Verification reality**: no test suite. Gate is `flutter analyze`. Reminder
> delivery is verified manually (Test plan).

## Scope

**In scope**:
- `lib/screens/homescreenpage.dart` only.

**Out of scope**:
- `lib/services/notification_service.dart` — reuse `scheduleEventReminder`/`cancel` unchanged.
- `lib/providers/notificationsprovider.dart` — read its getters; don't modify.
- The admin "Meeting"/mandatory auto-enroll paths (members don't self-signup
  there; reminders for those are a deferred follow-up).

## Git workflow

- Branch: `advisor/007-schedule-event-reminders-on-signup`
- One commit, subject e.g. `Schedule local reminders on slot signup`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Confirm `NotificationsProvider` is available via Provider

Run `grep -n "NotificationsProvider" lib/main.dart`. Confirm it is registered in
the `MultiProvider` (so `Provider.of<NotificationsProvider>(context, listen:
false)` resolves in the home screen). It is already consumed by
`notificationsettingspage.dart` via `context.watch<NotificationsProvider>()`, so
this should hold.

- If it is **not** provided in the widget tree → STOP and report (wiring it into
  `MultiProvider` is a different change).

### Step 2: Add imports

At the top of `lib/screens/homescreenpage.dart`, with the other imports, add (if
not already present):

```dart
import '../services/notification_service.dart';
import '../providers/notificationsprovider.dart';
```

### Step 3: Schedule a reminder on successful signup

In `_signUpForTimeSlot`, locate the signup **success path**. Anchor: the line
`hapticsProvider.success();` followed by `_fetchEvents();`. (After Plan 003 this
lives inside the `if (status == 'ok') { ... }` branch; before 003 it's inside
`if (existingAttendee == null) { ... }`. Either way, anchor on
`hapticsProvider.success();`.)

Immediately **after** `hapticsProvider.success();`, insert:

```dart
          // Schedule a local reminder if the user enabled event reminders.
          final notifPrefs =
              Provider.of<NotificationsProvider>(context, listen: false);
          if (notifPrefs.enabled &&
              notifPrefs.eventReminders &&
              timeSlot.id != null) {
            final start = DateTime(
              event.date.year,
              event.date.month,
              event.date.day,
              timeSlot.time.hour,
              timeSlot.time.minute,
            );
            final remindAt = start.subtract(
                Duration(minutes: notifPrefs.reminderMinutesBefore));
            await NotificationService.instance.scheduleEventReminder(
              id: timeSlot.id!,
              title: 'Upcoming: ${event.name}',
              body:
                  'Starts at ${timeSlot.time.format(context)}. Tap for details.',
              scheduledFor: remindAt,
            );
          }
```

Notes:
- Using `timeSlot.id!` as the notification id makes it deterministic and unique
  per slot, so Step 4 can cancel exactly this reminder. A user holds at most one
  signup per slot, so there's no collision.
- `scheduleEventReminder` already returns early if `remindAt` is in the past, so
  signing up for a soon/past slot simply schedules nothing.

### Step 4: Cancel the reminder on unsignup

In `_removeAttendee`, after the `'unsignup'` `logactivity(...)` call and before
`_fetchEvents();`, insert:

```dart
        // Cancel any scheduled reminder for this slot.
        if (timeSlot.id != null) {
          await NotificationService.instance.cancel(timeSlot.id!);
        }
```

### Step 5: Analyze

**Verify**: `flutter analyze lib/screens/homescreenpage.dart` → no new
errors/warnings.

## Test plan

No automated harness. Manual (needs a device with notifications granted):

- In Settings, enable notifications + Event reminders, set "minutes before" to a
  small value (e.g. 1–2 min for testing).
- Sign up for a slot whose start time is a few minutes out → a reminder fires at
  (start − minutesBefore). Verify via `NotificationService.instance.pending()`
  (it lists scheduled notifications) or by waiting for it.
- Cancel the signup → the pending reminder for that slot id is gone.
- With Event reminders toggled **off**, signing up schedules nothing.

## Done criteria

ALL must hold:

- [ ] `_signUpForTimeSlot` calls `scheduleEventReminder` in the success path, gated on `enabled && eventReminders`
- [ ] `_removeAttendee` calls `NotificationService.instance.cancel(timeSlot.id!)` on unsignup
- [ ] The reminder id is `timeSlot.id` (deterministic) in both schedule and cancel
- [ ] `flutter analyze lib/screens/homescreenpage.dart` introduces no new errors/warnings
- [ ] `git status` shows only `lib/screens/homescreenpage.dart` modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- `NotificationsProvider` is not registered in `main.dart`'s provider tree.
- The signup success anchor (`hapticsProvider.success();`) or the `_removeAttendee`
  unsignup `logactivity` call don't exist (drift, or Plan 003 changed them in a
  way that removed the anchor).
- `scheduleEventReminder`/`cancel` signatures differ from "Current state".
- Using `context` after `await` triggers a use-after-async analyzer error you
  can't resolve by reading `notifPrefs` before the `await` — if so, read
  `notifPrefs` and compute `remindAt` before any `await`, then call schedule.

## Maintenance notes

- Reminders are local and device-bound: they live only on the device that did the
  signup. A member who signs up on phone A won't get the local reminder on phone
  B. (Server-side push for reminders would need a scheduled job calling
  `send-push`; deferred.)
- If the event date/time is later edited by an admin, the previously scheduled
  reminder still fires at the old time. A follow-up could reschedule on event
  update — out of scope here.
- A reviewer should confirm the notification id scheme (`timeSlot.id`) can't
  collide with ids used by `showLocal`/push elsewhere.
