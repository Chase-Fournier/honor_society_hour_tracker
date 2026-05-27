-- continuous_events: admin-defined ongoing opportunities (no date, no time slots).
-- Members submit hours with a proof link; admins approve/reject. Approved
-- submissions write a row into "Service hours" so they show up in
-- CompletedHoursPage alongside attendance-credited hours.

create table if not exists public.continuous_events (
  id            bigint generated always as identity primary key,
  society_id    bigint not null references public.honor_societies(id) on delete cascade,
  name          text   not null,
  description   text   not null default '',
  type          text   not null,
  icon_name     text   not null default 'workspaces',
  steps         jsonb  not null default '[]'::jsonb,
  allow_multiple_submissions boolean not null default true,
  is_active     boolean not null default true,
  created_by    uuid   references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint continuous_events_steps_max
    check (jsonb_typeof(steps) = 'array' and jsonb_array_length(steps) <= 10)
);

create index if not exists continuous_events_society_idx
  on public.continuous_events (society_id, is_active);

create table if not exists public.continuous_event_submissions (
  id                   bigint generated always as identity primary key,
  continuous_event_id  bigint not null references public.continuous_events(id) on delete cascade,
  society_id           bigint not null references public.honor_societies(id) on delete cascade,
  user_id              uuid   not null references auth.users(id) on delete cascade,
  hours                numeric(6,2) not null check (hours > 0 and hours <= 999),
  activity_date        date   not null,
  proof_link           text   not null,
  notes                text,
  status               text   not null default 'pending'
                         check (status in ('pending','approved','rejected')),
  reviewer_id          uuid   references auth.users(id) on delete set null,
  reviewer_notes       text,
  reviewed_at          timestamptz,
  service_hours_id     bigint,
  created_at           timestamptz not null default now()
);

create index if not exists ces_event_status_idx
  on public.continuous_event_submissions (continuous_event_id, status);
create index if not exists ces_user_idx
  on public.continuous_event_submissions (user_id, status);
create index if not exists ces_society_status_idx
  on public.continuous_event_submissions (society_id, status);

-- Block two simultaneous pending submissions for the same (event, user).
create unique index if not exists ces_one_pending_per_user_event
  on public.continuous_event_submissions (continuous_event_id, user_id)
  where status = 'pending';

alter table public.continuous_events enable row level security;
alter table public.continuous_event_submissions enable row level security;

-- continuous_events policies ------------------------------------------------

drop policy if exists "ce_select_members" on public.continuous_events;
create policy "ce_select_members" on public.continuous_events
  for select using (
    exists (
      select 1 from public.user_society_memberships usm
      where usm.user_id = auth.uid()
        and usm.society_id = continuous_events.society_id
    )
  );

drop policy if exists "ce_write_admins" on public.continuous_events;
create policy "ce_write_admins" on public.continuous_events
  for all
  using (
    exists (
      select 1 from public.user_society_memberships usm
      where usm.user_id = auth.uid()
        and usm.society_id = continuous_events.society_id
        and usm.is_admin = true
    )
  )
  with check (
    exists (
      select 1 from public.user_society_memberships usm
      where usm.user_id = auth.uid()
        and usm.society_id = continuous_events.society_id
        and usm.is_admin = true
    )
  );

-- continuous_event_submissions policies ------------------------------------

drop policy if exists "ces_member_select_own" on public.continuous_event_submissions;
create policy "ces_member_select_own" on public.continuous_event_submissions
  for select using (user_id = auth.uid());

drop policy if exists "ces_member_insert_own" on public.continuous_event_submissions;
create policy "ces_member_insert_own" on public.continuous_event_submissions
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.user_society_memberships usm
      where usm.user_id = auth.uid()
        and usm.society_id = continuous_event_submissions.society_id
    )
  );

drop policy if exists "ces_member_update_pending" on public.continuous_event_submissions;
create policy "ces_member_update_pending" on public.continuous_event_submissions
  for update
  using (user_id = auth.uid() and status = 'pending')
  with check (user_id = auth.uid() and status = 'pending');

drop policy if exists "ces_member_delete_pending" on public.continuous_event_submissions;
create policy "ces_member_delete_pending" on public.continuous_event_submissions
  for delete using (user_id = auth.uid() and status = 'pending');

drop policy if exists "ces_admin_all" on public.continuous_event_submissions;
create policy "ces_admin_all" on public.continuous_event_submissions
  for all
  using (
    exists (
      select 1 from public.user_society_memberships usm
      where usm.user_id = auth.uid()
        and usm.society_id = continuous_event_submissions.society_id
        and usm.is_admin = true
    )
  )
  with check (
    exists (
      select 1 from public.user_society_memberships usm
      where usm.user_id = auth.uid()
        and usm.society_id = continuous_event_submissions.society_id
        and usm.is_admin = true
    )
  );
