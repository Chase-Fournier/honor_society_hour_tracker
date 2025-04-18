import 'timeslot.dart';

class Event {
  final int id;
  final String name;
  final String description;
  final DateTime date;
  final String type;
  final bool isMandatory;
  final DateTime createdAt;
  final int? collectionId;
  List<TimeSlot> timeSlots;
  final bool requiresForms;
  final String? formLink;
  final bool hasDelay;
  final int delayHours;
  final Duration swapRequestDeadline; // New property

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.type,
    this.isMandatory = false,
    required this.createdAt,
    this.collectionId,
    List<TimeSlot>? timeSlots,
    this.requiresForms = false,
    this.formLink,
    this.swapRequestDeadline = const Duration(days: 1),
    this.hasDelay = false,
    this.delayHours = 0,
  }) : timeSlots = timeSlots ?? [];

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      type: json['type'],
      isMandatory: json['isMandatory'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      collectionId: json['collection_id'],
      timeSlots: (json['timeSlots'] as List<dynamic>?)
              ?.map((timeSlotJson) => TimeSlot.fromJson(timeSlotJson))
              .toList() ??
          [],
      requiresForms: json['requires_forms'] ?? false,
      formLink: json['form_link'],
      swapRequestDeadline:
          Duration(hours: json['swap_request_deadline_hours'] ?? 24),
      hasDelay: json['has_delay'] ?? false,
      delayHours: json['delay_hours'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'isMandatory': isMandatory,
      'created_at': createdAt.toIso8601String(),
      'collection_id': collectionId,
      'timeSlots': timeSlots.map((timeSlot) => timeSlot.toJson()).toList(),
      'requires_forms': requiresForms,
      'form_link': formLink,
      'swap_request_deadline_hours': swapRequestDeadline.inHours,
      'has_delay': hasDelay,
      'delay_hours': delayHours,
    };
  }

  bool canSignUpForTimeSlot(TimeSlot timeSlot) {
    if (!hasDelay) return true;

    final now = DateTime.now();
    final eventDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      timeSlot.time.hour,
      timeSlot.time.minute,
    );

    final signupDateTime = eventDateTime.subtract(Duration(hours: delayHours));
    return now.isAfter(signupDateTime);
  }

  Event copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? date,
    String? type,
    bool? isMandatory,
    DateTime? createdAt,
    int? collectionId,
    List<TimeSlot>? timeSlots,
    bool? requiresForms,
    String? formLink,
    Duration? swapRequestDeadline,
    bool? hasDelay,
    int? delayHours,
  }) {
    return Event(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        date: date ?? this.date,
        type: type ?? this.type,
        isMandatory: isMandatory ?? this.isMandatory,
        createdAt: createdAt ?? this.createdAt,
        collectionId: collectionId ?? this.collectionId,
        timeSlots: timeSlots ?? List.from(this.timeSlots),
        requiresForms: requiresForms ?? this.requiresForms,
        formLink: formLink ?? this.formLink,
        hasDelay: hasDelay ?? this.hasDelay,
        delayHours: delayHours ?? this.delayHours,
        swapRequestDeadline: swapRequestDeadline ?? this.swapRequestDeadline);
  }
}
