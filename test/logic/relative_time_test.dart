import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/relative_time.dart';

void main() {
  final now = DateTime(2026, 8, 3, 12, 0);
  DateTime ago(Duration d) => now.subtract(d);

  group('timeAgo (verbose)', () {
    String at(Duration d) => timeAgo(ago(d), now: now);

    test('just now', () {
      expect(at(Duration.zero), 'Just now');
      expect(at(const Duration(seconds: 45)), 'Just now');
    });

    test('minutes, singular and plural', () {
      expect(at(const Duration(minutes: 1)), '1 minute ago');
      expect(at(const Duration(minutes: 42)), '42 minutes ago');
    });

    test('hours, singular and plural', () {
      expect(at(const Duration(hours: 1)), '1 hour ago');
      expect(at(const Duration(hours: 5)), '5 hours ago');
    });

    test('days, singular and plural', () {
      expect(at(const Duration(days: 1)), '1 day ago');
      expect(at(const Duration(days: 3)), '3 days ago');
    });

    // The boundaries are strict `>`, so 7 days is still counted in days and
    // the first "1 week ago" only appears at 8 days. Pinned deliberately --
    // it looks like an off-by-one but it is the shipped behaviour.
    test('exactly 7 days still reads in days', () {
      expect(at(const Duration(days: 7)), '7 days ago');
    });

    test('8 days is the first week', () {
      expect(at(const Duration(days: 8)), '1 week ago');
    });

    test('weeks plural', () {
      expect(at(const Duration(days: 21)), '3 weeks ago');
    });

    test('exactly 30 days is still weeks', () {
      expect(at(const Duration(days: 30)), '4 weeks ago');
    });

    test('past 30 days falls back to an absolute date', () {
      expect(at(const Duration(days: 40)), 'Jun 24, 2026');
    });

    test('a future timestamp reads as just now', () {
      expect(timeAgo(now.add(const Duration(days: 2)), now: now), 'Just now');
    });

    test('uses the ambient clock when now is omitted', () {
      withClock(Clock.fixed(now), () {
        expect(timeAgo(ago(const Duration(hours: 2))), '2 hours ago');
      });
    });
  });

  group('timeAgoShort (compact)', () {
    String at(Duration d) => timeAgoShort(ago(d), now: now);

    test('just now', () {
      expect(at(Duration.zero), 'Just now');
    });

    test('compact minutes, hours and days', () {
      expect(at(const Duration(minutes: 5)), '5m ago');
      expect(at(const Duration(hours: 5)), '5h ago');
      expect(at(const Duration(days: 5)), '5d ago');
    });

    test('does not pluralise', () {
      expect(at(const Duration(days: 1)), '1d ago');
    });

    // Shorter fallback window than timeAgo: 7 days, and no year in the format.
    test('past 7 days falls back to a short absolute date', () {
      expect(at(const Duration(days: 10)), 'Jul 24');
    });

    test('exactly 7 days still reads in days', () {
      expect(at(const Duration(days: 7)), '7d ago');
    });

    test('uses the ambient clock when now is omitted', () {
      withClock(Clock.fixed(now), () {
        expect(timeAgoShort(ago(const Duration(minutes: 3))), '3m ago');
      });
    });
  });

  test('the two styles genuinely differ, which is why both exist', () {
    final threeWeeks = ago(const Duration(days: 21));
    expect(timeAgo(threeWeeks, now: now), '3 weeks ago');
    expect(timeAgoShort(threeWeeks, now: now), 'Jul 13');
  });
}
