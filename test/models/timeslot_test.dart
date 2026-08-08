import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/models/timeslot.dart';

import '../helpers/fixtures.dart';

void main() {
  group('fromJson', () {
    test('reads times out of ISO-8601 timestamps', () {
      final slot = TimeSlot.fromJson(timeSlotRow(
        startTime: '2026-09-15T09:05:00.000Z',
        endTime: '2026-09-15T11:30:00.000Z',
      ));

      expect(slot.time, const TimeOfDay(hour: 9, minute: 5));
      expect(slot.endTime, const TimeOfDay(hour: 11, minute: 30));
    });

    test('maps the remaining snake_case columns', () {
      final slot = TimeSlot.fromJson(timeSlotRow(
        id: 77,
        numberOfPeople: 12,
        notes: 'Bring gloves',
        eventId: 5,
      ));

      expect(slot.id, 77);
      expect(slot.numberOfPeople, 12);
      expect(slot.notes, 'Bring gloves');
      expect(slot.eventId, 5);
    });

    test('defaults missing scalars rather than throwing', () {
      final slot = TimeSlot.fromJson({
        'start_time': '2026-09-15T09:00:00.000Z',
        'end_time': '2026-09-15T10:00:00.000Z',
      });

      expect(slot.id, isNull);
      expect(slot.numberOfPeople, 0);
      expect(slot.notes, '');
      expect(slot.eventId, 0);
    });

    test('falls back to the current time when created_at is absent', () {
      final fixed = DateTime(2026, 8, 3, 12);
      withClock(Clock.fixed(fixed), () {
        final slot = TimeSlot.fromJson({
          'start_time': '2026-09-15T09:00:00.000Z',
          'end_time': '2026-09-15T10:00:00.000Z',
        });
        expect(slot.createdAt, fixed);
      });
    });

    test('always starts with an empty attendee list', () {
      final slot = TimeSlot.fromJson(timeSlotRow());
      expect(slot.attendees, isEmpty);
    });
  });

  group('parseTimeOfDay', () {
    test('accepts an ISO timestamp', () {
      expect(TimeSlot.parseTimeOfDay('2026-09-15T14:30:00.000Z'),
          const TimeOfDay(hour: 14, minute: 30));
    });

    // A Postgres `time` column serialises like this, and DateTime.parse
    // rejects it outright -- previously a FormatException at parse time.
    test('accepts a bare time string from a `time` column', () {
      expect(TimeSlot.parseTimeOfDay('14:30:00'),
          const TimeOfDay(hour: 14, minute: 30));
      expect(TimeSlot.parseTimeOfDay('09:05'),
          const TimeOfDay(hour: 9, minute: 5));
    });

    test('falls back to midnight for null, empty and nonsense', () {
      const midnight = TimeOfDay(hour: 0, minute: 0);
      expect(TimeSlot.parseTimeOfDay(null), midnight);
      expect(TimeSlot.parseTimeOfDay(''), midnight);
      expect(TimeSlot.parseTimeOfDay('not a time'), midnight);
      expect(TimeSlot.parseTimeOfDay(42), midnight);
    });

    test('rejects out-of-range components', () {
      expect(TimeSlot.parseTimeOfDay('99:99'),
          const TimeOfDay(hour: 0, minute: 0));
    });

    test('honours an explicit fallback', () {
      const fallback = TimeOfDay(hour: 8, minute: 15);
      expect(TimeSlot.parseTimeOfDay(null, fallback: fallback), fallback);
    });
  });

  group('toJson', () {
    // Regression: toJson wrote '${time.hour}:${time.minute}', so 09:05 became
    // "9:5" -- unpadded, and rejected by fromJson's own parser.
    test('round-trips through fromJson', () {
      final original = timeSlot(
        time: const TimeOfDay(hour: 9, minute: 5),
        endTime: const TimeOfDay(hour: 11, minute: 30),
        numberOfPeople: 4,
        notes: 'Meet at the gate',
        eventId: 3,
      );

      final restored = TimeSlot.fromJson(original.toJson());

      expect(restored.time, original.time);
      expect(restored.endTime, original.endTime);
      expect(restored.numberOfPeople, original.numberOfPeople);
      expect(restored.notes, original.notes);
      expect(restored.eventId, original.eventId);
      expect(restored.id, original.id);
    });

    test('round-trips single-digit times specifically', () {
      final original = timeSlot(
        time: const TimeOfDay(hour: 1, minute: 2),
        endTime: const TimeOfDay(hour: 3, minute: 4),
      );
      final restored = TimeSlot.fromJson(original.toJson());

      expect(restored.time, const TimeOfDay(hour: 1, minute: 2));
      expect(restored.endTime, const TimeOfDay(hour: 3, minute: 4));
    });

    test('emits a parseable timestamp, not a bare "h:m"', () {
      final json = timeSlot(time: const TimeOfDay(hour: 9, minute: 5)).toJson();
      expect(DateTime.tryParse(json['start_time'] as String), isNotNull);
    });

    test('serialises attendees', () {
      final json = timeSlot(attendees: [attendee(name: 'Alex')]).toJson();
      final attendees = json['attendees'] as List;
      expect(attendees, hasLength(1));
      expect((attendees.first as Map)['name'], 'Alex');
    });
  });

  group('copyWith', () {
    test('changes only the named field', () {
      final original = timeSlot(notes: 'original', numberOfPeople: 5);
      final copy = original.copyWith(notes: 'updated');

      expect(copy.notes, 'updated');
      expect(copy.numberOfPeople, 5);
      expect(copy.time, original.time);
    });

    test('returns an equivalent slot when given nothing', () {
      final original = timeSlot();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.time, original.time);
      expect(copy.notes, original.notes);
    });

    // Regression: `id ?? this.id` could never clear a nullable field.
    test('can clear the nullable id', () {
      final original = timeSlot(id: 10);
      expect(original.copyWith(id: () => null).id, isNull);
    });

    test('can set the id to a new value', () {
      expect(timeSlot(id: 10).copyWith(id: () => 99).id, 99);
    });

    test('copies the attendee list rather than sharing it', () {
      final original = timeSlot(attendees: [attendee()]);
      final copy = original.copyWith();

      copy.attendees.add(attendee(id: 501));

      expect(original.attendees, hasLength(1));
      expect(copy.attendees, hasLength(2));
    });
  });
}
