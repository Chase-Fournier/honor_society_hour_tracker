import '../models/attendee.dart';
import '../models/event.dart';
import '../models/timeslot.dart';
import 'hours.dart';

// What marking a roster implies, decided before any I/O.
//
// Extracted from `_AttendanceCheckPageState._saveAttendance`, which interleaved
// the decision with a per-attendee `select` -> `insert`/`delete` -> `update`
// loop. Separating them makes the rules testable and lets the caller issue
// batched queries instead of three round trips per member.

/// A row destined for the `Service hours` table.
class ServiceHourRow {
  const ServiceHourRow({
    required this.userId,
    required this.eventName,
    required this.timeSlotId,
    required this.hours,
    required this.date,
    required this.type,
    required this.societyId,
  });

  final String userId;
  final String eventName;
  final int? timeSlotId;
  final double hours;
  final DateTime date;
  final String type;
  final int? societyId;

  /// Column names match the `Service hours` table exactly.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'event_name': eventName,
        'timeslot_id': timeSlotId,
        'hours': hours,
        'date': date.toIso8601String(),
        'type': type,
        'society_id': societyId,
      };
}

/// The complete set of changes implied by a roster.
class AttendanceChanges {
  const AttendanceChanges({
    required this.hoursToInsert,
    required this.userIdsToClear,
    required this.presenceByAttendeeId,
  });

  /// New `Service hours` rows for members marked present who had none.
  final List<ServiceHourRow> hoursToInsert;

  /// Members marked absent whose existing hours must be removed.
  final List<String> userIdsToClear;

  /// `Attendees.is_present` values, keyed by attendee id.
  final Map<int, bool> presenceByAttendeeId;

  bool get isEmpty =>
      hoursToInsert.isEmpty &&
      userIdsToClear.isEmpty &&
      presenceByAttendeeId.isEmpty;
}

/// Works out what marking [attendees] implies.
///
/// [userIdsWithExistingHours] is the result of a single lookup against
/// `Service hours` for this slot — the screen previously issued one query per
/// attendee inside the loop.
///
/// The operation is idempotent: a member already marked present who already has
/// hours produces no insert, so re-saving a roster cannot double-credit.
AttendanceChanges attendanceChangesFor({
  required List<Attendee> attendees,
  required Set<String> userIdsWithExistingHours,
  required Event event,
  required TimeSlot timeSlot,
  required int? societyId,
}) {
  final hoursToInsert = <ServiceHourRow>[];
  final userIdsToClear = <String>[];
  final presence = <int, bool>{};

  // One duration for the whole slot. durationInHours rolls past midnight, so an
  // overnight slot credits positive hours rather than the negative value the
  // old inline subtraction produced.
  final hours = timeSlotHours(timeSlot);

  for (final attendee in attendees) {
    presence[attendee.id] = attendee.isPresent;

    final hasHours = userIdsWithExistingHours.contains(attendee.userId);

    if (attendee.isPresent && !hasHours) {
      hoursToInsert.add(ServiceHourRow(
        userId: attendee.userId,
        eventName: event.name,
        timeSlotId: timeSlot.id,
        hours: hours,
        date: event.date,
        type: event.type,
        societyId: societyId,
      ));
    } else if (!attendee.isPresent && hasHours) {
      userIdsToClear.add(attendee.userId);
    }
  }

  return AttendanceChanges(
    hoursToInsert: hoursToInsert,
    userIdsToClear: userIdsToClear,
    presenceByAttendeeId: presence,
  );
}
