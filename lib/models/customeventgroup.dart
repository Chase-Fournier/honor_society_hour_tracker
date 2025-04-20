import 'affecteduser.dart';

class CustomEventGroup {
  final String eventName;
  final int userCount;
  final String type;
  final double hours;
  final String timeSlot;
  final List<AffectedUser> affectedUsers;

  CustomEventGroup({
    required this.eventName,
    required this.userCount,
    required this.type,
    required this.hours,
    required this.timeSlot,
    required this.affectedUsers,
  });
}
