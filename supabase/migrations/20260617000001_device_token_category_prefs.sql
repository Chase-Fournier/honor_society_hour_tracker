-- Per-device notification category preferences.
--
-- The Flutter client exposes per-category toggles (meeting notes, hour
-- updates, swap requests) in Settings, but until now they were stored only
-- in on-device SharedPreferences and never consulted server-side, so the
-- server kept pushing every category regardless. Persist them per device
-- token (matching the on-device semantics: a toggle affects the device that
-- set it) so the send-push Edge Function can skip tokens that opted out.

alter table public.device_tokens
  add column if not exists notify_meeting_notes boolean not null default true,
  add column if not exists notify_hour_updates  boolean not null default true,
  add column if not exists notify_swap_requests boolean not null default true;
