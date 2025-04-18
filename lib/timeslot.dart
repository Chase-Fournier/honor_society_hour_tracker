import 'attendee.dart';
import 'package:flutter/material.dart';

class TimeSlot {
  final int? id;
  final TimeOfDay time;
  final TimeOfDay endTime;
  final int numberOfPeople;
  final String notes;
  final int eventId;
  final DateTime createdAt;
  List<Attendee> attendees;

  TimeSlot({
    this.id,
    required this.time,
    required this.endTime,
    required this.numberOfPeople,
    this.notes = '',
    required this.eventId,
    required this.createdAt,
    List<Attendee>? attendees,
  }) : attendees = attendees ?? [];

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'],
      time: TimeOfDay.fromDateTime(
          DateTime.parse(json['start_time'] ?? "2012-02-27" as String)),
      endTime: TimeOfDay.fromDateTime(
          DateTime.parse(json['end_time'] ?? "2012-02-27" as String)),
      numberOfPeople: json['number_of_people'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      eventId: json['event_id'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      attendees: [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_time': '${time.hour}:${time.minute}',
      'end_time': '${endTime.hour}:${endTime.minute}',
      'number_of_people': numberOfPeople,
      'notes': notes,
      'event_id': eventId,
      'created_at': createdAt.toIso8601String(),
      'attendees': attendees.map((attendee) => attendee.toJson()).toList(),
    };
  }

  TimeSlot copyWith({
    int? id,
    TimeOfDay? time,
    TimeOfDay? endTime,
    int? numberOfPeople,
    String? notes,
    int? eventId,
    DateTime? createdAt,
    List<Attendee>? attendees,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      numberOfPeople: numberOfPeople ?? this.numberOfPeople,
      notes: notes ?? this.notes,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
      attendees: attendees ?? List.from(this.attendees),
    );
  }
}
