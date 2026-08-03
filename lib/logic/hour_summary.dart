import '../common/normalizetype.dart';
import '../models/completedhour.dart';
import '../models/event.dart';
import 'hours.dart';

// The hour totals a member sees on the home and completed-hours screens.
//
// Extracted from `_HomePageState._fetchCompletedHours` and the counters in
// completedhourspage.dart, which computed these inline against raw type
// strings.

/// Totals for one member, bucketed by requirement type.
class HourSummary {
  HourSummary({
    required this.completedByType,
    required this.potentialByType,
    required this.entriesByType,
  });

  /// Hours already credited, keyed by requirement type.
  final Map<String, double> completedByType;

  /// [completedByType] plus hours from slots the member is signed up for but
  /// has not yet attended. Always >= the completed figure for the same type.
  final Map<String, double> potentialByType;

  /// The individual credited entries behind [completedByType].
  final Map<String, List<CompletedHour>> entriesByType;

  double completedFor(String type) => completedByType[normalizeType(type)] ?? 0;
  double potentialFor(String type) => potentialByType[normalizeType(type)] ?? 0;

  /// Total credited hours across every type.
  double get totalCompleted =>
      completedByType.values.fold(0.0, (sum, hours) => sum + hours);

  /// How many requirements are satisfied, counting meetings separately.
  int completedRequirementCount({
    required Map<String, double> hoursNeededByType,
    required int meetingRequirement,
  }) {
    var count = 0;
    for (final entry in hoursNeededByType.entries) {
      if (meetsRequirement(completedFor(entry.key), entry.value)) count++;
    }
    if (meetsRequirement(completedFor('Meeting'), meetingRequirement)) count++;
    return count;
  }
}

/// Aggregates a member's logged hours and upcoming commitments.
///
/// [requirementTypes] seeds the buckets so a requirement with no hours yet still
/// reports 0 rather than being absent. 'Meeting' is always included, since the
/// meeting requirement lives on the society rather than in `hour_requirements`.
///
/// Types are matched with [normalizeType], as everywhere else in the app. The
/// original keyed the buckets on the raw string, so an hour logged as "service"
/// did not count towards the "Service" requirement and simply vanished from the
/// member's totals.
HourSummary summariseHours({
  required Iterable<Map<String, dynamic>> loggedRows,
  required Iterable<Event> upcomingEvents,
  required Iterable<String> requirementTypes,
  required String userId,
}) {
  final completed = <String, double>{};
  final potential = <String, double>{};
  final entries = <String, List<CompletedHour>>{};

  for (final type in [...requirementTypes, 'Meeting']) {
    final key = normalizeType(type);
    completed[key] = 0;
    potential[key] = 0;
    entries[key] = [];
  }

  for (final row in loggedRows) {
    final key = normalizeType((row['type'] as String?) ?? '');
    // Unknown types are still dropped -- there is no requirement to show them
    // against -- but now only after normalising, so casing no longer decides it.
    if (!completed.containsKey(key)) continue;

    final hours = (row['hours'] as num?)?.toDouble() ?? 0.0;
    completed[key] = completed[key]! + hours;
    potential[key] = potential[key]! + hours;

    final dateString = row['date'] as String?;
    entries[key]!.add(CompletedHour(
      title: (row['event_name'] as String?) ?? 'Unknown Event',
      date: dateString != null
          ? (DateTime.tryParse(dateString) ?? DateTime(1970))
          : DateTime(1970),
      hours: hours,
    ));
  }

  for (final event in upcomingEvents) {
    final key = normalizeType(event.type);
    if (!potential.containsKey(key)) continue;

    for (final slot in event.timeSlots) {
      final signedUpNotYetPresent =
          slot.attendees.any((a) => a.userId == userId && !a.isPresent);
      if (signedUpNotYetPresent) {
        potential[key] =
            potential[key]! + durationInHours(slot.time, slot.endTime);
      }
    }
  }

  return HourSummary(
    completedByType: completed,
    potentialByType: potential,
    entriesByType: entries,
  );
}
