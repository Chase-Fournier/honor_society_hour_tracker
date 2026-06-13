# Plan 003: Time-slot signup is atomic and cannot oversell capacity

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> This plan has an **operator step** (applying a database migration) that you
> may not be able to run yourself; do the parts you can, verify them, and clearly
> report what remains for the operator. When done, update `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a3682db..HEAD -- lib/screens/homescreenpage.dart`
> Written against the working tree at `a3682db` plus uncommitted changes. If the
> excerpts below don't match the live code, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (independent; can land before or after 001/002)
- **Category**: bug
- **Planned at**: commit `a3682db`, 2026-06-13

## Why this matters

Signing up for a time slot is the core action of this app, and today it is a
non-atomic **check-then-act** using **stale in-memory state**:

1. The client checks `existingAttendee == null`.
2. Inserts an `Attendees` row.
3. Writes `number_of_people = timeSlot.numberOfPeople - 1`, where
   `timeSlot.numberOfPeople` is the value the device loaded earlier — not the
   current DB value.

Two members tapping "Sign Up" at the same time both read the same count and both
write the same decremented value, so a slot with 1 spot can end up with 2
attendees and a wrong count. A stale device can also write a count that
overwrites another change. The fix moves the whole operation into a single
atomic Postgres function that locks the slot row, enforces capacity
server-side, and returns a status — eliminating the race regardless of how many
clients act concurrently.

## Current state

- `lib/screens/homescreenpage.dart` — `_signUpForTimeSlot(Event event,
  TimeSlot timeSlot)` performs the racy signup.
- `lib/providers/societyprovider.dart:334,359` — the repo already calls Postgres
  functions via `Supabase.instance.client.rpc('create_society', params: {...})`.
  **Match this RPC pattern.**
- `supabase/migrations/` — migrations define `security definer` plpgsql functions
  (see `20260527000002_continuous_submission_limit.sql` for the house style:
  `create or replace function public.<name>(...) returns ... language plpgsql ...`).
  Migration files are named `YYYYMMDDNNNNNN_<slug>.sql`.

Excerpt of the racy block — `lib/screens/homescreenpage.dart:2499-2529`:

```dart
        // Check if the user is already signed up
        final existingAttendee = await Supabase.instance.client
            .from('Attendees')
            .select()
            .eq('timeslot_id', timeSlot.id ?? 0)
            .eq('user_id', userId)
            .maybeSingle();

        if (existingAttendee == null) {
          // Add the user to the Attendees table
          await Supabase.instance.client.from('Attendees').insert({
            'timeslot_id': timeSlot?.id ?? 0,
            'user_id': userId,
            'is_present': false,
          });

          // Update the number of people in the time slot
          await Supabase.instance.client
              .from('Time slots')
              .update({'number_of_people': timeSlot.numberOfPeople - 1}).eq(
                  'id', timeSlot?.id ?? 0);

          await logactivity(
            event.name,
            '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
            NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
            'signup',
            userId,
          );
          hapticsProvider.success();
          _fetchEvents();
        }
```

Known schema facts (from existing code):
- Table is `"Time slots"` (literal name has a space → must be double-quoted in SQL).
  Columns used: `id` (integer/bigint), `number_of_people` (integer).
- Table `Attendees`: columns `timeslot_id` (integer), `user_id` (uuid),
  `is_present` (boolean), `forms_completed` (boolean).

> If `logactivity` is being given `societyId` by Plan 002 by the time you reach
> this, keep that argument. If 002 hasn't landed, leave the `logactivity` call
> exactly as you find it — do not change its arguments in this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze (gate, client) | `flutter analyze lib/screens/homescreenpage.dart` | No new errors/warnings |
| Flutter binary | If not on PATH: `/Users/cfournier/Flutter SDK/flutter/bin/flutter` | — |
| Apply migration (operator) | `supabase db push` (from repo root, with linked project) | migration applied, function created |

> **Verification reality**: there is no test suite and you may not have a
> Supabase instance. The **client** change is gated by `flutter analyze`. The
> **migration** is created as a file matching the repo's conventions; applying
> and end-to-end-verifying it is an operator step (see Step 4). Do not claim the
> bug is fixed end-to-end until the migration is applied.

## Scope

**In scope**:
- `supabase/migrations/20260613000001_signup_for_timeslot.sql` (create)
- `lib/screens/homescreenpage.dart` (only the `_signUpForTimeSlot` body)

**Out of scope**:
- The **cancel/unsignup** path (`number_of_people + 1`) — it has a milder version
  of the same race but is deferred to keep this change focused; note it in
  Maintenance.
- The admin event-creation capacity writes in `admineventspage.dart`.
- Any change to how events are fetched/rendered.

## Git workflow

- Branch: `advisor/003-prevent-timeslot-oversell`
- Commit the migration and the client change together; subject e.g.
  `Make timeslot signup atomic via RPC`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Create the atomic signup migration

Create `supabase/migrations/20260613000001_signup_for_timeslot.sql` with exactly
this content:

```sql
-- Atomic, race-free time-slot signup.
--
-- The previous client flow did check-then-act on stale in-memory capacity, so
-- concurrent signups could oversell a slot. This function locks the slot row
-- (FOR UPDATE), enforces capacity and duplicate checks, inserts the attendee,
-- and decrements capacity — all in one transaction. Returns a status string:
--   'ok'      — signed up
--   'full'    — no capacity left
--   'already' — user already signed up for this slot

create or replace function public.signup_for_timeslot(
  p_timeslot_id bigint,
  p_user_id uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining integer;
begin
  -- Lock the slot row so concurrent signups serialize on it.
  select number_of_people
    into v_remaining
    from "Time slots"
   where id = p_timeslot_id
   for update;

  if v_remaining is null then
    return 'full'; -- slot does not exist; treat as unavailable
  end if;

  -- Already signed up? (idempotent)
  if exists (
    select 1 from "Attendees"
     where timeslot_id = p_timeslot_id and user_id = p_user_id
  ) then
    return 'already';
  end if;

  if v_remaining <= 0 then
    return 'full';
  end if;

  insert into "Attendees" (timeslot_id, user_id, is_present, forms_completed)
  values (p_timeslot_id, p_user_id, false, false);

  update "Time slots"
     set number_of_people = number_of_people - 1
   where id = p_timeslot_id;

  return 'ok';
end;
$$;

grant execute on function public.signup_for_timeslot(bigint, uuid) to authenticated;
```

**Verify**: `test -f supabase/migrations/20260613000001_signup_for_timeslot.sql && grep -c "signup_for_timeslot" supabase/migrations/20260613000001_signup_for_timeslot.sql` → file exists, count ≥ 2.

> If the `"Attendees"` table is actually unquoted/lowercase, or `id` is `uuid`
> not `bigint`, the function will fail when applied. If you can inspect the live
> schema and the types differ from the "Known schema facts" above, STOP and
> report the actual types — do not guess.

### Step 2: Replace the racy client block with an RPC call

In `_signUpForTimeSlot`, replace the entire block shown in "Current state"
(from `// Check if the user is already signed up` through the closing `}` of
`if (existingAttendee == null) { ... }`) with:

```dart
        // Atomic signup — see supabase/migrations/.._signup_for_timeslot.sql.
        // Returns 'ok' | 'full' | 'already'.
        final status = await Supabase.instance.client.rpc(
          'signup_for_timeslot',
          params: {
            'p_timeslot_id': timeSlot.id,
            'p_user_id': userId,
          },
        ) as String?;

        if (status == 'ok') {
          await logactivity(
            event.name,
            '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
            NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
            'signup',
            userId,
          );
          hapticsProvider.success();
          _fetchEvents();
        } else if (status == 'full') {
          hapticsProvider.error();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This time slot is now full.')),
            );
          }
        } else if (status == 'already') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("You're already signed up for this slot.")),
            );
          }
        }
```

Notes:
- If Plan 002 has landed, the `logactivity` call here will already include
  `societyId: society?.id` in the surrounding code style — keep it consistent
  with whatever 002 produced (add `societyId: society?.id,` if 002 is done).
- Leave the rest of `_signUpForTimeSlot` (the requirement/delay checks above and
  the `catch (e)` below) untouched.

**Verify**: `grep -n "signup_for_timeslot" lib/screens/homescreenpage.dart` → one match; `grep -n "number_of_people': timeSlot.numberOfPeople - 1" lib/screens/homescreenpage.dart` → **no** matches.

### Step 3: Analyze the client change

**Verify**: `flutter analyze lib/screens/homescreenpage.dart` → no new errors/warnings.

### Step 4: (Operator) Apply and verify the migration

This step likely requires the operator (Supabase CLI linked to the project, or
the dashboard). If you cannot run it, report that Steps 1–3 are done and Step 4
is pending.

- Apply: `supabase db push` (or run the SQL in the Supabase SQL editor).
- Verify the function exists and behaves:
  - Signing up for a slot with `number_of_people = 1` returns `ok` and leaves the
    count at `0`.
  - A second concurrent/subsequent signup returns `full` and does **not** insert
    a second attendee or push the count negative.
  - Signing up twice as the same user returns `already`.

## Test plan

No automated harness exists. Verification is:
- Client: `flutter analyze` clean (Step 3).
- Behavior: the operator checks in Step 4 (capacity enforced, no oversell, no
  negative counts, idempotent re-signup).
- If a test baseline is added later, add an integration test that fires two
  concurrent `signup_for_timeslot` calls against a 1-capacity slot and asserts
  exactly one `ok` and one `full`.

## Done criteria

ALL must hold:

- [ ] `supabase/migrations/20260613000001_signup_for_timeslot.sql` exists with the function + grant
- [ ] `_signUpForTimeSlot` calls `rpc('signup_for_timeslot', ...)` and handles `ok`/`full`/`already`
- [ ] `grep -n "number_of_people': timeSlot.numberOfPeople - 1" lib/screens/homescreenpage.dart` returns no matches
- [ ] `flutter analyze lib/screens/homescreenpage.dart` introduces no new errors/warnings
- [ ] `git status` shows only the migration file and `homescreenpage.dart` modified
- [ ] Operator step 4 either completed or explicitly reported as pending
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- The live `"Attendees"`/`"Time slots"` schema (table casing/quoting, `id` type)
  differs from "Known schema facts" — the SQL would be wrong.
- The racy block in "Current state" doesn't match the live code (drift).
- `flutter analyze` reports a new error from the RPC call that a one-line fix
  doesn't resolve (e.g. the `rpc` return cast).
- You're unsure whether to add `societyId` to `logactivity` (depends on Plan 002
  state) — ask rather than guess.

## Maintenance notes

- **Deploy order matters**: the migration must be applied *before* shipping the
  client change, or signup will fail (function not found). Note this in the PR.
- The **cancel/unsignup** path still does `number_of_people + 1` non-atomically
  (`homescreenpage.dart` ~line 2411) and the admin capacity writes are also
  non-atomic — deferred here. A natural follow-up is a symmetric
  `cancel_timeslot_signup` RPC.
- This function is `security definer`; a reviewer should confirm it only ever
  acts on the `p_user_id` passed and cannot be used to sign up arbitrary users
  beyond what RLS already allows. Consider deriving the user from `auth.uid()`
  inside the function instead of trusting `p_user_id` if RLS on `Attendees` is
  not strict.
