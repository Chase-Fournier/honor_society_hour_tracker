class Attendee {
  final int id;
  final int timeSlotId;
  final String userId;
  final String name;
  bool isPresent;
  bool formsCompleted;

  Attendee({
    required this.id,
    required this.timeSlotId,
    required this.userId,
    required this.name,
    this.isPresent = false,
    this.formsCompleted = false,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'],
      timeSlotId: json['timeslot_id'],
      userId: json['user_id'],
      name: json['name'] ?? 'Unknown',
      isPresent: json['is_present'] ?? false,
      formsCompleted: json['forms_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timeslot_id': timeSlotId,
      'user_id': userId,
      'name': name,
      'is_present': isPresent,
      'forms_completed': formsCompleted,
    };
  }

  Attendee copyWith({
    int? id,
    int? timeSlotId,
    String? userId,
    String? name,
    bool? isPresent,
    bool? formsCompleted,
  }) {
    return Attendee(
      id: id ?? this.id,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isPresent: isPresent ?? this.isPresent,
      formsCompleted: formsCompleted ?? this.formsCompleted,
    );
  }
}
