# Notifications Setup

This guide walks you through finishing the notification setup that was scaffolded in the codebase. Everything in the Dart/Flutter side is already wired up — what's left is the **platform-specific Firebase setup**, the **Supabase database/Edge Function side**, and a one-time `flutter pub get`.

Two kinds of notifications are supported:

1. **Local scheduled notifications** — work fully offline once scheduled. Used for event reminders (sign-ups).
2. **Push notifications (FCM)** — server-sent via Firebase Cloud Messaging, triggered by Supabase Edge Functions or database triggers. Used for meeting notes, hour updates, and swap requests.

---

## Architecture overview

| File | Role |
|---|---|
| [lib/services/notification_service.dart](lib/services/notification_service.dart) | Singleton wrapping `flutter_local_notifications` + FCM token sync to Supabase. |
| [lib/services/firebase_messaging_service.dart](lib/services/firebase_messaging_service.dart) | Wraps `firebase_messaging`. Safely no-ops if Firebase isn't configured yet. |
| [lib/providers/notificationsprovider.dart](lib/providers/notificationsprovider.dart) | `ChangeNotifier` for user prefs (enabled, which categories, reminder timing). Persists via SharedPreferences. |
| [lib/screens/notificationsettingspage.dart](lib/screens/notificationsettingspage.dart) | The user-facing settings screen, linked from Profile → Notifications. |
| [lib/main.dart](lib/main.dart) | Calls `NotificationService.instance.init()` before `runApp`, registers the provider, re-registers the FCM token on sign-in. |
| [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) | Permissions + scheduled-notification receivers. |
| [ios/Runner/Info.plist](ios/Runner/Info.plist) | `UIBackgroundModes` with `remote-notification`. |
| [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift) | Registers for remote notifications. |

---

## Step 1 — Pull dependencies

```sh
flutter pub get
```

The packages added are:
- `flutter_local_notifications` — scheduled local notifications
- `timezone` + `flutter_timezone` — for zoned `tz.TZDateTime` scheduling
- `firebase_core` + `firebase_messaging` — push notifications
- `permission_handler` — Android 13+ `POST_NOTIFICATIONS` runtime prompt

> The app **will run fine without Firebase configured** — push notifications just no-op until you complete Step 3. Local scheduled notifications work immediately.

---

## Step 2 — Supabase: migrations + Edge Function

All the database and serverless side has been scaffolded under [supabase/](supabase/). Detailed deploy steps live in [supabase/README.md](supabase/README.md). The short version:

```sh
supabase login
supabase link --project-ref <project-ref>
supabase db push                                 # runs the 3 migrations
supabase functions deploy send-push              # deploys the FCM sender
```

Then **once** in the SQL editor (see [supabase/README.md](supabase/README.md) §4):

```sql
select vault.create_secret(
  'https://<project-ref>.functions.supabase.co', 'edge_url',
  'Edge Functions base URL used by notification triggers');
select vault.create_secret(
  '<service-role-key>', 'service_role_key',
  'Used by notification triggers to call send-push');
```

And set FCM secrets:

```sh
supabase secrets set FCM_PROJECT_ID=<firebase-project-id>
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat firebase-service-account.json)"
```

What the migrations install:

- [supabase/migrations/20260526000001_device_tokens.sql](supabase/migrations/20260526000001_device_tokens.sql) — `device_tokens` table + RLS. `NotificationService.syncFcmToken` upserts here on `onConflict: 'fcm_token'`.
- [supabase/migrations/20260526000002_notification_helpers.sql](supabase/migrations/20260526000002_notification_helpers.sql) — `send_push_to_users(uuid[], title, body, data)` and `send_push_to_society(...)` helpers that invoke the Edge Function via `pg_net`.
- [supabase/migrations/20260526000003_notification_triggers.sql](supabase/migrations/20260526000003_notification_triggers.sql) — triggers on `"Notes"` (new meeting notes), `activity_logs` (attendance/hour changes), and `swap_requests` (request created / status changed).

---

## Step 3 — Firebase project setup

### 3a. Create the Firebase project
1. Go to <https://console.firebase.google.com> → **Add project**.
2. Name it (e.g. "Wheeler NHS").
3. Skip Google Analytics if you don't need it.

### 3b. Register your apps

**Android:**
1. In the Firebase console, **Add app → Android**.
2. Android package name: `com.wheelermun.wheeler_nhs` (matches `applicationId` in [android/app/build.gradle](android/app/build.gradle)).
3. Download `google-services.json` → place at [android/app/google-services.json](android/app/).
4. In [android/build.gradle](android/build.gradle), add to `buildscript.dependencies`:
   ```gradle
   classpath 'com.google.gms:google-services:4.4.2'
   ```
5. In [android/app/build.gradle](android/app/build.gradle), at the top of the file (after the `plugins` block):
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

**iOS:**
1. In the Firebase console, **Add app → iOS**.
2. iOS bundle ID: open [ios/Runner.xcodeproj](ios/Runner.xcodeproj) in Xcode → Runner target → General tab → "Bundle Identifier". Use that value.
3. Download `GoogleService-Info.plist`.
4. **Open Xcode** (not Finder) and drag `GoogleService-Info.plist` into the `Runner` group, with "Copy items if needed" checked and the `Runner` target ticked. (Drag-via-Finder won't add it to the project file.)
5. Apple Push Notification setup:
   - In <https://developer.apple.com>, create an **APNs Authentication Key** (.p8).
   - In Firebase Console → Project Settings → Cloud Messaging → Apple app configuration → upload the .p8 with Key ID and Team ID.
6. In Xcode → Runner target → **Signing & Capabilities** → click `+ Capability` → add **Push Notifications** and **Background Modes** (check "Remote notifications" — it should already be there from `Info.plist`).

### 3c. Use FlutterFire (optional but easier)

If you'd rather generate `firebase_options.dart` automatically:

```sh
dart pub global activate flutterfire_cli
flutterfire configure
```

If you go this route, update [lib/services/firebase_messaging_service.dart](lib/services/firebase_messaging_service.dart) — change:

```dart
await Firebase.initializeApp();
```

to:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

and import the generated `firebase_options.dart`. Without `flutterfire configure`, Firebase reads `google-services.json` / `GoogleService-Info.plist` directly, which also works.

---

## Step 4 — Sending push notifications

Already implemented in [supabase/functions/send-push/index.ts](supabase/functions/send-push/index.ts) and the three migrations under [supabase/migrations/](supabase/migrations/). See [supabase/README.md](supabase/README.md) for the architecture diagram and deploy commands.

The Edge Function accepts either explicit `tokens` or `user_ids` (which it resolves against `device_tokens` using the service role). Database triggers always use `user_ids`.

To send an ad-hoc push from anywhere (Dart, curl, another Edge Function):

```bash
curl -X POST https://<project-ref>.functions.supabase.co/send-push \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"user_ids":["<uuid>"],"title":"Hi","body":"Manual test"}'
```

---

## Step 5 — Scheduling event reminders (local)

`flutter_local_notifications` is already initialized. To schedule a reminder when a user signs up for a time slot, call this from wherever your signup flow lives (e.g. inside the signup handler in `homescreenpage.dart` or `customeventformpage.dart`):

```dart
final notifications = context.read<NotificationsProvider>();
if (notifications.shouldScheduleFor('event')) {
  final reminderTime = timeslot.startTime
      .subtract(Duration(minutes: notifications.reminderMinutesBefore));
  await NotificationService.instance.scheduleEventReminder(
    id: timeslot.id, // unique per slot — id collisions overwrite
    title: 'Upcoming event: ${event.name}',
    body: 'Starts in ${notifications.reminderMinutesBefore} minutes at ${event.location}',
    scheduledFor: reminderTime,
    payload: 'event:${event.id}',
  );
}
```

And when the user un-signs:

```dart
await NotificationService.instance.cancel(timeslot.id);
```

---

## Step 6 — Test

1. Run the app on a physical device (push notifications don't deliver in the iOS simulator; local ones do).
2. Sign in.
3. Profile → **Notifications** → toggle **Enable Notifications** — accept the permission prompt.
4. Tap **Send a test notification** at the bottom. You should see it appear immediately.
5. For FCM: in Firebase Console → Cloud Messaging → "Send your first message" → paste the FCM token from a recently signed-in test device (or query `select fcm_token from device_tokens where user_id = '…'`).

---

## Common gotchas

- **Android 13+** requires the runtime `POST_NOTIFICATIONS` prompt. The `permission_handler` package handles it via `NotificationService.requestPermissions()`.
- **Exact alarms on Android 14+** require user approval via system settings. The code falls back to `inexactAllowWhileIdle`, which is fine for "X minutes before" reminders — they'll fire within a small window.
- **iOS simulator** delivers local notifications but **not** push. Test FCM on hardware.
- **Token rotation:** FCM tokens can rotate. `FirebaseMessagingService` already wires `onTokenRefresh` → `NotificationService.syncFcmToken`, so the new token is upserted into Supabase automatically.
- **Sign-out:** `NotificationsProvider.setEnabled(false)` calls `unregisterDevice()` which deletes the token row. If you want this to happen on every sign-out (not just when the user explicitly disables), call it inside `_signOut` in [lib/screens/settingspage.dart](lib/screens/settingspage.dart).
- **App icon for Android notifications:** uses `@mipmap/launcher_icon`. If your launcher icon has a color background and you want a proper monochrome status-bar icon, generate a white-on-transparent drawable and update the `AndroidInitializationSettings` argument in `NotificationService.init()`.

---

## What's wired vs. what's pending

| Item | Status |
|---|---|
| Local notification plumbing | Done — works after `flutter pub get`. |
| Notification settings UI (Profile → Notifications) | Done. |
| FCM token sync to Supabase on sign-in | Done. |
| `device_tokens` table | Migration scaffolded — run `supabase db push`. |
| Firebase project + `google-services.json` / `GoogleService-Info.plist` | **You** — Step 3. |
| `send-push` Edge Function | Scaffolded — run `supabase functions deploy send-push`. |
| Triggers for meeting notes / hours / swaps | Scaffolded in migrations — applied via `supabase db push`. |
| Schedule reminder on event sign-up | Done — wired into the signup/unsignup handlers in `homescreenpage.dart`. |
| Per-category opt-out respected server-side | Done — `device_tokens` carries `notify_meeting_notes` / `notify_hour_updates` / `notify_swap_requests`; `send-push` filters on them by `data.type`. **Redeploy:** run `supabase db push` (new migration) and `supabase functions deploy send-push`. |
| Tapping a notification routes to the right tab | Done — `NotificationService.tappedNotification` is consumed by `MainScreen` (covers local taps, FCM background/terminated taps, and cold starts). |
