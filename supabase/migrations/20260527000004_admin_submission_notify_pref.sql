-- Let each admin choose whether they receive the "hours submitted for review"
-- push for continuous events. Stored per society membership so an admin of
-- multiple societies can decide independently. Default on.

alter table public.user_society_memberships
  add column if not exists notify_continuous_submissions boolean not null default true;

-- Recreate the submission-notify trigger function to honour the preference.
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
      and coalesce(usm.notify_continuous_submissions, true) = true
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
