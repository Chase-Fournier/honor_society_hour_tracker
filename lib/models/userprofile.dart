import 'completeduserhour.dart';

class UserProfile {
  final String name;
  final String id;
  List<CompletedUserHour> completedHours;
  final bool hasPaidDues;
  final String graduationYear; // Added graduation year field

  UserProfile({
    required this.name,
    required this.completedHours,
    required this.id,
    this.hasPaidDues = false,
    this.graduationYear = '', // Default to empty string
  });
}