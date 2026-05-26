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

## Step 2 — Supabase: `device_tokens` table

Create a table to hold FCM tokens per device. Run this in the Supabase SQL editor:

```sql
create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('ios','android','other')),
  updated_at timestamptz not null default now()
);

create index on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy "Users manage their own tokens"
  on public.device_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

`NotificationService.syncFcmToken` upserts into this table on `onConflict: 'fcm_token'`, so re-installs/refreshes don't duplicate.

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

You can send pushes from a **Supabase Edge Function** triggered by database changes. Example function: `supabase/functions/send-push/index.ts`

```ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { JWT } from "https://deno.land/x/google_auth_library@v0.1.0/mod.ts";

const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;
const SERVICE_ACCOUNT = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!);

async function getAccessToken() {
  const jwt = new JWT({
    email: SERVICE_ACCOUNT.client_email,
    key: SERVICE_ACCOUNT.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  return (await jwt.authorize()).access_token;
}

serve(async (req) => {
  const { tokens, title, body, data } = await req.json();
  const accessToken = await getAccessToken();

  const results = await Promise.all(
    (tokens as string[]).map((token) =>
      fetch(
        `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: { token, notification: { title, body }, data },
          }),
        },
      ).then((r) => r.json()),
    ),
  );

  return new Response(JSON.stringify({ results }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

Then deploy and set secrets:

```sh
supabase functions deploy send-push
supabase secrets set FCM_PROJECT_ID=your-firebase-project-id
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat firebase-service-account.json)"
```

Get the service account JSON from Firebase Console → Project Settings → Service accounts → Generate new private key.

### Database triggers

Wire the trigger to events you care about. Example for meeting notes (Step 3 of the original ask — "New meeting notes posted"):

```sql
create or replace function notify_new_meeting_note()
returns trigger as $$
declare
  recipient_tokens text[];
begin
  -- Collect tokens of all members of the society
  select array_agg(dt.fcm_token) into recipient_tokens
  from device_tokens dt
  join user_society_memberships usm on usm.user_id = dt.user_id
  where usm.society_id = NEW.society_id;

  if recipient_tokens is not null then
    perform net.http_post(
      url := 'https://YOUR-PROJECT.functions.supabase.co/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key')
      ),
      body := jsonb_build_object(
        'tokens', recipient_tokens,
        'title', 'New meeting notes',
        'body', NEW.title,
        'data', jsonb_build_object('type', 'meeting_notes', 'id', NEW.id)
      )
    );
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger trg_meeting_note_insert
  after insert on meeting_notes
  for each row execute procedure notify_new_meeting_note();
```

> The `net.http_post` helper requires the `pg_net` extension: `create extension if not exists pg_net;`

Repeat the same pattern for:
- **Hours updated** → trigger on `activity_logs` insert where `action_type in ('attendance_marked','manual_addition')`, look up the affected `user_id`'s tokens.
- **Swap requests** → trigger on `swap_requests` insert/update, targeting the counterparty's tokens.

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
| `device_tokens` table | **You** — run the SQL in Step 2. |
| Firebase project + `google-services.json` / `GoogleService-Info.plist` | **You** — Step 3. |
| `send-push` Edge Function | **You** — Step 4. |
| Triggers for meeting notes / hours / swaps | **You** — Step 4. |
| Schedule reminder on event sign-up | **You** — Step 5; one-line call in your signup handler. |
