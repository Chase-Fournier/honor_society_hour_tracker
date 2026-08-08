import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/attendance.dart';

import '../helpers/fixtures.dart';

void main() {
  AttendanceChanges changesFor(
    List<dynamic> roster, {
    Set<String> existing = const {},
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
    TimeOfDay end = const TimeOfDay(hour: 11, minute: 30),
    int? societyId = 1,
  }) =>
      attendanceChangesFor(
        attendees: roster.cast(),
        userIdsWithExistingHours: existing,
        event: event(name: 'Park Cleanup', type: 'Service'),
        timeSlot: timeSlot(id: 10, time: start, endTime: end),
        societyId: societyId,
      );

  group('inserting hours', () {
    test('a present member with no hours gets a row', () {
      final changes = changesFor([attendee(userId: 'u1', isPresent: true)]);

      expect(changes.hoursToInsert, hasLength(1));
      expect(changes.hoursToInsert.single.userId, 'u1');
      expect(changes.userIdsToClear, isEmpty);
    });

    test('the row carries the slot duration', () {
      final changes = changesFor([attendee(isPresent: true)]);
      expect(changes.hoursToInsert.single.hours, 2.5);
    });

    // Closes the loop on the durationInHours fix: this is the only place that
    // value reaches the database, and it used to be written as -20.0.
    test('an overnight slot credits positive hours', () {
      final changes = changesFor(
        [attendee(isPresent: true)],
        start: const TimeOfDay(hour: 22, minute: 0),
        end: const TimeOfDay(hour: 2, minute: 0),
      );

      expect(changes.hoursToInsert.single.hours, 4.0);
      expect(changes.hoursToInsert.single.hours, greaterThan(0));
    });

    test('the row uses the event name, type, date and society', () {
      final row = changesFor([attendee(isPresent: true)]).hoursToInsert.single;

      expect(row.eventName, 'Park Cleanup');
      expect(row.type, 'Service');
      expect(row.societyId, 1);
      expect(row.timeSlotId, 10);
      expect(row.date, DateTime(2026, 9, 15));
    });

    test('serialises to the Service hours column names', () {
      final json = changesFor([attendee(userId: 'u1', isPresent: true)])
          .hoursToInsert
          .single
          .toJson();

      expect(json.keys.toSet(), {
        'user_id',
        'event_name',
        'timeslot_id',
        'hours',
        'date',
        'type',
        'society_id',
      });
      expect(json['user_id'], 'u1');
    });

    test('tolerates a null society', () {
      final changes = changesFor([attendee(isPresent: true)], societyId: null);
      expect(changes.hoursToInsert.single.societyId, isNull);
    });
  });

  group('idempotence', () {
    // Re-saving a roster must not double-credit. The screen's original loop
    // guarded this with a per-attendee select; the guard now lives here.
    test('a present member who already has hours gets nothing', () {
      final changes = changesFor(
        [attendee(userId: 'u1', isPresent: true)],
        existing: {'u1'},
      );

      expect(changes.hoursToInsert, isEmpty);
      expect(changes.userIdsToClear, isEmpty);
    });

    test('applying the same roster twice is stable', () {
      final roster = [attendee(userId: 'u1', isPresent: true)];

      final first = changesFor(roster);
      expect(first.hoursToInsert, hasLength(1));

      // Second save, now that the row exists.
      final second = changesFor(roster, existing: {'u1'});
      expect(second.hoursToInsert, isEmpty);
      expect(second.userIdsToClear, isEmpty);
    });
  });

  group('clearing hours', () {
    test('an absent member with hours has them removed', () {
      final changes = changesFor(
        [attendee(userId: 'u1', isPresent: false)],
        existing: {'u1'},
      );

      expect(changes.userIdsToClear, ['u1']);
      expect(changes.hoursToInsert, isEmpty);
    });

    test('an absent member with no hours is left alone', () {
      final changes = changesFor([attendee(userId: 'u1', isPresent: false)]);

      expect(changes.userIdsToClear, isEmpty);
      expect(changes.hoursToInsert, isEmpty);
    });
  });

  group('presence', () {
    test('every attendee gets a presence entry regardless of hours', () {
      final changes = changesFor([
        attendee(id: 1, userId: 'u1', isPresent: true),
        attendee(id: 2, userId: 'u2', isPresent: false),
        attendee(id: 3, userId: 'u3', isPresent: true),
      ], existing: {
        'u3'
      });

      expect(changes.presenceByAttendeeId, {1: true, 2: false, 3: true});
    });
  });

  group('mixed rosters', () {
    test('inserts, clears and leaves alone in one pass', () {
      final changes = changesFor([
        attendee(id: 1, userId: 'new-present', isPresent: true),
        attendee(id: 2, userId: 'was-present', isPresent: false),
        attendee(id: 3, userId: 'still-present', isPresent: true),
        attendee(id: 4, userId: 'still-absent', isPresent: false),
      ], existing: {
        'was-present',
        'still-present',
      });

      expect(changes.hoursToInsert.map((r) => r.userId), ['new-present']);
      expect(changes.userIdsToClear, ['was-present']);
      expect(changes.presenceByAttendeeId, hasLength(4));
    });

    test('an empty roster produces no changes', () {
      final changes = changesFor(const []);
      expect(changes.isEmpty, isTrue);
    });
  });
}
