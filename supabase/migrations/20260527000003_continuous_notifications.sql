-- Push notifications for continuous (ongoing) event submissions.
--
--   1) Member submits hours  → notify society admins (review queue).
--   2) Admin approves/rejects → notify the submitting member.
--
-- (1) is a new trigger on continuous_event_submissions.
-- (2) reuses the existing activity_logs trigger by extending notify_hours_update
--     to recognise the continuous_submission_* action types that the approve /
--     reject / undo flows already write via logactivity().

-- =====================================================================
-- 1) New submission → notify the society's admins (not the submitter).
-- =====================================================================

create or replace function public.notify_continuous_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_ids uuid[];
  submitter_name text;
  ce_name text;
begin
  select array_agg(usm.user_id)
    into admin_ids
    from public.user_society_memberships usm
    where usm.society_id = NEW.society_id
      and usm.is_admin = true
      and usm.user_id <> NEW.user_id;

  if admin_ids is null then
    return NEW;
  end if;

  select coalesce(p.name, 'A member')
    into submitter_name
    from public.profiles p
    where p.user_id = NEW.user_id;

  select ce.name
    into ce_name
    from public.continuous_events ce
    where ce.id = NEW.continuous_event_id;

  perform public.send_push_to_users(
    admin_ids,
    'Hours submitted for review',
    coalesce(submitter_name, 'A member') || ' submitted ' ||
      coalesce(NEW.hours::text, '0') || ' hrs for ' ||
      coalesce(ce_name, 'an ongoing opportunity') || '.',
    jsonb_build_object(
      'type', 'continuous_submission',
      'action', 'submitted',
      'submission_id', NEW.id,
      'continuous_event_id', NEW.continuous_event_id,
      'society_id', NEW.society_id
    )
  );
  return NEW;
end;
$$;

drop trigger if exists trg_continuous_submission_notify
  on public.continuous_event_submissions;
create trigger trg_continuous_submission_notify
  after insert on public.continuous_event_submissions
  for each row execute procedure public.notify_continuous_submission();


-- =====================================================================
-- 2) Extend notify_hours_update to cover continuous submission outcomes.
--    Recreated in full (create-or-replace) with the new action types added.
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
    'manual_deletion',
    'continuous_submission_approved',
    'continuous_submission_rejected',
    'continuous_submission_undone'
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
    when 'continuous_submission_approved' then
      msg_title := 'Hours approved';
      msg_body := 'Your ' || coalesce(NEW.hours::text, '0') || ' hrs for ' ||
                  coalesce(NEW.event_name, 'an ongoing opportunity') || ' were approved.';
    when 'continuous_submission_rejected' then
      msg_title := 'Submission rejected';
      msg_body := 'Your hours submission for ' || coalesce(NEW.event_name, 'an ongoing opportunity') ||
                  ' was rejected.';
    when 'continuous_submission_undone' then
      msg_title := 'Submission reopened';
      msg_body := 'Your submission for ' || coalesce(NEW.event_name, 'an ongoing opportunity') ||
                  ' is under review again.';
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
