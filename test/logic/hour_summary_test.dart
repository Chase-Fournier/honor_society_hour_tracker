import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/hour_summary.dart';

import '../helpers/fixtures.dart';

Map<String, dynamic> loggedRow({
  String type = 'Service',
  num hours = 4,
  String eventName = 'Park Cleanup',
  String? date = '2026-08-01T00:00:00.000Z',
}) =>
    {'type': type, 'hours': hours, 'event_name': eventName, 'date': date};

void main() {
  HourSummary summarise({
    List<Map<String, dynamic>> logged = const [],
    List<dynamic> events = const [],
    List<String> types = const ['Service'],
    String userId = 'test-user-id',
  }) =>
      summariseHours(
        loggedRows: logged,
        upcomingEvents: events.cast(),
        requirementTypes: types,
        userId: userId,
      );

  group('seeding', () {
    test('every requirement type starts at zero rather than absent', () {
      final summary = summarise(types: ['Service', 'Tutoring']);

      expect(summary.completedByType['Service'], 0);
      expect(summary.completedByType['Tutoring'], 0);
      expect(summary.potentialByType['Service'], 0);
    });

    test('Meeting is always present, even without a requirement row', () {
      final summary = summarise(types: ['Service']);
      expect(summary.completedByType.containsKey('Meeting'), isTrue);
    });

    // Callers hold raw `hour_requirements.type` strings and are tempted to
    // index the maps with them. The buckets are keyed by normalizeType, so a
    // requirement stored as "service hours" seeds a bucket called
    // "Service Hours" and a raw lookup silently reads 0 off a populated total.
    // homescreenpage.dart's _buildProgressBars normalizes at the lookup; this
    // pins the contract it depends on.
    test('buckets are keyed by the normalized type, not the raw string', () {
      final summary = summarise(
        types: ['service hours', 'TUTORING'],
        logged: [loggedRow(type: 'service hours', hours: 3)],
      );

      expect(summary.completedByType.keys,
          containsAll(['Service Hours', 'Tutoring']));
      expect(summary.completedByType.containsKey('service hours'), isFalse,
          reason: 'indexing with the raw requirement string must not work');
      expect(summary.completedByType['Service Hours'], 3);
      expect(summary.completedFor('service hours'), 3,
          reason: 'completedFor normalizes, so it accepts either form');
    });
  });

  group('completed hours', () {
    test('sums rows of the same type', () {
      final summary = summarise(logged: [
        loggedRow(hours: 4),
        loggedRow(hours: 2.5),
      ]);

      expect(summary.completedFor('Service'), 6.5);
    });

    test('keeps types separate', () {
      final summary = summarise(
        types: ['Service', 'Tutoring'],
        logged: [
          loggedRow(type: 'Service', hours: 4),
          loggedRow(type: 'Tutoring', hours: 3)
        ],
      );

      expect(summary.completedFor('Service'), 4);
      expect(summary.completedFor('Tutoring'), 3);
    });

    // Regression: the original bucketed on the raw string, so hours logged
    // with different casing silently vanished from the member's totals.
    test('matches type case-insensitively', () {
      final summary = summarise(logged: [
        loggedRow(type: 'service', hours: 4),
        loggedRow(type: 'SERVICE', hours: 1),
        loggedRow(type: 'Service', hours: 2),
      ]);

      expect(summary.completedFor('Service'), 7);
    });

    test('lookup is also case-insensitive', () {
      final summary = summarise(logged: [loggedRow(hours: 4)]);
      expect(summary.completedFor('service'), 4);
    });

    test('a type with no matching requirement is not counted', () {
      final summary = summarise(
          types: ['Service'], logged: [loggedRow(type: 'Fundraising')]);

      expect(summary.completedFor('Service'), 0);
      expect(summary.completedByType.containsKey('Fundraising'), isFalse);
    });

    test('treats a missing or unparseable hours value as zero', () {
      final summary = summarise(logged: [
        {'type': 'Service', 'event_name': 'x'},
        loggedRow(hours: 3),
      ]);

      expect(summary.completedFor('Service'), 3);
    });

    test('records the individual entries behind each total', () {
      final summary = summarise(logged: [
        loggedRow(eventName: 'Cleanup', hours: 4),
        loggedRow(eventName: 'Food Drive', hours: 2),
      ]);

      final entries = summary.entriesByType['Service']!;
      expect(entries.map((e) => e.title), ['Cleanup', 'Food Drive']);
      expect(entries.first.hours, 4);
    });

    test('survives a null or malformed date', () {
      final summary = summarise(logged: [
        loggedRow(date: null),
        loggedRow(date: 'not-a-date'),
      ]);

      expect(summary.entriesByType['Service'], hasLength(2));
    });
  });

  group('potential hours', () {
    List<dynamic> eventSignedUp({
      String type = 'Service',
      bool isPresent = false,
      String userId = 'test-user-id',
      TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
      TimeOfDay end = const TimeOfDay(hour: 11, minute: 0),
    }) =>
        [
          event(type: type, timeSlots: [
            timeSlot(
              time: start,
              endTime: end,
              attendees: [attendee(userId: userId, isPresent: isPresent)],
            ),
          ]),
        ];

    test('adds hours for a slot signed up but not yet attended', () {
      final summary = summarise(events: eventSignedUp());

      expect(summary.completedFor('Service'), 0);
      expect(summary.potentialFor('Service'), 2);
    });

    test('does not double count a slot already marked present', () {
      final summary = summarise(events: eventSignedUp(isPresent: true));
      expect(summary.potentialFor('Service'), 0);
    });

    test('ignores slots belonging to someone else', () {
      final summary = summarise(events: eventSignedUp(userId: 'someone-else'));
      expect(summary.potentialFor('Service'), 0);
    });

    test('an overnight slot contributes positive potential hours', () {
      final summary = summarise(
        events: eventSignedUp(
          start: const TimeOfDay(hour: 22, minute: 0),
          end: const TimeOfDay(hour: 2, minute: 0),
        ),
      );

      expect(summary.potentialFor('Service'), 4);
    });

    test('potential always includes completed', () {
      final summary = summarise(
        logged: [loggedRow(hours: 5)],
        events: eventSignedUp(),
      );

      expect(summary.completedFor('Service'), 5);
      expect(summary.potentialFor('Service'), 7);
      expect(summary.potentialFor('Service'),
          greaterThanOrEqualTo(summary.completedFor('Service')));
    });

    test('matches the event type case-insensitively', () {
      final summary = summarise(events: eventSignedUp(type: 'service'));
      expect(summary.potentialFor('Service'), 2);
    });
  });

  group('totals and requirement counting', () {
    test('totalCompleted sums every type', () {
      final summary = summarise(
        types: ['Service', 'Tutoring'],
        logged: [
          loggedRow(type: 'Service', hours: 4),
          loggedRow(type: 'Tutoring', hours: 3),
        ],
      );

      expect(summary.totalCompleted, 7);
    });

    test('counts a requirement once it is met', () {
      final summary = summarise(logged: [loggedRow(hours: 20)]);

      expect(
        summary.completedRequirementCount(
            hoursNeededByType: {'Service': 20}, meetingRequirement: 8),
        1,
      );
    });

    test('does not count a requirement just short', () {
      final summary = summarise(logged: [loggedRow(hours: 19.5)]);

      expect(
        summary.completedRequirementCount(
            hoursNeededByType: {'Service': 20}, meetingRequirement: 8),
        0,
      );
    });

    test('counts meetings separately from hour requirements', () {
      final summary = summarise(
        types: ['Service'],
        logged: [
          loggedRow(type: 'Service', hours: 20),
          loggedRow(type: 'Meeting', hours: 8),
        ],
      );

      expect(
        summary.completedRequirementCount(
            hoursNeededByType: {'Service': 20}, meetingRequirement: 8),
        2,
      );
    });

    test('a zero-hour requirement counts as met', () {
      final summary = summarise();

      expect(
        summary.completedRequirementCount(
            hoursNeededByType: {'Service': 0}, meetingRequirement: 0),
        2,
      );
    });
  });
}
