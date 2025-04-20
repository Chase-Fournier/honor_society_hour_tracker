import 'package:flutter/material.dart';
import '../models/timeslot.dart';
import 'package:intl/intl.dart';

class NhsFormatUtils {
  static String formatTimeSlot(TimeSlot timeSlot, BuildContext context) {
    return '${formatTimeOfDay(timeSlot.time, context)} - ${formatTimeOfDay(timeSlot.endTime, context)}';
  }
  
  static String formatTimeOfDay(TimeOfDay time, BuildContext context) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dateTime);
  }
  
  static double calculateDuration(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final difference = endMinutes - startMinutes;
    return difference / 60.0;
  }
}
