import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/models/event.dart';

import '../helpers/fixtures.dart';

void main() {
  group('fromJson', () {
    test('maps the ordinary columns', () {
      final parsed = Event.fromJson(eventRow(
        id: 7,
        name: 'Beach Cleanup',
        description: 'Bags provided',
        type: 'Service',
        location: 'Pier 3',
      ));

      expect(parsed.id, 7);
      expect(parsed.name, 'Beach Cleanup');
      expect(parsed.description, 'Bags provided');
      expect(parsed.type, 'Service');
      expect(parsed.location, 'Pier 3');
    });

    test('parses dates', () {
      final parsed = Event.fromJson(eventRow(date: '2026-09-15T00:00:00.000Z'));
      expect(parsed.date.toUtc(), DateTime.utc(2026, 9, 15));
    });

    // The row deliberately mixes conventions: `isMandatory` and `timeSlots` are
    // camelCase while everything around them is snake_case. Pinned so a
    // well-meaning rename does not silently break parsing.
    test('reads the camelCase isMandatory key, not is_mandatory', () {
      expect(Event.fromJson(eventRow(isMandatory: true)).isMandatory, isTrue);

      final snake = eventRow()..['is_mandatory'] = true;
      snake.remove('isMandatory');
      expect(Event.fromJson(snake).isMandatory, isFalse);
    });

    test('reads nested time slots from the camelCase timeSlots key', () {
      final parsed = Event.fromJson(eventRow(timeSlots: [
        timeSlotRow(id: 1),
        timeSlotRow(id: 2),
      ]));

      expect(parsed.timeSlots, hasLength(2));
      expect(parsed.timeSlots.first.id, 1);
    });

    test('defaults to no time slots when the key is absent', () {
      expect(Event.fromJson(eventRow()).timeSlots, isEmpty);
    });

    test('defaults the booleans when absent', () {
      final row = eventRow();
      row.remove('requires_forms');
      row.remove('has_delay');
      row.remove('isMandatory');

      final parsed = Event.fromJson(row);
      expect(parsed.requiresForms, isFalse);
      expect(parsed.hasDelay, isFalse);
      expect(parsed.isMandatory, isFalse);
    });

    test('defaults the swap deadline to 24 hours', () {
      expect(Event.fromJson(eventRow()).swapRequestDeadline,
          const Duration(hours: 24));
    });

    test('honours an explicit swap deadline', () {
      expect(
        Event.fromJson(eventRow(swapRequestDeadlineHours: 48))
            .swapRequestDeadline,
        const Duration(hours: 48),
      );
    });

    test('keeps nullable columns null', () {
      final parsed = Event.fromJson(eventRow());
      expect(parsed.collectionId, isNull);
      expect(parsed.formLink, isNull);
      expect(parsed.location, isNull);
    });

    // Documents a sharp edge: these columns are read unguarded, so a null from
    // the database throws rather than degrading.
    test('throws when a required column is null', () {
      final row = eventRow()..['date'] = null;
      expect(() => Event.fromJson(row), throwsA(anything));
    });
  });

  group('canSignUpForTimeSlot', () {
    final slot = timeSlot(time: const TimeOfDay(hour: 9, minute: 0));

    test('is always allowed when the event has no delay', () {
      final e = event(date: DateTime(2030, 1, 1), hasDelay: false);
      withClock(Clock.fixed(DateTime(2026, 1, 1)), () {
        expect(e.canSignUpForTimeSlot(slot), isTrue);
      });
    });

    test('is closed before the delay window opens', () {
      final e =
          event(date: DateTime(2026, 9, 15), hasDelay: true, delayHours: 48);
      // Window opens 2026-09-13 09:00; this is a day earlier.
      withClock(Clock.fixed(DateTime(2026, 9, 12, 9)), () {
        expect(e.canSignUpForTimeSlot(slot), isFalse);
      });
    });

    test('is open once the window has started', () {
      final e =
          event(date: DateTime(2026, 9, 15), hasDelay: true, delayHours: 48);
      withClock(Clock.fixed(DateTime(2026, 9, 14)), () {
        expect(e.canSignUpForTimeSlot(slot), isTrue);
      });
    });

    // The comparison is a strict isAfter, so the exact opening instant is
    // still closed. Pinned because it is easy to flip accidentally.
    test('is still closed at the exact opening instant', () {
      final e =
          event(date: DateTime(2026, 9, 15), hasDelay: true, delayHours: 48);
      withClock(Clock.fixed(DateTime(2026, 9, 13, 9)), () {
        expect(e.canSignUpForTimeSlot(slot), isFalse);
      });
    });

    test('opens one minute later', () {
      final e =
          event(date: DateTime(2026, 9, 15), hasDelay: true, delayHours: 48);
      withClock(Clock.fixed(DateTime(2026, 9, 13, 9, 1)), () {
        expect(e.canSignUpForTimeSlot(slot), isTrue);
      });
    });

    test('uses the slot time, not midnight', () {
      final e =
          event(date: DateTime(2026, 9, 15), hasDelay: true, delayHours: 1);
      final lateSlot = timeSlot(time: const TimeOfDay(hour: 18, minute: 0));

      withClock(Clock.fixed(DateTime(2026, 9, 15, 16)), () {
        expect(e.canSignUpForTimeSlot(lateSlot), isFalse);
      });
      withClock(Clock.fixed(DateTime(2026, 9, 15, 17, 30)), () {
        expect(e.canSignUpForTimeSlot(lateSlot), isTrue);
      });
    });
  });

  group('toJson', () {
    test('round-trips through fromJson', () {
      final original = event(
        id: 3,
        name: 'Tutoring',
        type: 'Tutoring',
        isMandatory: true,
        requiresForms: true,
        hasDelay: true,
        delayHours: 12,
        location: 'Library',
        collectionId: 9,
        formLink: 'https://example.com/form',
      );

      final restored = Event.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.isMandatory, original.isMandatory);
      expect(restored.requiresForms, original.requiresForms);
      expect(restored.hasDelay, original.hasDelay);
      expect(restored.delayHours, original.delayHours);
      expect(restored.location, original.location);
      expect(restored.collectionId, original.collectionId);
      expect(restored.formLink, original.formLink);
      expect(restored.swapRequestDeadline, original.swapRequestDeadline);
    });

    test('writes the swap deadline in hours', () {
      final json = event(swapRequestDeadline: const Duration(days: 2)).toJson();
      expect(json['swap_request_deadline_hours'], 48);
    });

    test('round-trips nested time slots', () {
      final original = event(timeSlots: [
        timeSlot(time: const TimeOfDay(hour: 9, minute: 5)),
      ]);
      final restored = Event.fromJson(original.toJson());

      expect(restored.timeSlots, hasLength(1));
      expect(
          restored.timeSlots.first.time, const TimeOfDay(hour: 9, minute: 5));
    });
  });

  group('copyWith', () {
    test('changes only the named field', () {
      final original = event(name: 'Original', type: 'Service');
      final copy = original.copyWith(name: 'Renamed');

      expect(copy.name, 'Renamed');
      expect(copy.type, 'Service');
      expect(copy.id, original.id);
    });

    test('returns an equivalent event when given nothing', () {
      final original = event(location: 'Pier 3', collectionId: 4);
      final copy = original.copyWith();

      expect(copy.location, 'Pier 3');
      expect(copy.collectionId, 4);
      expect(copy.name, original.name);
    });

    // Regression: `x ?? this.x` meant an event could never be moved out of a
    // collection, nor have its location or form link removed.
    test('can clear location', () {
      final original = event(location: 'Pier 3');
      expect(original.copyWith(location: () => null).location, isNull);
    });

    test('can clear collectionId', () {
      final original = event(collectionId: 4);
      expect(original.copyWith(collectionId: () => null).collectionId, isNull);
    });

    test('can clear formLink', () {
      final original = event(formLink: 'https://example.com');
      expect(original.copyWith(formLink: () => null).formLink, isNull);
    });

    test('can still set the nullable fields', () {
      final copy = event().copyWith(
        location: () => 'Gym',
        collectionId: () => 12,
        formLink: () => 'https://example.com/f',
      );

      expect(copy.location, 'Gym');
      expect(copy.collectionId, 12);
      expect(copy.formLink, 'https://example.com/f');
    });

    test('copies the time slot list rather than sharing it', () {
      final original = event(timeSlots: [timeSlot()]);
      final copy = original.copyWith();

      copy.timeSlots.add(timeSlot(id: 11));

      expect(original.timeSlots, hasLength(1));
      expect(copy.timeSlots, hasLength(2));
    });
  });
}
