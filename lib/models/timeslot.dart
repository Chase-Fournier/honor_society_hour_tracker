import 'package:clock/clock.dart';

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
      time: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      numberOfPeople: json['number_of_people'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      eventId: json['event_id'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : clock.now(),
      attendees: [],
    );
  }

  /// Reads a time from either shape Postgres hands back.
  ///
  /// A `timestamp` column arrives as a full ISO-8601 string, but a bare `time`
  /// column arrives as `"14:30:00"`, which `DateTime.parse` rejects outright.
  /// Accepting both means a column type change cannot break parsing.
  static TimeOfDay parseTimeOfDay(Object? value, {TimeOfDay? fallback}) {
    if (value is! String || value.isEmpty) {
      return fallback ?? const TimeOfDay(hour: 0, minute: 0);
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null) return TimeOfDay.fromDateTime(parsed);

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (hour < 24 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return fallback ?? const TimeOfDay(hour: 0, minute: 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // Emitted as a full ISO-8601 timestamp so [fromJson] can read it back.
      // This previously wrote '${time.hour}:${time.minute}', producing "9:5"
      // for 09:05 -- not zero-padded, and rejected by its own parser, so
      // toJson -> fromJson threw a FormatException. The date component comes
      // from createdAt; only the time is ever read back.
      'start_time': _isoAt(time),
      'end_time': _isoAt(endTime),
      'number_of_people': numberOfPeople,
      'notes': notes,
      'event_id': eventId,
      'created_at': createdAt.toIso8601String(),
      'attendees': attendees.map((attendee) => attendee.toJson()).toList(),
    };
  }

  String _isoAt(TimeOfDay value) => DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
        value.hour,
        value.minute,
      ).toIso8601String();

  /// Copies the slot, overriding the given fields.
  ///
  /// [id] is nullable, so it takes a getter rather than a bare value: passing
  /// `id: () => null` clears it. A plain `id ?? this.id` can only ever set a
  /// value, never remove one.
  TimeSlot copyWith({
    ValueGetter<int?>? id,
    TimeOfDay? time,
    TimeOfDay? endTime,
    int? numberOfPeople,
    String? notes,
    int? eventId,
    DateTime? createdAt,
    List<Attendee>? attendees,
  }) {
    return TimeSlot(
      id: id != null ? id() : this.id,
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
