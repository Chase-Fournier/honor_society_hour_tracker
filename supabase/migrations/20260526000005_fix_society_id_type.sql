-- The honor_societies.id column is bigint, but send_push_to_society() took
-- integer. Postgres won't implicitly narrow bigint -> integer, so the
-- meeting-notes trigger failed with "function does not exist".
--
-- Drop and recreate with the correct type. Has to be drop+create (not
-- create-or-replace) because changing parameter types isn't allowed in place.

drop function if exists public.send_push_to_society(integer, text, text, jsonb, uuid);

create or replace function public.send_push_to_society(
  p_society_id bigint,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb,
  p_exclude_user uuid default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  recipients uuid[];
begin
  select array_agg(distinct usm.user_id)
    into recipients
    from public.user_society_memberships usm
    where usm.society_id = p_society_id
      and (p_exclude_user is null or usm.user_id <> p_exclude_user);

  if recipients is not null then
    perform public.send_push_to_users(recipients, p_title, p_body, p_data);
  end if;
end;
$$;
