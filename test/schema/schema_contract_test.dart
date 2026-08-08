// Contract tests between the app and the real database schema.
//
// Everything else in this suite validates the app against fixtures the app's
// own authors wrote, so a column renamed upstream leaves every test green while
// production breaks. These tests compare against `live_schema.dart`, generated
// from a read-only dump of the live `public` schema.
//
// They are still a snapshot, not a live connection -- regenerating is a manual
// step. But a stale snapshot is a visible, dated artifact, which is strictly
// better than an implicit assumption spread across a hundred fixtures.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import 'live_schema.dart';

/// RPC names the app calls via `supabase.rpc(...)`.
///
/// Kept in step with `grep -rn "\.rpc(" lib/`.
const appRpcCalls = {
  'signup_for_timeslot': 'lib/screens/homescreenpage.dart',
  'request_society_membership': 'lib/providers/societyprovider.dart',
  'create_society': 'lib/providers/societyprovider.dart',
};

/// Tables the app queries via `supabase.from(...)`.
const appTables = {
  'activity_logs',
  'Attendees',
  'Collections',
  'continuous_event_submissions',
  'continuous_events',
  'device_tokens',
  'Events',
  'honor_societies',
  'hour_requirements',
  'leadership_roles',
  'Notes',
  'profiles',
  'Service hours',
  'snake_scores',
  'society_join_requests',
  'swap_requests',
  'Time slots',
  'user_society_memberships',
};

void main() {
  group('tables', () {
    test('every table the app queries exists upstream', () {
      final missing = appTables.difference(liveSchema.keys.toSet());
      expect(missing, isEmpty,
          reason: 'the app queries tables that do not exist: $missing');
    });

    test('the snapshot covers all 18 known tables', () {
      expect(liveSchema, hasLength(18));
    });
  });

  group('functions', () {
    // This is the check that earns the snapshot its keep: it caught two RPCs
    // the app calls that do not exist in the database at all.
    test('signup_for_timeslot exists', () {
      expect(liveFunctions, contains('signup_for_timeslot'));
    });

    test('documents which app RPCs are missing upstream', () {
      final missing = {
        for (final entry in appRpcCalls.entries)
          if (!liveFunctions.contains(entry.key)) entry.key: entry.value,
      };

      // Known-missing, and both callers are dead code -- see the header of
      // test/providers/societyprovider_writes_test.dart. Asserting the exact
      // set means wiring either one up without creating the function fails
      // here, and creating the function makes this test demand an update.
      expect(missing.keys.toSet(), {
        'request_society_membership',
        'create_society',
      });
    });
  });

  group('fixtures match the real schema', () {
    /// Embedded PostgREST joins appear as keys but are tables, not columns.
    bool isJoin(String key) => liveSchema.containsKey(key);

    void checkRow(String table, Map<String, dynamic> row) {
      final columns = liveSchema[table];
      expect(columns, isNotNull, reason: 'unknown table "$table"');

      for (final key in row.keys) {
        if (isJoin(key)) continue;
        expect(columns, contains(key),
            reason: '"$table" fixture names "$key", '
                'which is not a column in the live schema');
      }
    }

    test('eventRow', () => checkRow('Events', eventRow()));
    test('timeSlotRow', () => checkRow('Time slots', timeSlotRow()));
    test('hourRequirementRow',
        () => checkRow('hour_requirements', hourRequirementRow()));
    test('honorSocietyRow',
        () => checkRow('honor_societies', honorSocietyRow()));
    test('membershipRow',
        () => checkRow('user_society_memberships', membershipRow()));

    test('eventRow with nested time slots', () {
      checkRow('Events', eventRow(timeSlots: [timeSlotRow()]));
    });
  });

  group('columns the app depends on by name', () {
    // Spot-checks for the mappings most likely to be "tidied up" by someone
    // who has not read the schema.
    test('Events really does use camelCase for two columns', () {
      // Event.fromJson reads json['isMandatory'] and json['timeSlots'] among
      // otherwise snake_case keys. That looks like a bug until you see the
      // actual column names.
      expect(liveSchema['Events'], contains('isMandatory'));
      expect(liveSchema['Events'], contains('timeSlots'));
      expect(liveSchema['Events'], isNot(contains('is_mandatory')));
    });

    test('Service hours carries the columns attendance writes', () {
      expect(
        liveSchema['Service hours'],
        containsAll([
          'user_id',
          'event_name',
          'timeslot_id',
          'hours',
          'date',
          'type',
          'society_id'
        ]),
      );
    });

    test(
        'swap_requests uses target_id, which SwapRequest maps to '
        'currentAttendeeId', () {
      expect(liveSchema['swap_requests'], contains('target_id'));
    });

    test('Attendees carries the flags the attendance screen toggles', () {
      expect(liveSchema['Attendees'],
          containsAll(['is_present', 'forms_completed', 'timeslot_id']));
    });

    test('user_society_memberships carries the admin flag', () {
      expect(liveSchema['user_society_memberships'], contains('is_admin'));
    });
  });
}
