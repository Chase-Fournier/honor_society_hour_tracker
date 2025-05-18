// lib/models/completeduserhour.dart
class CompletedUserHour {
  final int? id; // <-- Add this ID field
  final String eventName;
  final double hours;
  final String type;

  CompletedUserHour({
    this.id, // <-- Add to constructor
    required this.eventName,
    required this.hours,
    required this.type,
  });

  factory CompletedUserHour.fromJson(Map<String, dynamic> json) {
    final dynamic hoursValue = json['hours'];
    final double hours;
    if (hoursValue is int) {
      hours = hoursValue.toDouble();
    } else if (hoursValue is double) {
      hours = hoursValue;
    } else {
      // Provide a default or handle the error differently if needed
      print(
          'Warning: Invalid hours value received: $hoursValue. Defaulting to 0.');
      hours = 0.0;
      // Optionally: throw FormatException('Invalid hours value: $hoursValue');
    }

    return CompletedUserHour(
      id: json['id'] as int, // <-- Parse the ID
      eventName: json['event_name'] as String? ??
          'Unnamed Event', // Handle potential null
      hours: hours,
      type: json['type'] as String? ?? 'Unknown Type', // Handle potential null
    );
  }
}
