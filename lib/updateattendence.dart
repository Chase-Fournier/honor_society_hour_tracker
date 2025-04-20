import 'dart:async';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../models/attendee.dart';

Future<void> updateAttendanceStatus(Attendee attendee) async {
  await Supabase.instance.client
      .from('Attendees')
      .update({'is_present': attendee.isPresent}).eq('id', attendee.id);
}
