import 'package:flutter/material.dart';
import 'package:nhs_tracker/models/attendee.dart';
import 'package:nhs_tracker/models/completeduserhour.dart';
import 'package:nhs_tracker/models/event.dart';
import 'package:nhs_tracker/models/honorsociety.dart';
import 'package:nhs_tracker/models/hourrequirement.dart';
import 'package:nhs_tracker/models/timeslot.dart';
import 'package:nhs_tracker/models/userprofile.dart';

/// Builders for the objects tests need repeatedly.
///
/// Every parameter has a sensible default so a test names only the field it
/// actually cares about -- that keeps the interesting value visible instead of
/// buried in a wall of boilerplate.

// --- Supabase JSON rows -----------------------------------------------------
//
// These mirror the exact column names the app's queries select, including the
// inconsistencies: Event reads camelCase `isMandatory` and `timeSlots` among
// otherwise snake_case keys.

Map<String, dynamic> eventRow({
  int id = 1,
  String name = 'Park Cleanup',
  String description = 'Pick up litter',
  String date = '2026-09-15T00:00:00.000Z',
  String type = 'Service',
  bool isMandatory = false,
  String createdAt = '2026-08-01T12:00:00.000Z',
  int? collectionId,
  List<Map<String, dynamic>>? timeSlots,
  bool requiresForms = false,
  String? formLink,
  int? swapRequestDeadlineHours,
  bool hasDelay = false,
  int delayHours = 0,
  String? location,
}) =>
    {
      'id': id,
      'name': name,
      'description': description,
      'date': date,
      'type': type,
      'isMandatory': isMandatory,
      'created_at': createdAt,
      'collection_id': collectionId,
      if (timeSlots != null) 'timeSlots': timeSlots,
      'requires_forms': requiresForms,
      'form_link': formLink,
      'swap_request_deadline_hours': swapRequestDeadlineHours,
      'has_delay': hasDelay,
      'delay_hours': delayHours,
      'location': location,
    };

Map<String, dynamic> timeSlotRow({
  int id = 10,
  String startTime = '2026-09-15T09:00:00.000Z',
  String endTime = '2026-09-15T11:30:00.000Z',
  int numberOfPeople = 5,
  String notes = '',
  int eventId = 1,
  String createdAt = '2026-08-01T12:00:00.000Z',
}) =>
    {
      'id': id,
      'start_time': startTime,
      'end_time': endTime,
      'number_of_people': numberOfPeople,
      'notes': notes,
      'event_id': eventId,
      'created_at': createdAt,
    };

Map<String, dynamic> hourRequirementRow({
  int id = 100,
  String type = 'Service',
  num hoursNeeded = 20,
  String description = 'Community service hours',
  bool isActive = true,
  String iconName = 'volunteer_activism',
}) =>
    {
      'id': id,
      'type': type,
      'hours_needed': hoursNeeded,
      'description': description,
      'is_active': isActive,
      'icon_name': iconName,
    };

Map<String, dynamic> honorSocietyRow({
  int id = 1,
  String name = 'Wheeler NHS',
  String description = 'National Honor Society',
  String? imageUrl,
  List<Map<String, dynamic>>? hourRequirements,
  int meetingRequirement = 8,
  String createdAt = '2026-01-01T00:00:00.000Z',
  String? errorFormUrl,
}) =>
    {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'hour_requirements': hourRequirements ?? [hourRequirementRow()],
      'meeting_requirement': meetingRequirement,
      'created_at': createdAt,
      'error_form_url': errorFormUrl,
    };

/// A row shaped like `SocietyProvider`'s membership query: the membership flag
/// plus an embedded `honor_societies` join.
Map<String, dynamic> membershipRow({
  bool isAdmin = false,
  Map<String, dynamic>? society,
}) =>
    {
      'is_admin': isAdmin,
      'honor_societies': society ?? honorSocietyRow(),
    };

// --- Model objects ----------------------------------------------------------

HourRequirement hourRequirement({
  int id = 100,
  String type = 'Service',
  double hoursNeeded = 20,
  String description = 'Community service hours',
  bool isActive = true,
  String iconName = 'volunteer_activism',
}) =>
    HourRequirement(
      id: id,
      type: type,
      hoursNeeded: hoursNeeded,
      description: description,
      isActive: isActive,
      iconName: iconName,
    );

HonorSociety honorSociety({
  int id = 1,
  String name = 'Wheeler NHS',
  String description = 'National Honor Society',
  String? imageUrl,
  List<HourRequirement>? hourRequirements,
  int meetingRequirement = 8,
  DateTime? createdAt,
  String? errorFormUrl,
}) =>
    HonorSociety(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      hourRequirements: hourRequirements ?? [hourRequirement()],
      meetingRequirement: meetingRequirement,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      errorFormUrl: errorFormUrl,
    );

TimeSlot timeSlot({
  int? id = 10,
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0),
  TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 30),
  int numberOfPeople = 5,
  String notes = '',
  int eventId = 1,
  DateTime? createdAt,
  List<Attendee>? attendees,
}) =>
    TimeSlot(
      id: id,
      time: time,
      endTime: endTime,
      numberOfPeople: numberOfPeople,
      notes: notes,
      eventId: eventId,
      createdAt: createdAt ?? DateTime(2026, 8, 1),
      attendees: attendees,
    );

Event event({
  int id = 1,
  String name = 'Park Cleanup',
  String description = 'Pick up litter',
  DateTime? date,
  String type = 'Service',
  bool isMandatory = false,
  DateTime? createdAt,
  int? collectionId,
  List<TimeSlot>? timeSlots,
  bool requiresForms = false,
  String? formLink,
  Duration swapRequestDeadline = const Duration(days: 1),
  bool hasDelay = false,
  int delayHours = 0,
  String? location,
}) =>
    Event(
      id: id,
      name: name,
      description: description,
      date: date ?? DateTime(2026, 9, 15),
      type: type,
      isMandatory: isMandatory,
      createdAt: createdAt ?? DateTime(2026, 8, 1),
      collectionId: collectionId,
      timeSlots: timeSlots,
      requiresForms: requiresForms,
      formLink: formLink,
      swapRequestDeadline: swapRequestDeadline,
      hasDelay: hasDelay,
      delayHours: delayHours,
      location: location,
    );

Attendee attendee({
  int id = 500,
  int timeSlotId = 10,
  String userId = 'test-user-id',
  String name = 'Alex Rivera',
  bool isPresent = false,
  bool formsCompleted = false,
}) =>
    Attendee(
      id: id,
      timeSlotId: timeSlotId,
      userId: userId,
      name: name,
      isPresent: isPresent,
      formsCompleted: formsCompleted,
    );

CompletedUserHour completedUserHour({
  int? id = 900,
  String type = 'Service',
  double hours = 4,
  String eventName = 'Park Cleanup',
}) =>
    CompletedUserHour(
      id: id,
      type: type,
      hours: hours,
      eventName: eventName,
    );

/// A member with hours expressed as `{type: total}` -- the shape the hour
/// filters and progress calculations care about.
UserProfile userProfile({
  String id = 'test-user-id',
  String name = 'Alex Rivera',
  Map<String, double> hoursByType = const {},
  bool hasPaidDues = false,
  String graduationYear = '2027',
}) {
  var nextId = 900;
  return UserProfile(
    id: id,
    name: name,
    hasPaidDues: hasPaidDues,
    graduationYear: graduationYear,
    completedHours: [
      for (final entry in hoursByType.entries)
        completedUserHour(id: nextId++, type: entry.key, hours: entry.value),
    ],
  );
}
