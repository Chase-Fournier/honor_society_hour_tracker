import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/user_filtering.dart';
import 'package:nhs_tracker/models/userprofile.dart';

import '../helpers/fixtures.dart';

List<String> _names(List<UserProfile> users) =>
    users.map((u) => u.name).toList();

void main() {
  final alex = userProfile(
    id: 'a',
    name: 'Alex Rivera',
    graduationYear: '2027',
    hoursByType: const {'Service': 12, 'Tutoring': 3},
  );
  final blair = userProfile(
    id: 'b',
    name: 'Blair Chen',
    graduationYear: '2026',
    hasPaidDues: true,
    hoursByType: const {'Service': 40, 'Meeting': 6},
  );
  final casey = userProfile(
    id: 'c',
    name: 'casey Ford',
    graduationYear: '2028',
    hoursByType: const {'Service': 2},
  );
  final roster = [alex, blair, casey];

  group('totalHoursFor / hoursByTypeFor', () {
    test('totals every type', () {
      expect(totalHoursFor(alex), 15);
    });

    test('is zero for a member with no hours', () {
      expect(totalHoursFor(userProfile()), 0);
    });

    test('sums only the requested type', () {
      expect(hoursByTypeFor(alex, 'Service'), 12);
      expect(hoursByTypeFor(alex, 'Meeting'), 0);
    });

    test('matches type case- and spacing-insensitively', () {
      final user = userProfile(hoursByType: const {'community service': 5});
      expect(hoursByTypeFor(user, 'Community Service'), 5);
      expect(hoursByTypeFor(user, 'COMMUNITY SERVICE'), 5);
    });
  });

  group('search', () {
    test('matches a name substring, ignoring case', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(searchQuery: 'ri'),
      );
      expect(_names(result), ['Alex Rivera']);
    });

    test('an empty query keeps everyone', () {
      expect(filterAndSortUsers(roster), hasLength(3));
    });

    test('a non-matching query returns empty', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(searchQuery: 'zzz'),
      );
      expect(result, isEmpty);
    });
  });

  group('hour type filter', () {
    test('keeps only members with hours of that type', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(hourType: 'Meeting'),
      );
      expect(_names(result), ['Blair Chen']);
    });

    test("'All' does not filter", () {
      expect(
        filterAndSortUsers(roster, filter: const UserFilter(hourType: 'All')),
        hasLength(3),
      );
    });
  });

  group('advanced total-hours filter', () {
    List<UserProfile> run(HourTypeFilter totals) => filterAndSortUsers(
          roster,
          filter: UserFilter(useAdvancedFiltering: true, totalHours: totals),
        );

    test('atLeast keeps members at or above the minimum', () {
      expect(
        _names(run(
            const HourTypeFilter(condition: RangeCondition.atLeast, min: 15))),
        ['Alex Rivera', 'Blair Chen'],
      );
    });

    test('atLeast with a zero minimum stays inert', () {
      expect(run(const HourTypeFilter(condition: RangeCondition.atLeast)),
          hasLength(3));
    });

    // Regression: the max was previously compared against itself, so this
    // filter silently kept everybody.
    test('atMost actually excludes members above the maximum', () {
      expect(
        _names(run(
            const HourTypeFilter(condition: RangeCondition.atMost, max: 20))),
        ['Alex Rivera', 'casey Ford'],
      );
    });

    test('atMost at the old default of 50 is no longer ignored', () {
      final busy = userProfile(id: 'd', name: 'Dana', hoursByType: const {
        'Service': 80,
      });
      final result = filterAndSortUsers(
        [alex, busy],
        filter: const UserFilter(
          useAdvancedFiltering: true,
          totalHours: HourTypeFilter(condition: RangeCondition.atMost, max: 50),
        ),
      );
      expect(_names(result), ['Alex Rivera']);
    });

    test('between applies both ends', () {
      expect(
        _names(run(const HourTypeFilter(
            condition: RangeCondition.between, min: 10, max: 20))),
        ['Alex Rivera'],
      );
    });
  });

  group('advanced per-type filter', () {
    // Regression: the per-type atMost/between branches were dead code.
    test('atMost on a specific type excludes members above it', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(
          useAdvancedFiltering: true,
          hoursByType: {
            'Service':
                HourTypeFilter(condition: RangeCondition.atMost, max: 12),
          },
        ),
      );
      expect(_names(result), ['Alex Rivera', 'casey Ford']);
    });

    test('between on a specific type applies both ends', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(
          useAdvancedFiltering: true,
          hoursByType: {
            'Service': HourTypeFilter(
                condition: RangeCondition.between, min: 5, max: 20),
          },
        ),
      );
      expect(_names(result), ['Alex Rivera']);
    });

    test('several type filters must all pass', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(
          useAdvancedFiltering: true,
          hoursByType: {
            'Service':
                HourTypeFilter(condition: RangeCondition.atLeast, min: 10),
            'Tutoring':
                HourTypeFilter(condition: RangeCondition.atLeast, min: 1),
          },
        ),
      );
      expect(_names(result), ['Alex Rivera']);
    });
  });

  group('graduation year filter', () {
    List<UserProfile> run(String year, GraduationYearCondition condition) =>
        filterAndSortUsers(
          roster,
          filter: UserFilter(
            useAdvancedFiltering: true,
            graduationYear: year,
            graduationYearCondition: condition,
          ),
        );

    test('equals', () {
      expect(
          _names(run('2026', GraduationYearCondition.equals)), ['Blair Chen']);
    });

    test('before', () {
      expect(
          _names(run('2027', GraduationYearCondition.before)), ['Blair Chen']);
    });

    test('after', () {
      expect(
          _names(run('2027', GraduationYearCondition.after)), ['casey Ford']);
    });

    test('an empty year does not filter', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(
          useAdvancedFiltering: true,
          graduationYearCondition: GraduationYearCondition.before,
        ),
      );
      expect(result, hasLength(3));
    });
  });

  group('dues filter', () {
    test('shows only paid members', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(
          useAdvancedFiltering: true,
          filterByDues: true,
        ),
      );
      expect(_names(result), ['Blair Chen']);
    });

    test('shows only unpaid members', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(
          useAdvancedFiltering: true,
          filterByDues: true,
          showPaidDues: false,
        ),
      );
      expect(_names(result), ['Alex Rivera', 'casey Ford']);
    });
  });

  group('sorting', () {
    test('by name ascending', () {
      expect(_names(filterAndSortUsers(roster, sortField: SortField.name)),
          ['Alex Rivera', 'Blair Chen', 'casey Ford']);
    });

    test('by name descending', () {
      expect(
        _names(filterAndSortUsers(
          roster,
          sortField: SortField.name,
          sortOrder: SortOrder.descending,
        )),
        ['casey Ford', 'Blair Chen', 'Alex Rivera'],
      );
    });

    test('by total hours', () {
      expect(
        _names(filterAndSortUsers(roster, sortField: SortField.totalHours)),
        ['casey Ford', 'Alex Rivera', 'Blair Chen'],
      );
    });

    test('serviceHours follows the selected hour type when one is set', () {
      final result = filterAndSortUsers(
        roster,
        filter: const UserFilter(hourType: 'Tutoring'),
        sortField: SortField.serviceHours,
      );
      // Only Alex logged Tutoring, so only Alex survives the type filter.
      expect(_names(result), ['Alex Rivera']);
    });

    // Regression: graduation years were compared as strings, so "999" sorted
    // after "2026" and this screen disagreed with the join-requests screen.
    test('graduation years sort numerically, not lexicographically', () {
      final early = userProfile(id: 'x', name: 'Early', graduationYear: '999');
      final late = userProfile(id: 'y', name: 'Late', graduationYear: '2026');

      expect(
        _names(filterAndSortUsers([late, early],
            sortField: SortField.graduationYear)),
        ['Early', 'Late'],
      );
    });

    test('members with no graduation year sort last', () {
      final unknown = userProfile(id: 'z', name: 'Unknown', graduationYear: '');
      final result = filterAndSortUsers(
        [unknown, blair],
        sortField: SortField.graduationYear,
      );
      expect(_names(result), ['Blair Chen', 'Unknown']);
    });

    // Regression: without a tiebreak, equal keys reshuffled between rebuilds.
    test('equal sort keys fall back to a stable name/id order', () {
      final tied = [
        userProfile(id: 'c3', name: 'Same Name', hoursByType: const {}),
        userProfile(id: 'c1', name: 'Same Name', hoursByType: const {}),
        userProfile(id: 'c2', name: 'Same Name', hoursByType: const {}),
      ];

      final first = filterAndSortUsers(tied, sortField: SortField.totalHours);
      final second = filterAndSortUsers(tied.reversed.toList(),
          sortField: SortField.totalHours);

      expect(first.map((u) => u.id).toList(), ['c1', 'c2', 'c3']);
      expect(second.map((u) => u.id).toList(), ['c1', 'c2', 'c3']);
    });
  });

  test('does not mutate the caller\'s list', () {
    final original = [blair, alex, casey];
    final copy = List.of(original);
    filterAndSortUsers(original, sortField: SortField.name);
    expect(original, equals(copy));
  });

  group('graduationYearValue', () {
    test(
        'parses a plain year', () => expect(graduationYearValue('2026'), 2026));
    test('trims', () => expect(graduationYearValue(' 2026 '), 2026));
    test('empty sorts last', () => expect(graduationYearValue(''), 9999));
    test('garbage sorts last', () => expect(graduationYearValue('n/a'), 9999));
  });
}
