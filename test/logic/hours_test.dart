import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/nhsformatutils.dart';
import 'package:nhs_tracker/logic/hours.dart';

import '../helpers/fixtures.dart';

void main() {
  group('durationInHours', () {
    test('measures a normal daytime slot', () {
      expect(
        durationInHours(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 11, minute: 30),
        ),
        2.5,
      );
    });

    test('handles sub-hour slots', () {
      expect(
        durationInHours(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 9, minute: 15),
        ),
        0.25,
      );
    });

    test('an equal start and end is a zero-length slot, not 24 hours', () {
      expect(
        durationInHours(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 9, minute: 0),
        ),
        0.0,
      );
    });

    // Regression: this returned -20.0, and the attendance page writes the
    // result straight into `Service hours`, so an overnight event credited
    // members negative service hours.
    test('rolls past midnight instead of going negative', () {
      expect(
        durationInHours(
          const TimeOfDay(hour: 22, minute: 0),
          const TimeOfDay(hour: 2, minute: 0),
        ),
        4.0,
      );
    });

    test('never returns a negative for any pair of times', () {
      for (var startH = 0; startH < 24; startH += 3) {
        for (var endH = 0; endH < 24; endH += 3) {
          final hours = durationInHours(
            TimeOfDay(hour: startH, minute: 0),
            TimeOfDay(hour: endH, minute: 0),
          );
          expect(hours, greaterThanOrEqualTo(0),
              reason: '$startH:00 -> $endH:00');
          expect(hours, lessThan(24));
        }
      }
    });

    test('NhsFormatUtils.calculateDuration delegates to the same logic', () {
      const start = TimeOfDay(hour: 22, minute: 0);
      const end = TimeOfDay(hour: 2, minute: 0);
      expect(
        NhsFormatUtils.calculateDuration(start, end),
        durationInHours(start, end),
      );
    });
  });

  group('timeSlotHours', () {
    test('measures a slot object', () {
      expect(
        timeSlotHours(timeSlot(
          time: const TimeOfDay(hour: 13, minute: 0),
          endTime: const TimeOfDay(hour: 16, minute: 45),
        )),
        3.75,
      );
    });
  });

  group('progressFraction', () {
    test('reports partial progress', () {
      expect(progressFraction(5, 20), 0.25);
    });

    test('clamps above 1 when the member overshoots', () {
      expect(progressFraction(40, 20), 1.0);
    });

    test('clamps below 0', () {
      expect(progressFraction(-5, 20), 0.0);
    });

    // A zero-hour requirement is vacuously satisfied. The old call sites
    // divided unguarded and leaned on clamp's NaN handling to land here by
    // accident; this pins it as intended behaviour.
    test('treats a zero requirement as complete, and never yields NaN', () {
      final fraction = progressFraction(0, 0);
      expect(fraction.isNaN, isFalse);
      expect(fraction, 1.0);
    });

    test('a zero requirement with hours logged is also complete', () {
      expect(progressFraction(10, 0), 1.0);
    });

    test('a negative requirement is treated as zero', () {
      expect(progressFraction(0, -5), 1.0);
    });
  });

  group('progressPercent', () {
    test('rounds to a whole percentage', () {
      expect(progressPercent(1, 3), 33);
      expect(progressPercent(2, 3), 67);
    });

    test('is 100 for a zero requirement rather than throwing', () {
      expect(progressPercent(0, 0), 100);
    });
  });

  group('meetsRequirement', () {
    test('is met exactly at the boundary', () {
      expect(meetsRequirement(20, 20), isTrue);
    });

    test('is not met just below', () {
      expect(meetsRequirement(19.9, 20), isFalse);
    });

    test('a zero requirement is always met', () {
      expect(meetsRequirement(0, 0), isTrue);
    });
  });
}
