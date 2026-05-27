-- Helper functions that database triggers use to invoke the send-push
-- Edge Function. Requires pg_net for HTTP calls.

create extension if not exists pg_net;

-- The Edge Function URL and a shared secret are read from app settings.
-- Set them once per database with:
--   alter database postgres set app.settings.edge_url     = 'https://<project>.functions.supabase.co';
--   alter database postgres set app.settings.service_role_key = '<your service role key>';

create or replace function public.send_push_to_users(
  p_user_ids uuid[],
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  service_key text;
begin
  -- Skip silently if no recipients
  if p_user_ids is null or array_length(p_user_ids, 1) is null then
    return;
  end if;

  edge_url := current_setting('app.settings.edge_url', true);
  service_key := current_setting('app.settings.service_role_key', true);

  if edge_url is null or service_key is null then
    raise notice 'send_push_to_users: app.settings.edge_url or service_role_key not set; skipping.';
    return;
  end if;

  perform net.http_post(
    url := edge_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'user_ids', to_jsonb(p_user_ids),
      'title', p_title,
      'body', p_body,
      'data', p_data
    )
  );
end;
$$;

-- Convenience: notify all members of a society except an optional excluded user.
create or replace function public.send_push_to_society(
  p_society_id integer,
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
