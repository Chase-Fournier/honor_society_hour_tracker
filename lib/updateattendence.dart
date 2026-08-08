import 'dart:async';
import '../models/attendee.dart';
import 'data/supabase_client.dart';

Future<void> updateAttendanceStatus(Attendee attendee) async {
  await supabase
      .from('Attendees')
      .update({'is_present': attendee.isPresent}).eq('id', attendee.id);
}
