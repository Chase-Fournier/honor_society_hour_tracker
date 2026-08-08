import 'package:flutter/material.dart';

import '../models/timeslot.dart';

/// Hour arithmetic, kept in one place.
///
/// This logic previously existed twice: `NhsFormatUtils.calculateDuration` and
/// a private `_calculateHours` in the attendance check page. Both computed the
/// same thing and shared the same bug.

/// Length of a time slot in hours.
///
/// A slot that crosses midnight (22:00 -> 02:00) rolls into the next day and
/// counts 4 hours. The previous implementation subtracted raw minute-of-day and
/// returned **-20.0** for that case. Because the attendance page writes this
/// value straight into `Service hours`, an overnight event credited members
/// negative hours.
///
/// An end equal to the start is a zero-length slot, not a 24-hour one.
double durationInHours(TimeOfDay start, TimeOfDay end) {
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;

  var difference = endMinutes - startMinutes;
  if (difference < 0) {
    difference += Duration.minutesPerDay;
  }

  return difference / 60.0;
}

/// [durationInHours] for a whole slot.
double timeSlotHours(TimeSlot timeSlot) =>
    durationInHours(timeSlot.time, timeSlot.endTime);

/// Fraction of [required] met by [completed], clamped to 0..1.
///
/// Returns 1.0 when [required] is zero: a requirement of no hours is already
/// satisfied.
///
/// The call sites this replaces divided without a guard, so a 0-hour
/// requirement produced NaN (0/0) or Infinity. That did *not* crash — Dart's
/// `clamp` returns the upper bound for NaN rather than propagating it, so the
/// bars happened to render 100%. The guard makes that outcome intentional and
/// asserted rather than an accident of `clamp` semantics that a future Dart
/// release could change.
double progressFraction(double completed, num required) {
  if (required <= 0) return 1.0;
  return (completed / required).clamp(0.0, 1.0);
}

/// [progressFraction] as a whole-number percentage, 0..100.
int progressPercent(double completed, num required) =>
    (progressFraction(completed, required) * 100).round();

/// Whether [completed] satisfies [required].
///
/// A zero requirement counts as met.
bool meetsRequirement(double completed, num required) =>
    required <= 0 || completed >= required;
