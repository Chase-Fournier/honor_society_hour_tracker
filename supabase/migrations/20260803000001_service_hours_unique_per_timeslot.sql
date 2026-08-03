-- Prevent double-crediting service hours for the same time slot.
--
-- The attendance screen decided whether to insert hours by reading
-- "Service hours" and then writing based on that read. That check-then-act
-- pattern is the same race `signup_for_timeslot` was written to remove for
-- capacity: two admins saving the same roster concurrently both observe "no
-- existing row" and both insert, crediting the member twice. A member could
-- also be double-credited by one admin double-tapping save on a slow network.
--
-- The client is now batched and idempotent, but the client cannot make this
-- safe on its own -- only the database can. A partial unique index makes the
-- second insert fail instead of succeeding quietly.
--
-- !! THIS MIGRATION DELETES ROWS. The unique index cannot be created while
-- duplicates exist, so step 1 removes them, keeping the earliest row of each
-- duplicate set. Review the audit query below against production before
-- applying.

-- Step 0 (manual, not executed): count what step 1 would delete.
--
--   select "user_id", "timeslot_id", count(*), min("id") as keeping
--     from public."Service hours"
--    where "timeslot_id" is not null
--    group by "user_id", "timeslot_id"
--   having count(*) > 1;

begin;

-- Step 1: drop duplicates, keeping the earliest id per (user_id, timeslot_id).
--
-- Scoped to rows with a timeslot_id. Manually logged hours have a null
-- timeslot_id, are not tied to a slot, and are legitimately repeatable, so they
-- are left completely alone.
delete from public."Service hours" a
      using public."Service hours" b
      where a."timeslot_id" is not null
        and b."timeslot_id" is not null
        and a."user_id" is not null
        and a."user_id" = b."user_id"
        and a."timeslot_id" = b."timeslot_id"
        and a."id" > b."id";

-- Step 2: make it impossible to reintroduce.
--
-- Partial, so the many manually logged rows with a null timeslot_id are
-- unaffected. Postgres treats NULLs as distinct anyway, but being explicit
-- documents the intent and keeps the index small.
create unique index if not exists "service_hours_one_per_user_per_timeslot"
    on public."Service hours" ("user_id", "timeslot_id")
 where "timeslot_id" is not null and "user_id" is not null;

commit;

-- After this, a concurrent duplicate insert raises unique_violation (23505)
-- rather than silently double-crediting. The attendance screen surfaces the
-- error; a future refinement is to catch 23505 specifically and treat it as
-- "already credited", which is the correct interpretation.
