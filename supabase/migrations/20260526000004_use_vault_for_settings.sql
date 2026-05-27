-- Replace the helpers from migration 20260526000002 to read configuration
-- from Supabase Vault instead of `current_setting('app.settings.*')`.
--
-- `ALTER DATABASE postgres SET …` requires superuser on Supabase-hosted
-- projects, which the SQL editor doesn't have. Vault is the documented
-- alternative for storing connection settings + secrets.
--
-- After running this migration, populate the two secrets once via the
-- SQL editor (see supabase/README.md §4):
--
--   select vault.create_secret(
--     'https://<project-ref>.functions.supabase.co',
--     'edge_url',
--     'Wheeler NHS Edge Functions base URL');
--
--   select vault.create_secret(
--     '<service-role-key>',
--     'service_role_key',
--     'Used by notification triggers to call send-push');

create extension if not exists pg_net;

create or replace function public.send_push_to_users(
  p_user_ids uuid[],
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  edge_url text;
  service_key text;
begin
  if p_user_ids is null or array_length(p_user_ids, 1) is null then
    return;
  end if;

  select decrypted_secret into edge_url
    from vault.decrypted_secrets
    where name = 'edge_url'
    limit 1;

  select decrypted_secret into service_key
    from vault.decrypted_secrets
    where name = 'service_role_key'
    limit 1;

  if edge_url is null or service_key is null then
    raise notice 'send_push_to_users: vault secrets edge_url / service_role_key not set; skipping.';
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

-- send_push_to_society() does not need to change — it just calls
-- send_push_to_users() — but recreate it to ensure its search_path
-- picks up the new helper.

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
