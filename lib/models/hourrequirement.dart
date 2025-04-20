class HourRequirement {
  final int id;
  final String type;
  final double hoursNeeded;
  final String description;
  final bool isActive;
  final String iconName;

  HourRequirement({
    required this.id,
    required this.type,
    required this.hoursNeeded,
    required this.description,
    this.isActive = true,
    this.iconName = 'workspaces',
  });

  factory HourRequirement.fromJson(Map<String, dynamic> json) {
    return HourRequirement(
      id: json['id'],
      type: json['type'],
      hoursNeeded: json['hours_needed'].toDouble(),
      description: json['description'],
      isActive: json['is_active'] ?? true,
      iconName: json['icon_name'] ?? 'workspaces',
    );
  }
}
