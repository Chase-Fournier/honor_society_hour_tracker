import 'completeduserhour.dart';

class UserProfile {
  final String name;
  final String id;
  List<CompletedUserHour> completedHours;
  final bool hasPaidDues; // New field

  UserProfile({
    required this.name,
    required this.completedHours,
    required this.id,
    this.hasPaidDues = false, // Default to false
  });
}