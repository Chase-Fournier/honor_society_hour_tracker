import 'continuouseventstep.dart';

class ContinuousEvent {
  final int id;
  final int societyId;
  final String name;
  final String description;
  final String type;
  final String iconName;
  final List<ContinuousEventStep> steps;
  final bool allowMultipleSubmissions;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContinuousEvent({
    required this.id,
    required this.societyId,
    required this.name,
    required this.description,
    required this.type,
    this.iconName = 'workspaces',
    List<ContinuousEventStep>? steps,
    this.allowMultipleSubmissions = true,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  }) : steps = steps ?? [];

  factory ContinuousEvent.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List?) ?? const [];
    final parsedSteps = rawSteps
        .map((s) => ContinuousEventStep.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return ContinuousEvent(
      id: (json['id'] as num).toInt(),
      societyId: (json['society_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'workspaces',
      steps: parsedSteps,
      allowMultipleSubmissions: json['allow_multiple_submissions'] ?? true,
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'society_id': societyId,
      'name': name,
      'description': description,
      'type': type,
      'icon_name': iconName,
      'steps': steps.map((s) => s.toJson()).toList(),
      'allow_multiple_submissions': allowMultipleSubmissions,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ContinuousEvent copyWith({
    String? name,
    String? description,
    String? type,
    String? iconName,
    List<ContinuousEventStep>? steps,
    bool? allowMultipleSubmissions,
    bool? isActive,
  }) {
    return ContinuousEvent(
      id: id,
      societyId: societyId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      steps: steps ?? this.steps,
      allowMultipleSubmissions:
          allowMultipleSubmissions ?? this.allowMultipleSubmissions,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
