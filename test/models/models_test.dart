// Parsing coverage for the models without a file of their own.
//
// Several of these tests assert that a factory *throws* on a null column. That
// is not an endorsement -- it documents the current contract so a future change
// to defensive parsing is a deliberate, visible decision rather than a silent
// behaviour change.
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/models/activitylog.dart';
import 'package:nhs_tracker/models/attendee.dart';
import 'package:nhs_tracker/models/collection.dart';
import 'package:nhs_tracker/models/completeduserhour.dart';
import 'package:nhs_tracker/models/continuousevent.dart';
import 'package:nhs_tracker/models/continuouseventstep.dart';
import 'package:nhs_tracker/models/continuouseventsubmission.dart';
import 'package:nhs_tracker/models/honorsociety.dart';
import 'package:nhs_tracker/models/hourrequirement.dart';
import 'package:nhs_tracker/models/swaprequest.dart';

import '../helpers/fixtures.dart';

void main() {
  group('HourRequirement', () {
    test('maps snake_case columns', () {
      final parsed = HourRequirement.fromJson(hourRequirementRow(
        id: 5,
        type: 'Tutoring',
        hoursNeeded: 12,
        iconName: 'school',
      ));

      expect(parsed.id, 5);
      expect(parsed.type, 'Tutoring');
      expect(parsed.hoursNeeded, 12.0);
      expect(parsed.iconName, 'school');
    });

    test('widens an int hours_needed to double', () {
      expect(
          HourRequirement.fromJson(hourRequirementRow(hoursNeeded: 20))
              .hoursNeeded,
          isA<double>());
    });

    test('accepts a fractional hours_needed', () {
      expect(
        HourRequirement.fromJson(hourRequirementRow(hoursNeeded: 7.5))
            .hoursNeeded,
        7.5,
      );
    });

    test('defaults is_active and icon_name when absent', () {
      final row = hourRequirementRow();
      row.remove('is_active');
      row.remove('icon_name');

      final parsed = HourRequirement.fromJson(row);
      expect(parsed.isActive, isTrue);
      expect(parsed.iconName, 'workspaces');
    });

    test('throws when hours_needed is null', () {
      final row = hourRequirementRow()..['hours_needed'] = null;
      expect(() => HourRequirement.fromJson(row), throwsA(anything));
    });
  });

  group('HonorSociety', () {
    test('maps columns and nested requirements', () {
      final parsed = HonorSociety.fromJson(honorSocietyRow(
        id: 3,
        name: 'Beta Club',
        meetingRequirement: 6,
        hourRequirements: [
          hourRequirementRow(id: 1, type: 'Service'),
          hourRequirementRow(id: 2, type: 'Tutoring'),
        ],
      ));

      expect(parsed.id, 3);
      expect(parsed.name, 'Beta Club');
      expect(parsed.meetingRequirement, 6);
      expect(parsed.hourRequirements, hasLength(2));
      expect(parsed.hourRequirements.last.type, 'Tutoring');
    });

    test('keeps optional urls null', () {
      final parsed = HonorSociety.fromJson(honorSocietyRow());
      expect(parsed.imageUrl, isNull);
      expect(parsed.errorFormUrl, isNull);
    });

    test('throws when hour_requirements is null', () {
      final row = honorSocietyRow()..['hour_requirements'] = null;
      expect(() => HonorSociety.fromJson(row), throwsA(anything));
    });
  });

  group('Attendee', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'timeslot_id': 10,
          'user_id': 'u1',
          'name': 'Alex',
          'is_present': true,
          'forms_completed': true,
        };

    test('maps columns', () {
      final parsed = Attendee.fromJson(row());
      expect(parsed.id, 1);
      expect(parsed.timeSlotId, 10);
      expect(parsed.userId, 'u1');
      expect(parsed.isPresent, isTrue);
      expect(parsed.formsCompleted, isTrue);
    });

    test('falls back to "Unknown" for a missing name', () {
      final r = row()..remove('name');
      expect(Attendee.fromJson(r).name, 'Unknown');
    });

    test('defaults the flags to false', () {
      final r = row()
        ..remove('is_present')
        ..remove('forms_completed');
      final parsed = Attendee.fromJson(r);
      expect(parsed.isPresent, isFalse);
      expect(parsed.formsCompleted, isFalse);
    });

    test('round-trips through toJson', () {
      final parsed = Attendee.fromJson(Attendee.fromJson(row()).toJson());
      expect(parsed.id, 1);
      expect(parsed.name, 'Alex');
      expect(parsed.isPresent, isTrue);
    });

    test('copyWith overrides one field', () {
      final original = attendee(isPresent: false);
      expect(original.copyWith(isPresent: true).isPresent, isTrue);
      expect(original.copyWith(isPresent: true).name, original.name);
    });
  });

  group('CompletedUserHour', () {
    Map<String, dynamic> row() =>
        {'id': 1, 'event_name': 'Cleanup', 'hours': 4, 'type': 'Service'};

    test('widens an int hours to double', () {
      expect(CompletedUserHour.fromJson(row()).hours, 4.0);
    });

    test('accepts a double hours', () {
      final parsed = CompletedUserHour.fromJson(row()..['hours'] = 2.5);
      expect(parsed.hours, 2.5);
    });

    test('defaults an unusable hours value to zero rather than throwing', () {
      final parsed = CompletedUserHour.fromJson(row()..['hours'] = 'lots');
      expect(parsed.hours, 0.0);
    });

    test('falls back for missing name and type', () {
      final r = row()
        ..remove('event_name')
        ..remove('type');
      final parsed = CompletedUserHour.fromJson(r);
      expect(parsed.eventName, 'Unnamed Event');
      expect(parsed.type, 'Unknown Type');
    });

    // The field is declared `final int?` but the parser casts with `as int`,
    // so an absent id throws instead of yielding null.
    test('throws on a missing id despite the field being nullable', () {
      final r = row()..remove('id');
      expect(() => CompletedUserHour.fromJson(r), throwsA(anything));
    });
  });

  group('ActivityLog', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'event_name': 'Cleanup',
          'timeslot': '9:00 - 11:00',
          'hours': 2,
          'action_type': 'signup',
          'user_id': 'u1',
          'profiles': {'name': 'Alex'},
          'created_at': '2026-08-01T12:00:00.000Z',
        };

    test('reads the joined profile name', () {
      expect(ActivityLog.fromJson(row()).userName, 'Alex');
    });

    test('widens int hours', () {
      expect(ActivityLog.fromJson(row()).hours, 2.0);
    });

    test('keeps the optional swap columns null', () {
      final parsed = ActivityLog.fromJson(row());
      expect(parsed.oldUserId, isNull);
      expect(parsed.newUserName, isNull);
    });

    // The join is dereferenced unguarded, so a filtered-out or missing profile
    // row takes down the whole activity list.
    test('throws when the profiles join is missing', () {
      final r = row()..remove('profiles');
      expect(() => ActivityLog.fromJson(r), throwsA(anything));
    });
  });

  group('SwapRequest', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'requester_id': 'u1',
          'target_id': 'u2',
          'event_id': 3,
          'timeslot_id': 10,
          'status': 'pending',
          'Time slots': {
            'start_time': '2026-09-15T09:00:00.000Z',
            'end_time': '2026-09-15T11:00:00.000Z',
          },
        };

    // The field is currentAttendeeId but the column is target_id -- a name
    // mismatch that is easy to "correct" wrongly.
    test('populates currentAttendeeId from the target_id column', () {
      expect(SwapRequest.fromJson(row()).currentAttendeeId, 'u2');
    });

    test('reads times from the space-containing "Time slots" join', () {
      final parsed = SwapRequest.fromJson(row());
      expect(parsed.startTime.toUtc(), DateTime.utc(2026, 9, 15, 9));
      expect(parsed.endTime.toUtc(), DateTime.utc(2026, 9, 15, 11));
    });

    test('throws when the "Time slots" join is missing', () {
      final r = row()..remove('Time slots');
      expect(() => SwapRequest.fromJson(r), throwsA(anything));
    });
  });

  group('Collection', () {
    test('maps event ids', () {
      final parsed = Collection.fromJson({
        'id': 1,
        'name': 'Fall Events',
        'event_ids': ['1', '2'],
      });

      expect(parsed.name, 'Fall Events');
      expect(parsed.eventIds, ['1', '2']);
    });

    test('defaults to no event ids when the column is not a list', () {
      final parsed =
          Collection.fromJson({'id': 1, 'name': 'X', 'event_ids': null});
      expect(parsed.eventIds, isEmpty);
    });

    // The `is List<dynamic>` check passes for a list of ints, and the failure
    // surfaces inside List<String>.from instead.
    test('throws for a list of non-strings', () {
      expect(
        () => Collection.fromJson({
          'id': 1,
          'name': 'X',
          'event_ids': [1, 2]
        }),
        throwsA(anything),
      );
    });
  });

  group('ContinuousEventStep', () {
    test('treats a blank link as absent', () {
      expect(
        ContinuousEventStep.fromJson(
            {'order': 1, 'description': 'Step', 'link': '   '}).link,
        isNull,
      );
    });

    test('keeps a real link', () {
      expect(
        ContinuousEventStep.fromJson(
            {'order': 1, 'description': 'Step', 'link': 'https://x.com'}).link,
        'https://x.com',
      );
    });

    test('defaults order and description', () {
      final parsed = ContinuousEventStep.fromJson(const {});
      expect(parsed.order, 0);
      expect(parsed.description, '');
    });

    test('omits an absent link from toJson', () {
      final json = ContinuousEventStep(order: 1, description: 'Step').toJson();
      expect(json.containsKey('link'), isFalse);
    });

    test('round-trips a step with a link', () {
      final original = ContinuousEventStep(
          order: 2, description: 'Do it', link: 'https://x');
      final restored = ContinuousEventStep.fromJson(original.toJson());

      expect(restored.order, 2);
      expect(restored.description, 'Do it');
      expect(restored.link, 'https://x');
    });

    // Regression: `link ?? this.link` could never remove a link.
    test('copyWith can clear the link', () {
      final original =
          ContinuousEventStep(order: 1, description: 'S', link: 'https://x');
      expect(original.copyWith(link: () => null).link, isNull);
    });

    test('copyWith can set the link and leaves other fields alone', () {
      final original = ContinuousEventStep(order: 1, description: 'S');
      final copy = original.copyWith(link: () => 'https://y');

      expect(copy.link, 'https://y');
      expect(copy.order, 1);
      expect(copy.description, 'S');
    });
  });

  group('ContinuousEvent', () {
    Map<String, dynamic> row(List<Map<String, dynamic>> steps) => {
          'id': 1,
          'society_id': 2,
          'name': 'Weekly Tutoring',
          'description': 'Tutor weekly',
          'type': 'Tutoring',
          'steps': steps,
          'created_at': '2026-08-01T12:00:00.000Z',
          'updated_at': '2026-08-02T12:00:00.000Z',
        };

    test('sorts steps by order regardless of row order', () {
      final parsed = ContinuousEvent.fromJson(row([
        {'order': 3, 'description': 'third'},
        {'order': 1, 'description': 'first'},
        {'order': 2, 'description': 'second'},
      ]));

      expect(parsed.steps.map((s) => s.description).toList(),
          ['first', 'second', 'third']);
    });

    test('keeps duplicate orders in their original relative order', () {
      final parsed = ContinuousEvent.fromJson(row([
        {'order': 1, 'description': 'a'},
        {'order': 1, 'description': 'b'},
      ]));

      expect(parsed.steps.map((s) => s.description).toList(), ['a', 'b']);
    });

    test('handles an event with no steps', () {
      expect(ContinuousEvent.fromJson(row(const [])).steps, isEmpty);
    });

    test('defaults the optional text columns', () {
      final r = row(const [])
        ..remove('name')
        ..remove('description')
        ..remove('type');

      final parsed = ContinuousEvent.fromJson(r);
      expect(parsed.name, '');
      expect(parsed.description, '');
      expect(parsed.iconName, 'workspaces');
      expect(parsed.allowMultipleSubmissions, isTrue);
      expect(parsed.isActive, isTrue);
    });

    // Both timestamps are parsed unguarded, unlike the text columns above.
    test('throws when updated_at is missing', () {
      final r = row(const [])..remove('updated_at');
      expect(() => ContinuousEvent.fromJson(r), throwsA(anything));
    });
  });

  group('ContinuousEventSubmission', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'continuous_event_id': 2,
          'society_id': 3,
          'user_id': 'u1',
          'hours': 2,
          'activity_date': '2026-08-01T00:00:00.000Z',
          'proof_link': 'https://x.com',
          'status': 'pending',
          'created_at': '2026-08-01T12:00:00.000Z',
        };

    test('maps columns and widens hours', () {
      final parsed = ContinuousEventSubmission.fromJson(row());
      expect(parsed.id, 1);
      expect(parsed.hours, 2.0);
      expect(parsed.proofLink, 'https://x.com');
    });

    test('status getters agree with the status string', () {
      ContinuousEventSubmission at(String status) =>
          ContinuousEventSubmission.fromJson(row()..['status'] = status);

      expect(at('pending').isPending, isTrue);
      expect(at('approved').isApproved, isTrue);
      expect(at('rejected').isRejected, isTrue);
      expect(at('approved').isPending, isFalse);
    });

    test('an unknown status matches none of the getters', () {
      final parsed =
          ContinuousEventSubmission.fromJson(row()..['status'] = 'withdrawn');
      expect(parsed.isPending, isFalse);
      expect(parsed.isApproved, isFalse);
      expect(parsed.isRejected, isFalse);
    });

    test('defaults a missing status to pending', () {
      final r = row()..remove('status');
      expect(ContinuousEventSubmission.fromJson(r).isPending, isTrue);
    });

    // Unlike ActivityLog, this parser guards its joins.
    test('survives missing profile and event joins', () {
      final parsed = ContinuousEventSubmission.fromJson(row());
      expect(parsed.userName, isNull);
      expect(parsed.continuousEventName, isNull);
    });

    test('reads the joined names when present', () {
      final r = row()
        ..['profiles'] = {'name': 'Alex'}
        ..['continuous_events'] = {'name': 'Weekly Tutoring'};

      final parsed = ContinuousEventSubmission.fromJson(r);
      expect(parsed.userName, 'Alex');
      expect(parsed.continuousEventName, 'Weekly Tutoring');
    });

    test('ignores a join whose name is not a string', () {
      final r = row()..['profiles'] = {'name': 42};
      expect(ContinuousEventSubmission.fromJson(r).userName, isNull);
    });

    test('keeps review columns null while pending', () {
      final parsed = ContinuousEventSubmission.fromJson(row());
      expect(parsed.reviewedAt, isNull);
      expect(parsed.reviewerId, isNull);
      expect(parsed.serviceHoursId, isNull);
    });
  });
}
