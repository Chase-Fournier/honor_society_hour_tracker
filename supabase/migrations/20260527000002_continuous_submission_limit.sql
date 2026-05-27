-- The original partial unique index blocked a second *pending* submission for
-- every continuous event. But events flagged allow_multiple_submissions should
-- permit multiple pending submissions (e.g. weekly tutoring logs). Only
-- single-submission events should be limited.
--
-- A partial unique index can't reference the parent event's flag, so replace it
-- with a BEFORE INSERT trigger that enforces the limit conditionally.

drop index if exists public.ces_one_pending_per_user_event;

create or replace function public.enforce_continuous_submission_limit()
returns trigger
language plpgsql
as $$
declare
  allows_multiple boolean;
  existing_count integer;
begin
  select allow_multiple_submissions
    into allows_multiple
    from public.continuous_events
   where id = new.continuous_event_id;

  -- Missing/multi-submission event: no limit (FK handles missing parent).
  if allows_multiple is null or allows_multiple then
    return new;
  end if;

  -- Single-submission event: block if the user already has a pending or
  -- approved submission. A prior rejection does not consume their one chance.
  select count(*)
    into existing_count
    from public.continuous_event_submissions
   where continuous_event_id = new.continuous_event_id
     and user_id = new.user_id
     and status in ('pending', 'approved');

  if existing_count > 0 then
    raise exception 'continuous_submission_limit: only one submission is allowed for this opportunity'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_continuous_submission_limit
  on public.continuous_event_submissions;
create trigger trg_continuous_submission_limit
  before insert on public.continuous_event_submissions
  for each row
  execute function public.enforce_continuous_submission_limit();
