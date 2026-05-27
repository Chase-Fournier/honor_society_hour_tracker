-- Triggers that push notifications based on table activity.
--
-- Tables referenced (existing in this project):
--   public."Notes"           - meeting notes (society_id, title)
--   public.activity_logs     - audit log (user_id, action_type, event_name, hours)
--   public.swap_requests     - swap workflow (requester_id, target_id, status)

-- =====================================================================
-- 1) New meeting note → notify all society members (except the author).
-- =====================================================================

create or replace function public.notify_new_meeting_note()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.send_push_to_society(
    NEW.society_id,
    'New meeting notes',
    coalesce(NEW.title, 'A new note has been posted'),
    jsonb_build_object(
      'type', 'meeting_notes',
      'note_id', NEW.id,
      'society_id', NEW.society_id
    ),
    null
  );
  return NEW;
end;
$$;

drop trigger if exists trg_notes_after_insert on public."Notes";
create trigger trg_notes_after_insert
  after insert on public."Notes"
  for each row execute procedure public.notify_new_meeting_note();


-- =====================================================================
-- 2) Hours updated by admin → notify the affected member.
--    Fires only for attendance / manual-event actions, never for the user's
--    own sign-up/unsign-up actions.
-- =====================================================================

create or replace function public.notify_hours_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  msg_title text;
  msg_body text;
begin
  if NEW.action_type not in (
    'attendance_marked',
    'attendance_removed',
    'manual_addition',
    'manual_deletion'
  ) then
    return NEW;
  end if;

  case NEW.action_type
    when 'attendance_marked' then
      msg_title := 'Attendance confirmed';
      msg_body := 'You were marked present at ' || coalesce(NEW.event_name, 'an event') ||
                  ' (' || coalesce(NEW.hours::text, '0') || ' hrs).';
    when 'attendance_removed' then
      msg_title := 'Attendance removed';
      msg_body := 'Your attendance was removed from ' || coalesce(NEW.event_name, 'an event') || '.';
    when 'manual_addition' then
      msg_title := 'Hours added';
      msg_body := coalesce(NEW.hours::text, '0') || ' hrs added for ' || coalesce(NEW.event_name, 'a manual event') || '.';
    when 'manual_deletion' then
      msg_title := 'Hours removed';
      msg_body := 'Hours for ' || coalesce(NEW.event_name, 'a manual event') || ' were removed.';
  end case;

  perform public.send_push_to_users(
    array[NEW.user_id]::uuid[],
    msg_title,
    msg_body,
    jsonb_build_object(
      'type', 'hours',
      'action', NEW.action_type,
      'event_name', NEW.event_name,
      'hours', NEW.hours
    )
  );
  return NEW;
end;
$$;

drop trigger if exists trg_activity_logs_hours_notify on public.activity_logs;
create trigger trg_activity_logs_hours_notify
  after insert on public.activity_logs
  for each row execute procedure public.notify_hours_update();


-- =====================================================================
-- 3) Swap requests → notify the relevant counterparty.
--    INSERT  → target_id gets "incoming swap request"
--    UPDATE  → requester_id gets "accepted" / "declined"
-- =====================================================================

create or replace function public.notify_swap_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_name text;
begin
  if (TG_OP = 'INSERT') then
    select coalesce(p.name, 'A member')
      into requester_name
      from public.profiles p
      where p.user_id = NEW.requester_id;

    perform public.send_push_to_users(
      array[NEW.target_id]::uuid[],
      'Swap request',
      requester_name || ' wants to swap an event slot with you.',
      jsonb_build_object(
        'type', 'swap',
        'action', 'requested',
        'swap_id', NEW.id,
        'event_id', NEW.event_id,
        'timeslot_id', NEW.timeslot_id
      )
    );
    return NEW;
  end if;

  if (TG_OP = 'UPDATE') and (OLD.status is distinct from NEW.status) then
    if NEW.status = 'accepted' then
      perform public.send_push_to_users(
        array[NEW.requester_id]::uuid[],
        'Swap accepted',
        'Your swap request was accepted.',
        jsonb_build_object('type', 'swap', 'action', 'accepted', 'swap_id', NEW.id)
      );
    elsif NEW.status in ('declined', 'denied') then
      perform public.send_push_to_users(
        array[NEW.requester_id]::uuid[],
        'Swap declined',
        'Your swap request was declined.',
        jsonb_build_object('type', 'swap', 'action', 'declined', 'swap_id', NEW.id)
      );
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_swap_requests_after_insert on public.swap_requests;
create trigger trg_swap_requests_after_insert
  after insert on public.swap_requests
  for each row execute procedure public.notify_swap_request();

drop trigger if exists trg_swap_requests_after_update on public.swap_requests;
create trigger trg_swap_requests_after_update
  after update on public.swap_requests
  for each row execute procedure public.notify_swap_request();
