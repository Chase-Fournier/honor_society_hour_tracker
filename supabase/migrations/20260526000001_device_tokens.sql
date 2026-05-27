-- device_tokens: one row per FCM token per device.
-- Upserted by the Flutter client on sign-in / token refresh.

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'other')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "Users manage their own tokens" on public.device_tokens;
create policy "Users manage their own tokens"
  on public.device_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
