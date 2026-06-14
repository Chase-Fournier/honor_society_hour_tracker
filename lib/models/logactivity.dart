import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

final supabase = Supabase.instance.client;

/// Records user activity in the system for auditing purposes.
///
/// Parameters:
/// - eventName: String - Name of event
/// - timeslot: String - Time slot information
/// - hours: double - Hours involved
/// - actionType: String - Type of action
/// - userId: String - User performing action
/// - oldUserId: String? - Previous user (for swaps)
/// - newUserId: String? - New user (for swaps)
///
/// Returns:
/// - Future<void>
Future<void> logactivity(
  String eventName,
  String timeslot,
  double hours,
  String actionType,
  String userId, {
  String? oldUserId,
  String? newUserId,
  int? societyId,
}) async {
  try {
    await supabase.from('activity_logs').insert({
      'event_name': eventName,
      'timeslot': timeslot,
      'hours': hours,
      'action_type': actionType,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'old_user_id': oldUserId,
      'new_user_id': newUserId,
      'society_id': societyId,
    });
  } catch (e) {
    debugPrint('Error logging activity: $e');
  }
}
