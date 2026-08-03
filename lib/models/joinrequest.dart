import 'package:flutter/foundation.dart' show ValueGetter;

/// A member's request to join a society.
///
/// Moved out of `lib/screens/JoinRequestsAdmin.dart`, where it was unreachable
/// from a test because that file transitively pulled in an eager Supabase
/// client.
class JoinRequest {
  final int id;
  final String status;
  final String userId;
  final String userName;
  final String userEmail;
  final String graduationYear;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processorName;

  JoinRequest({
    required this.id,
    required this.status,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.graduationYear = '',
    required this.requestedAt,
    this.processedAt,
    this.processorName,
  });

  /// Copies the request, overriding the given fields.
  ///
  /// [processedAt] and [processorName] are nullable and take getters, so
  /// `processedAt: () => null` clears them — reverting an approved request back
  /// to pending needs exactly that. The previous `?? this.processedAt` form
  /// could only ever set a value.
  JoinRequest copyWith({
    String? status,
    ValueGetter<DateTime?>? processedAt,
    ValueGetter<String?>? processorName,
  }) {
    return JoinRequest(
      id: id,
      status: status ?? this.status,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      graduationYear: graduationYear,
      requestedAt: requestedAt,
      processedAt: processedAt != null ? processedAt() : this.processedAt,
      processorName:
          processorName != null ? processorName() : this.processorName,
    );
  }

  /// Note the mixed key conventions: `userName` / `userEmail` / `processorName`
  /// are camelCase (they are computed in the select), while `user_id`,
  /// `graduation_year`, `requested_at` and `processed_at` are real snake_case
  /// columns. `graduation_year` may arrive as an int or a string.
  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'],
      status: json['status'],
      userId: json['user_id'],
      userName: json['userName'] ?? 'Unknown User',
      userEmail: json['userEmail'] ?? 'No email',
      graduationYear: json['graduation_year']?.toString() ?? '',
      requestedAt: DateTime.parse(json['requested_at']),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      processorName: json['processorName'],
    );
  }
}
