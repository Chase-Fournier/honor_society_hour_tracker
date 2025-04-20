class SwapRequest {
  final int id;
  final String requesterId;
  final String currentAttendeeId;
  final int eventId;
  final int timeSlotId;
  final String status;
  final DateTime startTime;
  final DateTime endTime;

  SwapRequest({
    required this.id,
    required this.requesterId,
    required this.currentAttendeeId,
    required this.eventId,
    required this.timeSlotId,
    required this.status,
    required this.startTime,
    required this.endTime,
  });

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    return SwapRequest(
      id: json['id'],
      requesterId: json['requester_id'],
      currentAttendeeId: json['target_id'],
      eventId: json['event_id'],
      timeSlotId: json['timeslot_id'],
      status: json['status'],
      startTime: DateTime.parse(json['Time slots']['start_time']),
      endTime: DateTime.parse(json['Time slots']['end_time']),
    );
  }
}
