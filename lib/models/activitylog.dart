class ActivityLog {
  final int id;
  final String eventName;
  final String timeslot;
  final double hours;
  final String actionType;
  final String userId;
  final String userName;
  final DateTime createdAt;
  final String? oldUserId;
  final String? newUserId;
  final String? oldUserName;
  final String? newUserName;

  ActivityLog({
    required this.id,
    required this.eventName,
    required this.timeslot,
    required this.hours,
    required this.actionType,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.oldUserId,
    this.newUserId,
    this.oldUserName,
    this.newUserName,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      eventName: json['event_name'],
      timeslot: json['timeslot'],
      hours: json['hours'].toDouble(),
      actionType: json['action_type'],
      userId: json['user_id'],
      userName: json['profiles']['name'],
      createdAt: DateTime.parse(json['created_at']),
      oldUserId: json['old_user_id'],
      newUserId: json['new_user_id'],
      oldUserName: json['old_user_name'],
      newUserName: json['new_user_name'],
    );
  }
}
