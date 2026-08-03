// GENERATED from a read-only dump of the live Supabase `public` schema.
//
//   supabase db dump --linked --schema public -f <file>
//
// Captured 2026-08-03. This is the app's schema contract made explicit: tests
// assert that every column the app names actually exists upstream, which is the
// one class of breakage hand-written fixtures cannot catch on their own.
//
// Regenerate after any schema change. If a test fails against this file, either
// the app is querying something that no longer exists, or this snapshot is
// stale -- check which before "fixing" the test.

/// Table name -> column names, exactly as they exist in production.
const Map<String, Set<String>> liveSchema = {
  'Attendees': {
    'created_at',
    'forms_completed',
    'id',
    'is_present',
    'timeslot_id',
    'user_id'
  },
  'Collections': {'created_at', 'event_ids', 'id', 'name', 'society_id'},
  'Events': {
    'attendees',
    'collection_id',
    'created_at',
    'date',
    'delay_hours',
    'description',
    'form_link',
    'has_delay',
    'id',
    'isMandatory',
    'location',
    'name',
    'requires_forms',
    'society_id',
    'swap_request_deadline_hours',
    'timeSlots',
    'type'
  },
  'Notes': {'content', 'created_at', 'id', 'society_id', 'text', 'title'},
  'Service hours': {
    'attendee_name',
    'created_at',
    'date',
    'event_description',
    'event_name',
    'hours',
    'id',
    'society_id',
    'timeslot',
    'timeslot_id',
    'type',
    'user_id'
  },
  'Time slots': {
    'created_at',
    'end_time',
    'event_id',
    'id',
    'notes',
    'number_of_people',
    'start_time'
  },
  'activity_logs': {
    'action_type',
    'created_at',
    'event_name',
    'hours',
    'id',
    'new_user_id',
    'old_user_id',
    'society_id',
    'timeslot',
    'user_id'
  },
  'continuous_event_submissions': {
    'activity_date',
    'continuous_event_id',
    'created_at',
    'hours',
    'id',
    'notes',
    'proof_link',
    'reviewed_at',
    'reviewer_id',
    'reviewer_notes',
    'service_hours_id',
    'society_id',
    'status',
    'user_id'
  },
  'continuous_events': {
    'allow_multiple_submissions',
    'created_at',
    'created_by',
    'description',
    'icon_name',
    'id',
    'is_active',
    'name',
    'society_id',
    'steps',
    'type',
    'updated_at'
  },
  'device_tokens': {
    'fcm_token',
    'id',
    'notify_hour_updates',
    'notify_meeting_notes',
    'notify_swap_requests',
    'platform',
    'updated_at',
    'user_id'
  },
  'honor_societies': {
    'created_at',
    'description',
    'error_form_url',
    'id',
    'image_url',
    'meeting_requirement',
    'name'
  },
  'hour_requirements': {
    'created_at',
    'description',
    'hours_needed',
    'icon_name',
    'id',
    'is_active',
    'society_id',
    'type'
  },
  'leadership_roles': {
    'created_at',
    'description',
    'display_order',
    'email',
    'holder_name',
    'id',
    'is_active',
    'phone',
    'society_id',
    'title'
  },
  'profiles': {
    'admin',
    'color',
    'created_at',
    'email',
    'graduation_year',
    'has_paid_dues',
    'id',
    'name',
    'user_id'
  },
  'snake_scores': {'created_at', 'game', 'id', 'score', 'user_id'},
  'society_join_requests': {
    'created_at',
    'id',
    'processed_at',
    'processed_by',
    'requested_at',
    'society_id',
    'status',
    'user_id'
  },
  'swap_requests': {
    'created_at',
    'event_id',
    'id',
    'requester_id',
    'status',
    'target_id',
    'timeslot_id'
  },
  'user_society_memberships': {
    'created_at',
    'has_paid_dues',
    'is_admin',
    'notify_continuous_submissions',
    'society_id',
    'user_id'
  },
};

/// Functions callable via `.rpc()` in the live database.
const Set<String> liveFunctions = {
  'enforce_continuous_submission_limit',
  'handle_new_user',
  'notify_continuous_submission',
  'notify_hours_update',
  'notify_new_meeting_note',
  'notify_swap_request',
  'send_push_to_society',
  'send_push_to_users',
  'signup_for_timeslot',
  'update_profile_user_id',
};
