import 'package:clock/clock.dart';
import '../logic/hours.dart';
import 'package:flutter/material.dart';
import '../models/timeslot.dart';
import 'package:intl/intl.dart';

class NhsFormatUtils {
  static String formatTimeSlot(TimeSlot timeSlot, BuildContext context) {
    return '${formatTimeOfDay(timeSlot.time, context)} - ${formatTimeOfDay(timeSlot.endTime, context)}';
  }

  /// Human-readable date, e.g. "Jun 18, 2026".
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  static String formatTimeOfDay(TimeOfDay time, BuildContext context) {
    final now = clock.now();
    final dateTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dateTime);
  }

  /// Deprecated alias for [durationInHours]; kept so existing call sites read
  /// naturally. New code should use the function in `lib/logic/hours.dart`.
  static double calculateDuration(TimeOfDay startTime, TimeOfDay endTime) =>
      durationInHours(startTime, endTime);
}
