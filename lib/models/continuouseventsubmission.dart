class ContinuousEventSubmission {
  final int id;
  final int continuousEventId;
  final int societyId;
  final String userId;
  final double hours;
  final DateTime activityDate;
  final String proofLink;
  final String? notes;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? reviewerId;
  final String? reviewerNotes;
  final DateTime? reviewedAt;
  final int? serviceHoursId;
  final DateTime createdAt;
  final String? userName;
  final String? continuousEventName;

  ContinuousEventSubmission({
    required this.id,
    required this.continuousEventId,
    required this.societyId,
    required this.userId,
    required this.hours,
    required this.activityDate,
    required this.proofLink,
    this.notes,
    required this.status,
    this.reviewerId,
    this.reviewerNotes,
    this.reviewedAt,
    this.serviceHoursId,
    required this.createdAt,
    this.userName,
    this.continuousEventName,
  });

  factory ContinuousEventSubmission.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    String? userName;
    if (profile is Map && profile['name'] is String) {
      userName = profile['name'] as String;
    }

    final eventBlock = json['continuous_events'];
    String? eventName;
    if (eventBlock is Map && eventBlock['name'] is String) {
      eventName = eventBlock['name'] as String;
    }

    return ContinuousEventSubmission(
      id: (json['id'] as num).toInt(),
      continuousEventId: (json['continuous_event_id'] as num).toInt(),
      societyId: (json['society_id'] as num).toInt(),
      userId: json['user_id'] as String,
      hours: (json['hours'] as num).toDouble(),
      activityDate: DateTime.parse(json['activity_date']),
      proofLink: json['proof_link'] as String? ?? '',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      reviewerId: json['reviewer_id'] as String?,
      reviewerNotes: json['reviewer_notes'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at']),
      serviceHoursId: (json['service_hours_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at']),
      userName: userName,
      continuousEventName: eventName,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
