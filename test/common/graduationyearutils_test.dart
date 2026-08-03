import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/graduationyearutils.dart';

void main() {
  // Pinning the clock makes the rolling window concrete: anchored on 2026 the
  // accepted range is 1970..2050.
  T inYear<T>(int year, T Function() body) =>
      withClock(Clock.fixed(DateTime(year, 6, 1)), body);

  group('window', () {
    test('spans 56 years back and 24 forward', () {
      inYear(2026, () {
        expect(GraduationYearUtils.minYear, 1970);
        expect(GraduationYearUtils.maxYear, 2050);
      });
    });

    test('rolls forward with the year, needing no manual bump', () {
      inYear(2030, () {
        expect(GraduationYearUtils.minYear, 1974);
        expect(GraduationYearUtils.maxYear, 2054);
      });
    });
  });

  group('validate', () {
    test('accepts a year inside the window', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('2027'), isNull);
      });
    });

    test('accepts both boundaries', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('1970'), isNull);
        expect(GraduationYearUtils.validate('2050'), isNull);
      });
    });

    test('trims surrounding whitespace', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('  2027  '), isNull);
      });
    });

    test('rejects null, empty and whitespace with the same message', () {
      inYear(2026, () {
        const expected = 'Please enter your graduation year';
        expect(GraduationYearUtils.validate(null), expected);
        expect(GraduationYearUtils.validate(''), expected);
        expect(GraduationYearUtils.validate('   '), expected);
      });
    });

    test('rejects non-numeric input', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('abcd'), 'Enter a 4-digit year');
      });
    });

    test('rejects the wrong number of digits', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('202'), 'Enter a 4-digit year');
        expect(GraduationYearUtils.validate('02026'), 'Enter a 4-digit year');
      });
    });

    // "+026" parses as 26 and is 4 characters long, so it clears the length
    // gate and is caught by the range check instead. Pinned so a future
    // refactor of the two checks does not silently start accepting it.
    test('a signed 4-character value is caught by the range check', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('+026'),
            'Enter a year between 1970 and 2050');
      });
    });

    test('rejects a year below the window', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('1969'),
            'Enter a year between 1970 and 2050');
      });
    });

    test('rejects a year above the window', () {
      inYear(2026, () {
        expect(GraduationYearUtils.validate('2051'),
            'Enter a year between 1970 and 2050');
      });
    });

    test('the range message tracks the current year', () {
      inYear(2030, () {
        expect(GraduationYearUtils.validate('1900'),
            'Enter a year between 1974 and 2054');
      });
    });

    test('a year valid today can fall out of the window later', () {
      inYear(2026, () => expect(GraduationYearUtils.validate('1970'), isNull));
      inYear(2027, () {
        expect(GraduationYearUtils.validate('1970'),
            'Enter a year between 1971 and 2051');
      });
    });
  });
}
