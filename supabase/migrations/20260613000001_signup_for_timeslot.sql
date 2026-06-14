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
