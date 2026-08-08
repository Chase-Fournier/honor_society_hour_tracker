import '../common/normalizetype.dart';
import '../models/userprofile.dart';

/// The member-roster filter and sort engine.
///
/// Extracted verbatim from `_AdminListsPageState._getFilteredAndSortedUsers`
/// so it can be tested without a Supabase client or a widget tree, with two
/// behavioural fixes noted at [HourTypeFilter] and [SortField.graduationYear].

enum SortField {
  name,
  totalHours,
  serviceHours,
  tutoringHours,
  meetingHours,
  graduationYear,
}

enum SortOrder { ascending, descending }

/// How a numeric range filter is applied.
enum RangeCondition { atLeast, atMost, between }

RangeCondition rangeConditionFromString(String? value) {
  switch (value) {
    case 'atMost':
      return RangeCondition.atMost;
    case 'between':
      return RangeCondition.between;
    case 'atLeast':
    default:
      return RangeCondition.atLeast;
  }
}

enum GraduationYearCondition { equals, before, after }

GraduationYearCondition? graduationYearConditionFromString(String? value) {
  switch (value) {
    case 'equals':
      return GraduationYearCondition.equals;
    case 'before':
      return GraduationYearCondition.before;
    case 'after':
      return GraduationYearCondition.after;
    default:
      return null;
  }
}

/// A numeric range filter, used for both total hours and per-type hours.
///
/// **Fix:** the two call sites disagreed, and one was dead.
///
/// Per hour type, the `atMost` branch was guarded by
/// `maxHours < (_maximumHoursByType[hourType] ?? 50)` — comparing `maxHours`
/// against the very expression it had just been assigned from on the line
/// above, which is always false. "At most N hours of type X" therefore silently
/// did nothing, and `between` only worked through its minimum.
///
/// For total hours the guard was `_maximumTotalHours < 50`, i.e. "ignore the
/// maximum while the slider sits at its ceiling".
///
/// Both guards are dropped: choosing a condition is itself the signal that the
/// user wants it applied. The visible consequence is that "at most 50" now
/// really does exclude anyone above 50, where before it was ignored.
class HourTypeFilter {
  const HourTypeFilter({
    this.condition = RangeCondition.atLeast,
    this.min = 0,
    this.max = 50,
  });

  final RangeCondition condition;
  final double min;
  final double max;

  bool accepts(double hours) {
    switch (condition) {
      case RangeCondition.atLeast:
        // Preserved from the original: a minimum of 0 excludes nobody, so the
        // filter stays inert until the user raises it.
        return min <= 0 || hours >= min;
      case RangeCondition.atMost:
        return hours <= max;
      case RangeCondition.between:
        return hours >= min && hours <= max;
    }
  }
}

/// Total hours across every type.
double totalHoursFor(UserProfile user) =>
    user.completedHours.fold(0.0, (sum, hour) => sum + hour.hours);

/// Hours logged against [type], matched case/spacing-insensitively.
double hoursByTypeFor(UserProfile user, String type) {
  final wanted = normalizeType(type);
  return user.completedHours
      .where((hour) => normalizeType(hour.type) == wanted)
      .fold(0.0, (sum, hour) => sum + hour.hours);
}

/// Every knob the roster screen exposes.
class UserFilter {
  const UserFilter({
    this.searchQuery = '',
    this.hourType,
    this.useAdvancedFiltering = false,
    this.totalHours = const HourTypeFilter(),
    this.hoursByType = const {},
    this.graduationYear = '',
    this.graduationYearCondition,
    this.filterByDues = false,
    this.showPaidDues = true,
  });

  final String searchQuery;

  /// `null` or `'All'` means every type.
  final String? hourType;

  final bool useAdvancedFiltering;
  final HourTypeFilter totalHours;
  final Map<String, HourTypeFilter> hoursByType;
  final String graduationYear;
  final GraduationYearCondition? graduationYearCondition;
  final bool filterByDues;
  final bool showPaidDues;
}

/// Filters then sorts [users]. Never mutates its input.
List<UserProfile> filterAndSortUsers(
  List<UserProfile> users, {
  UserFilter filter = const UserFilter(),
  SortField sortField = SortField.name,
  SortOrder sortOrder = SortOrder.ascending,
}) {
  var result = users;

  if (filter.searchQuery.isNotEmpty) {
    final query = filter.searchQuery.toLowerCase();
    result = result.where((u) => u.name.toLowerCase().contains(query)).toList();
  }

  final hourType = filter.hourType;
  if (hourType != null && hourType != 'All') {
    final wanted = normalizeType(hourType);
    result = result
        .where(
            (u) => u.completedHours.any((h) => normalizeType(h.type) == wanted))
        .toList();
  }

  if (filter.useAdvancedFiltering) {
    result = result.where((user) {
      if (!filter.totalHours.accepts(totalHoursFor(user))) return false;

      for (final entry in filter.hoursByType.entries) {
        if (!entry.value.accepts(hoursByTypeFor(user, entry.key))) return false;
      }

      if (filter.graduationYear.isNotEmpty &&
          filter.graduationYearCondition != null &&
          !_matchesGraduationYear(
            user.graduationYear,
            filter.graduationYear,
            filter.graduationYearCondition!,
          )) {
        return false;
      }

      if (filter.filterByDues && user.hasPaidDues != filter.showPaidDues) {
        return false;
      }

      return true;
    }).toList();
  } else {
    result = List<UserProfile>.of(result);
  }

  result.sort((a, b) {
    final comparison = _compare(a, b, sortField, filter.hourType);
    return sortOrder == SortOrder.ascending ? comparison : -comparison;
  });

  return result;
}

int _compare(UserProfile a, UserProfile b, SortField field, String? hourType) {
  int comparison;
  switch (field) {
    case SortField.name:
      comparison = a.name.compareTo(b.name);
      break;
    case SortField.totalHours:
      comparison = totalHoursFor(a).compareTo(totalHoursFor(b));
      break;
    case SortField.serviceHours:
      final type =
          (hourType != null && hourType != 'All') ? hourType : 'Service';
      comparison = hoursByTypeFor(a, type).compareTo(hoursByTypeFor(b, type));
      break;
    case SortField.tutoringHours:
      comparison = hoursByTypeFor(a, 'Tutoring')
          .compareTo(hoursByTypeFor(b, 'Tutoring'));
      break;
    case SortField.meetingHours:
      comparison =
          hoursByTypeFor(a, 'Meeting').compareTo(hoursByTypeFor(b, 'Meeting'));
      break;
    case SortField.graduationYear:
      // **Fix:** the original compared graduation years as *strings*, so "999"
      // sorted after "2026" and the roster disagreed with the join-requests
      // screen, which parses them as ints. Members with an unparseable or
      // missing year sort last, matching gradYearValue in
      // lib/logic/join_request_sort.dart.
      comparison = graduationYearValue(a.graduationYear)
          .compareTo(graduationYearValue(b.graduationYear));
      break;
  }

  // The original had no tiebreak, so members with equal keys reshuffled between
  // rebuilds. Fall back to name, then id, for a stable order.
  if (comparison == 0)
    comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (comparison == 0) comparison = a.id.compareTo(b.id);
  return comparison;
}

/// Graduation year as a sortable int; unparseable/missing sorts last.
int graduationYearValue(String graduationYear) =>
    int.tryParse(graduationYear.trim()) ?? 9999;

bool _matchesGraduationYear(
  String userYear,
  String filterYear,
  GraduationYearCondition condition,
) {
  if (condition == GraduationYearCondition.equals) {
    return userYear == filterYear;
  }

  final user = int.tryParse(userYear);
  final wanted = int.tryParse(filterYear);

  // Preserved from the original: fall back to lexicographic comparison when
  // either side is not a number.
  final comparison = (user != null && wanted != null)
      ? user.compareTo(wanted)
      : userYear.compareTo(filterYear);

  return condition == GraduationYearCondition.before
      ? comparison < 0
      : comparison > 0;
}
